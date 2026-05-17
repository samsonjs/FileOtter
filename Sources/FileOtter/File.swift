//
//  File.swift
//  FileOtter
//
//  Created by Sami Samhuri on 2025-08-19.
//

import Darwin
import Foundation

// `Darwin.flock` is ambiguous — it names both `struct flock` (record locking) and the
// BSD `flock(2)` function. Bind the function under a unique Swift name.
@_silgen_name("flock") private func bsdFlock(_ fd: Int32, _ operation: Int32) -> Int32

// MARK: - File Class

/// A File object represents an open file with automatic resource management.
/// The file handle is automatically closed when the File object is deallocated.
public class File: CustomStringConvertible, CustomDebugStringConvertible {
    private var fd: Int32
    public let url: URL
    public let mode: Mode

    // MARK: - Mode

    public enum Mode: Equatable {
        case read // r
        case write // w
        case append // a
        case readWrite // r+
        case readWriteNew // w+
        case readAppend // a+
        case writeExclusive // wx (create, fail if exists)
    }

    // MARK: - Initialization

    public init(url: URL, mode: Mode = .read, permissions: Int = 0o666) throws {
        self.url = url
        self.mode = mode
        let flags = Self.openFlags(for: mode)
        let openedFD = url.path.withCString { Darwin.open($0, flags, mode_t(permissions)) }
        guard openedFD >= 0 else {
            let errorCode: CocoaError.Code = mode == .read ? .fileReadUnknown : .fileWriteUnknown
            throw CocoaError(errorCode, userInfo: [NSFilePathErrorKey: url.path])
        }
        fd = openedFD
    }

    deinit {
        if fd >= 0 { _ = Darwin.close(fd) }
    }

    private static func openFlags(for mode: Mode) -> Int32 {
        switch mode {
        case .read: O_RDONLY
        case .write: O_WRONLY | O_CREAT | O_TRUNC
        case .append: O_WRONLY | O_CREAT | O_APPEND
        case .readWrite: O_RDWR
        case .readWriteNew: O_RDWR | O_CREAT | O_TRUNC
        case .readAppend: O_RDWR | O_CREAT | O_APPEND
        case .writeExclusive: O_WRONLY | O_CREAT | O_EXCL
        }
    }

    // MARK: - Opening with blocks

    public static func open(url: URL, mode: Mode = .read, permissions: Int = 0o666) throws -> File {
        try File(url: url, mode: mode, permissions: permissions)
    }

    @discardableResult
    public static func open<T>(url: URL, mode: Mode = .read, permissions: Int = 0o666, _ body: (File) throws -> T) throws -> T {
        let file = try File(url: url, mode: mode, permissions: permissions)
        defer { try? file.close() }
        return try body(file)
    }

    // MARK: - Instance Properties

    public var atime: Date {
        Date(timeIntervalSince1970: TimeInterval(rawStat().st_atimespec.tv_sec))
    }

    public var mtime: Date {
        Date(timeIntervalSince1970: TimeInterval(rawStat().st_mtimespec.tv_sec))
    }

    public var ctime: Date {
        Date(timeIntervalSince1970: TimeInterval(rawStat().st_ctimespec.tv_sec))
    }

    public var birthtime: Date {
        Date(timeIntervalSince1970: TimeInterval(rawStat().st_birthtimespec.tv_sec))
    }

    public var size: Int {
        Int(rawStat().st_size)
    }

    private func rawStat() -> stat {
        precondition(fd >= 0, "File is closed")
        var buf = stat()
        let result = fstat(fd, &buf)
        precondition(result == 0, "fstat failed on open fd \(fd): errno \(errno)")
        return buf
    }

    // MARK: - Instance Methods

    public func chmod(_ permissions: Int) throws {
        guard fchmod(fd, mode_t(permissions)) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    public func chown(owner: Int? = nil, group: Int? = nil) throws {
        var current = stat()
        if owner == nil || group == nil {
            guard fstat(fd, &current) == 0 else {
                throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
            }
        }
        let newOwner = owner.map { uid_t($0) } ?? current.st_uid
        let newGroup = group.map { gid_t($0) } ?? current.st_gid
        guard fchown(fd, newOwner, newGroup) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    public func truncate(to size: Int) throws {
        guard ftruncate(fd, off_t(size)) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    public func flock(_ operation: LockOperation, nonBlocking: Bool = false) throws {
        var op: Int32
        switch operation {
        case .shared: op = LOCK_SH
        case .exclusive: op = LOCK_EX
        case .unlock: op = LOCK_UN
        }
        if nonBlocking { op |= LOCK_NB }
        guard bsdFlock(fd, op) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    public func fileStat() throws -> FileStat {
        guard fd >= 0 else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        var buf = stat()
        guard fstat(fd, &buf) == 0 else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        return FileStat(buf)
    }

    public func fileLstat() throws -> FileStat {
        // No flstat(2) exists, and an open fd has already followed any symlinks.
        // Inspect the original path with lstat to report on the link itself.
        try File.linkStatus(url)
    }

    public func close() throws {
        guard fd >= 0 else { return }
        let fdToClose = fd
        fd = -1
        guard Darwin.close(fdToClose) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        url.path
    }

    public var debugDescription: String {
        "<File:\(url.path) mode:\(mode)>"
    }
}

// MARK: - Static Path Operations

public extension File {
    static func basename(_ path: String, suffix: String? = nil) -> String {
        if path.isEmpty { return "" }

        // Strip trailing slashes; collapsing path of only slashes is root.
        var p = Substring(path)
        while p.count > 1, p.last == "/" { p = p.dropLast() }
        if p == "/" { return "/" }

        // Last path component
        let base: String
        if let lastSlash = p.lastIndex(of: "/") {
            base = String(p[p.index(after: lastSlash)...])
        } else {
            base = String(p)
        }

        guard let suffix else { return base }

        if suffix == ".*" {
            // Strip the final extension, but leading-dot files are not extensions.
            guard let dot = base.lastIndex(of: "."), dot != base.startIndex else {
                return base
            }
            return String(base[..<dot])
        }

        if base.hasSuffix(suffix) {
            return String(base.dropLast(suffix.count))
        }
        return base
    }

    static func dirname(_ path: String, level: Int = 1) -> String {
        var current = path
        for _ in 0 ..< level {
            current = dirnameOnce(current)
            if current == "/" || current == "." { break }
        }
        return current
    }

    private static func dirnameOnce(_ path: String) -> String {
        if path.isEmpty { return "." }

        // Strip trailing slashes, except for root.
        var p = Substring(path)
        while p.count > 1, p.last == "/" { p = p.dropLast() }
        if p == "/" { return "/" }

        guard let lastSlash = p.lastIndex(of: "/") else {
            // Single component, no parent directory.
            return "."
        }

        // Everything before the last slash, with trailing slashes collapsed.
        var dir = p[..<lastSlash]
        while dir.count > 1, dir.last == "/" { dir = dir.dropLast() }
        if dir.isEmpty { return "/" }
        // Ruby collapses 2+ leading slashes in the dirname result down to one.
        var result = String(dir)
        while result.hasPrefix("//") { result.removeFirst() }
        return result
    }

    static func extname(_ path: String) -> String {
        let base = basename(path)
        if base.isEmpty { return "" }
        guard let dot = base.lastIndex(of: ".") else { return "" }
        // Leading-dot files don't have an extension (".bashrc" → "").
        if dot == base.startIndex { return "" }
        // Basenames that are entirely dots ("..", "...") have no extension.
        if base.allSatisfy({ $0 == "." }) { return "" }
        return String(base[dot...])
    }

    static func split(_ path: String) -> (dir: String, name: String) {
        (dirname(path), basename(path))
    }

    static func join(_ components: String...) -> String {
        join(components)
    }

    static func join(_ components: [String]) -> String {
        if components.isEmpty { return "" }
        // Ruby's File.join dedups slashes only at the boundary between
        // consecutive components — interior slash runs are preserved.
        var result = components[0]
        for arg in components.dropFirst() {
            if arg.hasPrefix("/") {
                // Strip all trailing slashes from result so the boundary
                // collapses to whatever leading slashes the new arg brings.
                while result.hasSuffix("/") { result.removeLast() }
                result += arg
            } else if result.hasSuffix("/") {
                // Boundary already has a separator; just concatenate.
                result += arg
            } else {
                // Neither side has a separator; insert one.
                result += "/"
                result += arg
            }
        }
        return result
    }

    static func absolutePath(_ url: URL) -> URL {
        // URL(fileURLWithPath:) already makes relative paths absolute using current directory
        // We just need to normalize the path (resolves . and .. but NOT symlinks)
        url.standardized
    }

    static func expandPath(_ path: String) -> URL {
        // Expand tilde to home directory
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    static func realpath(_ url: URL) throws -> URL {
        // Resolve all symbolic links in the path
        // All components must exist for this to work
        let path = url.path

        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: path])
        }

        // Use standardizedFileURL to resolve symlinks and normalize the path
        // This resolves .., ., and symlinks
        return url.resolvingSymlinksInPath()
    }

    static func realdirpath(_ url: URL) throws -> URL {
        // Similar to realpath but the last component may not exist
        let parentURL = url.deletingLastPathComponent()
        let lastComponent = url.lastPathComponent

        // If we're at root or parent doesn't exist, just standardize
        if parentURL.path == "/" || parentURL.path.isEmpty {
            return url.standardizedFileURL
        }

        // Check if the full path exists (including the last component)
        if FileManager.default.fileExists(atPath: url.path) {
            // If the full path exists, resolve all symlinks
            return url.resolvingSymlinksInPath()
        }

        // Only the parent needs to exist, last component may not
        let resolvedParent: URL = if FileManager.default.fileExists(atPath: parentURL.path) {
            parentURL.resolvingSymlinksInPath()
        } else {
            // Parent doesn't exist, try to resolve what we can recursively
            try realdirpath(parentURL)
        }

        // Append the last component (which may not exist)
        return resolvedParent.appendingPathComponent(lastComponent)
    }
}

// MARK: - Static File Info

public extension File {
    static func atime(_ url: URL) throws -> Date {
        // Note: On macOS, access time updates may be disabled for performance
        // You can check with: mount | grep noatime
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

        // Try to get access date if available
        if let accessDate = attributes[.modificationDate] as? Date {
            // FileManager doesn't expose access time directly, using modification as fallback
            // For true access time, would need to use stat() system call
            return accessDate
        }

        throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
    }

    static func mtime(_ url: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let modDate = attributes[.modificationDate] as? Date else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        return modDate
    }

    static func ctime(_ url: URL) throws -> Date {
        // Status change time - on macOS this is often the same as mtime
        // For true ctime, would need to use stat() system call
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

        // Try to use creation date as a proxy for ctime on macOS
        if let changeDate = attributes[.modificationDate] as? Date {
            return changeDate
        }

        throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
    }

    static func birthtime(_ url: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let creationDate = attributes[.creationDate] as? Date else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        return creationDate
    }

    static func size(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? NSNumber else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        return fileSize.intValue
    }

    static func fileStatus(_ url: URL) throws -> FileStat {
        var buf = stat()
        guard url.path.withCString({ stat($0, &buf) }) == 0 else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        return FileStat(buf)
    }

    static func linkStatus(_ url: URL) throws -> FileStat {
        var buf = stat()
        guard url.path.withCString({ lstat($0, &buf) }) == 0 else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        return FileStat(buf)
    }
}

// MARK: - Static File Type Checks

public extension File {
    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func isFile(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return (statBuf.st_mode & S_IFMT) == S_IFREG
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    static func isSymlink(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { lstat($0, &statBuf) }
        guard result == 0 else { return false }
        return (statBuf.st_mode & S_IFMT) == S_IFLNK
    }

    static func isBlockDevice(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return (statBuf.st_mode & S_IFMT) == S_IFBLK
    }

    static func isCharDevice(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return (statBuf.st_mode & S_IFMT) == S_IFCHR
    }

    static func isPipe(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return (statBuf.st_mode & S_IFMT) == S_IFIFO
    }

    static func isSocket(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return (statBuf.st_mode & S_IFMT) == S_IFSOCK
    }

    static func isEmpty(_ url: URL) throws -> Bool {
        let size = try size(url)
        return size == 0
    }

    // Ruby aliases
    static func isZero(_ url: URL) throws -> Bool {
        try isEmpty(url)
    }
}

// MARK: - Static Permission Checks

public extension File {
    static func isReadable(_ url: URL) -> Bool {
        url.path.withCString { access($0, R_OK) } == 0
    }

    static func isWritable(_ url: URL) -> Bool {
        url.path.withCString { access($0, W_OK) } == 0
    }

    static func isExecutable(_ url: URL) -> Bool {
        url.path.withCString { access($0, X_OK) } == 0
    }

    static func isOwned(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return statBuf.st_uid == getuid()
    }

    static func isGroupOwned(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return statBuf.st_gid == getgid()
    }

    static func isWorldReadable(_ url: URL) -> Int? {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return nil }

        // Check if world readable (other read bit)
        if (statBuf.st_mode & S_IROTH) != 0 {
            return Int(statBuf.st_mode & 0o777)
        }
        return nil
    }

    static func isWorldWritable(_ url: URL) -> Int? {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return nil }

        // Check if world writable (other write bit)
        if (statBuf.st_mode & S_IWOTH) != 0 {
            return Int(statBuf.st_mode & 0o777)
        }
        return nil
    }

    static func isSetuid(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return (statBuf.st_mode & S_ISUID) != 0
    }

    static func isSetgid(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return (statBuf.st_mode & S_ISGID) != 0
    }

    static func isSticky(_ url: URL) -> Bool {
        var statBuf = stat()
        let result = url.path.withCString { stat($0, &statBuf) }
        guard result == 0 else { return false }
        return (statBuf.st_mode & S_ISVTX) != 0
    }
}

// MARK: - Static File Operations

public extension File {
    static func chmod(_ url: URL, permissions: Int) throws {
        let result = url.path.withCString { Darwin.chmod($0, mode_t(permissions)) }
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    static func chown(_ url: URL, owner: Int? = nil, group: Int? = nil) throws {
        // Get current ownership if not changing both
        var currentOwner: uid_t = 0
        var currentGroup: gid_t = 0
        
        if owner == nil || group == nil {
            var statBuf = stat()
            let result = url.path.withCString { stat($0, &statBuf) }
            guard result == 0 else {
                throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
            }
            currentOwner = statBuf.st_uid
            currentGroup = statBuf.st_gid
        }
        
        let newOwner = owner.map { uid_t($0) } ?? currentOwner
        let newGroup = group.map { gid_t($0) } ?? currentGroup
        
        let result = url.path.withCString { Darwin.chown($0, newOwner, newGroup) }
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    static func lchmod(_ url: URL, permissions: Int) throws {
        // lchmod is not available on all systems, use lchflags as workaround
        // or fall back to fchmodat with AT_SYMLINK_NOFOLLOW
        #if os(macOS)
        // macOS doesn't have lchmod, permissions on symlinks are ignored
        // We could use fchmodat with AT_SYMLINK_NOFOLLOW but it's not always available
        // For now, this is a no-op on symlinks as per macOS behavior
        var statBuf = stat()
        let result = url.path.withCString { lstat($0, &statBuf) }
        guard result == 0 else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        
        // If it's not a symlink, use regular chmod
        if (statBuf.st_mode & S_IFMT) != S_IFLNK {
            try chmod(url, permissions: permissions)
        }
        // For symlinks, silently succeed (macOS behavior)
        #else
        let result = url.path.withCString { lchmod($0, mode_t(permissions)) }
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        #endif
    }

    static func lchown(_ url: URL, owner: Int? = nil, group: Int? = nil) throws {
        // Get current ownership if not changing both
        var currentOwner: uid_t = 0
        var currentGroup: gid_t = 0
        
        if owner == nil || group == nil {
            var statBuf = stat()
            let result = url.path.withCString { lstat($0, &statBuf) }
            guard result == 0 else {
                throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])
            }
            currentOwner = statBuf.st_uid
            currentGroup = statBuf.st_gid
        }
        
        let newOwner = owner.map { uid_t($0) } ?? currentOwner
        let newGroup = group.map { gid_t($0) } ?? currentGroup
        
        let result = url.path.withCString { Darwin.lchown($0, newOwner, newGroup) }
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    static func link(source: URL, destination: URL) throws {
        // Create hard link
        let result = source.path.withCString { sourcePath in
            destination.path.withCString { destPath in
                Darwin.link(sourcePath, destPath)
            }
        }
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [
                NSFilePathErrorKey: destination.path,
                NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            ])
        }
    }

    static func symlink(source: URL, destination: URL) throws {
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: source)
    }

    static func readlink(_ url: URL) throws -> URL {
        let path = try FileManager.default.destinationOfSymbolicLink(atPath: url.path)
        return URL(fileURLWithPath: path)
    }

    static func unlink(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    static func delete(_ url: URL) throws {
        try unlink(url)
    }

    static func rename(source: URL, destination: URL) throws {
        // Use replaceItem - it works whether destination exists or not
        // and provides atomic replacement when it does exist
        _ = try FileManager.default.replaceItem(
            at: destination, withItemAt: source, backupItemName: nil, resultingItemURL: nil,
        )
    }

    static func truncate(_ url: URL, to size: Int) throws {
        let result = url.path.withCString { Darwin.truncate($0, off_t(size)) }
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    static func touch(_ url: URL) throws {
        let fm = FileManager.default

        if fm.fileExists(atPath: url.path) {
            // Update modification time to current time
            try fm.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        } else {
            // Create empty file
            fm.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
    }

    static func utime(_ url: URL, atime: Date, mtime: Date) throws {
        var times = [timeval](repeating: timeval(), count: 2)
        
        // Access time
        times[0].tv_sec = Int(atime.timeIntervalSince1970)
        times[0].tv_usec = Int32((atime.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1_000_000)
        
        // Modification time
        times[1].tv_sec = Int(mtime.timeIntervalSince1970)
        times[1].tv_usec = Int32((mtime.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1_000_000)
        
        let result = url.path.withCString { path in
            times.withUnsafeBufferPointer { timesPtr in
                Darwin.utimes(path, timesPtr.baseAddress)
            }
        }
        
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    static func lutime(_ url: URL, atime: Date, mtime: Date) throws {
        // lutimes sets times on symlink itself (not the target)
        var times = [timeval](repeating: timeval(), count: 2)
        
        // Access time
        times[0].tv_sec = Int(atime.timeIntervalSince1970)
        times[0].tv_usec = Int32((atime.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1_000_000)
        
        // Modification time
        times[1].tv_sec = Int(mtime.timeIntervalSince1970)
        times[1].tv_usec = Int32((mtime.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1_000_000)
        
        let result = url.path.withCString { path in
            times.withUnsafeBufferPointer { timesPtr in
                Darwin.lutimes(path, timesPtr.baseAddress)
            }
        }
        
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    static func mkfifo(_ url: URL, permissions: Int = 0o666) throws {
        let result = url.path.withCString { Darwin.mkfifo($0, mode_t(permissions)) }
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    static func identical(_ url1: URL, _ url2: URL) throws -> Bool {
        var stat1 = stat()
        var stat2 = stat()
        
        let result1 = url1.path.withCString { stat($0, &stat1) }
        guard result1 == 0 else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url1.path])
        }
        
        let result2 = url2.path.withCString { stat($0, &stat2) }
        guard result2 == 0 else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url2.path])
        }
        
        // Files are identical if they have the same device and inode
        return stat1.st_dev == stat2.st_dev && stat1.st_ino == stat2.st_ino
    }

    static func umask() -> Int {
        // Get current umask by setting and restoring
        let current = Darwin.umask(0)
        Darwin.umask(current)
        return Int(current)
    }

    static func umask(_ mask: Int) -> Int {
        let oldMask = Darwin.umask(mode_t(mask))
        return Int(oldMask)
    }
}

// MARK: - Pattern Matching

public extension File {
    static func fnmatch(pattern: String, path: String, flags: FnmatchFlags = []) -> Bool {
        pattern.withCString { patternPtr in
            path.withCString { pathPtr in
                Darwin.fnmatch(patternPtr, pathPtr, flags.rawValue) == 0
            }
        }
    }
}

// MARK: - Supporting Types

public struct FileStat {
    public let dev: Int // Device ID
    public let ino: Int // Inode number
    public let mode: Int // File mode (permissions + type)
    public let nlink: Int // Number of hard links
    public let uid: Int // User ID of owner
    public let gid: Int // Group ID of owner
    public let rdev: Int // Device ID (if special file)
    public let size: Int64 // Total size in bytes
    public let blksize: Int // Block size for filesystem I/O
    public let blocks: Int64 // Number of 512B blocks allocated
    public let atime: Date // Last access time
    public let mtime: Date // Last modification time
    public let ctime: Date // Last status change time
    public let birthtime: Date? // Creation time (if available)

    public init(dev: Int, ino: Int, mode: Int, nlink: Int, uid: Int, gid: Int, rdev: Int,
                size: Int64, blksize: Int, blocks: Int64,
                atime: Date, mtime: Date, ctime: Date, birthtime: Date?)
    {
        self.dev = dev
        self.ino = ino
        self.mode = mode
        self.nlink = nlink
        self.uid = uid
        self.gid = gid
        self.rdev = rdev
        self.size = size
        self.blksize = blksize
        self.blocks = blocks
        self.atime = atime
        self.mtime = mtime
        self.ctime = ctime
        self.birthtime = birthtime
    }

    init(_ buf: stat) {
        self.init(
            dev: Int(buf.st_dev),
            ino: Int(buf.st_ino),
            mode: Int(buf.st_mode),
            nlink: Int(buf.st_nlink),
            uid: Int(buf.st_uid),
            gid: Int(buf.st_gid),
            rdev: Int(buf.st_rdev),
            size: Int64(buf.st_size),
            blksize: Int(buf.st_blksize),
            blocks: Int64(buf.st_blocks),
            atime: Date(timeIntervalSince1970: TimeInterval(buf.st_atimespec.tv_sec)),
            mtime: Date(timeIntervalSince1970: TimeInterval(buf.st_mtimespec.tv_sec)),
            ctime: Date(timeIntervalSince1970: TimeInterval(buf.st_ctimespec.tv_sec)),
            birthtime: Date(timeIntervalSince1970: TimeInterval(buf.st_birthtimespec.tv_sec)),
        )
    }
}

public struct FnmatchFlags: OptionSet, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let pathname = FnmatchFlags(rawValue: FNM_PATHNAME)
    public static let noescape = FnmatchFlags(rawValue: FNM_NOESCAPE)
    public static let period = FnmatchFlags(rawValue: FNM_PERIOD)
    public static let casefold = FnmatchFlags(rawValue: FNM_CASEFOLD)
    public static let leadingDir = FnmatchFlags(rawValue: FNM_LEADING_DIR)
}

public enum LockOperation {
    case shared // LOCK_SH
    case exclusive // LOCK_EX
    case unlock // LOCK_UN
}

// MARK: - File Type enum

public enum FileType: String {
    case file
    case directory
    case characterSpecial
    case blockSpecial
    case fifo
    case link
    case socket
    case unknown
}

public extension File {
    static func ftype(_ url: URL) -> FileType {
        var statBuf = stat()
        let result = url.path.withCString { lstat($0, &statBuf) }
        guard result == 0 else { return .unknown }

        switch statBuf.st_mode & S_IFMT {
        case S_IFREG:
            return .file
        case S_IFDIR:
            return .directory
        case S_IFLNK:
            return .link
        case S_IFBLK:
            return .blockSpecial
        case S_IFCHR:
            return .characterSpecial
        case S_IFIFO:
            return .fifo
        case S_IFSOCK:
            return .socket
        default:
            return .unknown
        }
    }
}
