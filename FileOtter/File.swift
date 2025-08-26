//
//  File.swift
//  FileOtter
//
//  Created by Sami Samhuri on 2025-08-19.
//

import Foundation

// MARK: - File Class

/// A File object represents an open file with automatic resource management.
/// The file handle is automatically closed when the File object is deallocated.
public class File: CustomStringConvertible, CustomDebugStringConvertible {
    private let handle: FileHandle
    public let url: URL
    public let mode: Mode
    
    // MARK: - Mode
    
    public enum Mode {
        case read           // r
        case write          // w
        case append         // a
        case readWrite      // r+
        case readWriteNew   // w+
        case readAppend     // a+
        case writeExclusive // wx (create, fail if exists)
    }
    
    // MARK: - Initialization
    
    public init(url: URL, mode: Mode = .read, permissions: Int = 0o666) throws {
        self.url = url
        self.mode = mode
        self.handle = FileHandle() // TODO: Implement proper opening
        fatalError("Not implemented")
    }
    
    deinit {
        try? handle.close()
    }
    
    // MARK: - Opening with blocks
    
    public static func open(url: URL, mode: Mode = .read, permissions: Int = 0o666) throws -> File {
        fatalError("Not implemented")
    }
    
    @discardableResult
    public static func open<T>(url: URL, mode: Mode = .read, permissions: Int = 0o666, _ block: (File) throws -> T) rethrows -> T {
        fatalError("Not implemented")
    }
    
    // MARK: - Instance Properties
    
    public var atime: Date {
        fatalError("Not implemented")
    }
    
    public var mtime: Date {
        fatalError("Not implemented")
    }
    
    public var ctime: Date {
        fatalError("Not implemented")
    }
    
    public var birthtime: Date {
        fatalError("Not implemented")
    }
    
    public var size: Int {
        fatalError("Not implemented")
    }
    
    // MARK: - Instance Methods
    
    public func chmod(_ permissions: Int) throws {
        fatalError("Not implemented")
    }
    
    public func chown(owner: Int? = nil, group: Int? = nil) throws {
        fatalError("Not implemented")
    }
    
    public func truncate(to size: Int) throws {
        fatalError("Not implemented")
    }
    
    public func flock(_ operation: LockOperation) throws {
        fatalError("Not implemented")
    }
    
    public func stat() throws -> FileStat {
        fatalError("Not implemented")
    }
    
    public func lstat() throws -> FileStat {
        fatalError("Not implemented")
    }
    
    public func close() throws {
        fatalError("Not implemented")
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
    static func basename(_ url: URL, suffix: String? = nil) -> String {
        // Handle root path special case
        if url.path == "/" {
            return "/"
        }
        
        // Get the last path component using URL's built-in method
        let base = url.lastPathComponent
        
        // If no suffix specified, return the base
        guard let suffix = suffix else {
            return base
        }
        
        // Handle wildcard suffix ".*"
        if suffix == ".*" {
            // Use URL's pathExtension to remove any extension
            let withoutExt = url.deletingPathExtension().lastPathComponent
            return withoutExt
        }
        
        // Handle regular suffix
        if base.hasSuffix(suffix) {
            return String(base.dropLast(suffix.count))
        }
        
        return base
    }
    
    static func dirname(_ url: URL, level: Int = 1) -> URL {
        var result = url
        for _ in 0..<level where result.path != "/" {
            result = result.deletingLastPathComponent()
        }
        return result
    }
    
    static func extname(_ url: URL) -> String {
        let ext = url.pathExtension
        return ext.isEmpty ? "" : ".\(ext)"
    }
    
    static func split(_ url: URL) -> (dir: URL, name: String) {
        let dir = url.deletingLastPathComponent()
        let name = url.lastPathComponent
        
        // Handle root path special case
        if url.path == "/" {
            return (url, "")
        }
        
        return (dir, name)
    }
    
    static func join(_ components: String...) -> URL {
        join(components)
    }
    
    static func join(_ components: [String]) -> URL {
        // Filter out empty components
        let nonEmptyComponents = components.filter { !$0.isEmpty }
        
        guard !nonEmptyComponents.isEmpty else {
            return URL(fileURLWithPath: ".")
        }
        
        // Start with the first component to preserve absolute/relative nature
        var result = URL(fileURLWithPath: nonEmptyComponents[0])
        
        // Append remaining components
        for component in nonEmptyComponents.dropFirst() {
            // Remove leading/trailing slashes from component before appending
            let trimmed = component.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !trimmed.isEmpty {
                result.appendPathComponent(trimmed)
            }
        }
        
        return result
    }
    
    static func absolutePath(_ url: URL, relativeTo base: URL? = nil) -> URL {
        fatalError("Not implemented")
    }
    
    static func expandPath(_ path: String) -> URL {
        fatalError("Not implemented")
    }
    
    static func realpath(_ url: URL) throws -> URL {
        fatalError("Not implemented")
    }
    
    static func realdirpath(_ url: URL) throws -> URL {
        fatalError("Not implemented")
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
    
    static func stat(_ url: URL) throws -> FileStat {
        fatalError("Not implemented")
    }
    
    static func lstat(_ url: URL) throws -> FileStat {
        fatalError("Not implemented")
    }
}

// MARK: - Static File Type Checks

public extension File {
    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    static func isFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }
    
    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    static func isSymlink(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isBlockDevice(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isCharDevice(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isPipe(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isSocket(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isEmpty(_ url: URL) throws -> Bool {
        fatalError("Not implemented")
    }
    
    // Ruby aliases
    static func isZero(_ url: URL) throws -> Bool {
        try isEmpty(url)
    }
}

// MARK: - Static Permission Checks

public extension File {
    static func isReadable(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isWritable(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isExecutable(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isOwned(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isGroupOwned(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isWorldReadable(_ url: URL) -> Int? {
        fatalError("Not implemented")
    }
    
    static func isWorldWritable(_ url: URL) -> Int? {
        fatalError("Not implemented")
    }
    
    static func isSetuid(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isSetgid(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
    
    static func isSticky(_ url: URL) -> Bool {
        fatalError("Not implemented")
    }
}

// MARK: - Static File Operations

public extension File {
    static func chmod(_ url: URL, permissions: Int) throws {
        fatalError("Not implemented")
    }
    
    static func chown(_ url: URL, owner: Int? = nil, group: Int? = nil) throws {
        fatalError("Not implemented")
    }
    
    static func lchmod(_ url: URL, permissions: Int) throws {
        fatalError("Not implemented")
    }
    
    static func lchown(_ url: URL, owner: Int? = nil, group: Int? = nil) throws {
        fatalError("Not implemented")
    }
    
    static func link(source: URL, destination: URL) throws {
        fatalError("Not implemented")
    }
    
    static func symlink(source: URL, destination: URL) throws {
        fatalError("Not implemented")
    }
    
    static func readlink(_ url: URL) throws -> URL {
        fatalError("Not implemented")
    }
    
    static func unlink(_ url: URL) throws {
        fatalError("Not implemented")
    }
    
    static func delete(_ url: URL) throws {
        try unlink(url)
    }
    
    static func rename(source: URL, destination: URL) throws {
        fatalError("Not implemented")
    }
    
    static func truncate(_ url: URL, to size: Int) throws {
        fatalError("Not implemented")
    }
    
    static func touch(_ url: URL) throws {
        fatalError("Not implemented")
    }
    
    static func utime(_ url: URL, atime: Date, mtime: Date) throws {
        fatalError("Not implemented")
    }
    
    static func lutime(_ url: URL, atime: Date, mtime: Date) throws {
        fatalError("Not implemented")
    }
    
    static func mkfifo(_ url: URL, permissions: Int = 0o666) throws {
        fatalError("Not implemented")
    }
    
    static func identical(_ url1: URL, _ url2: URL) throws -> Bool {
        fatalError("Not implemented")
    }
    
    static func umask() -> Int {
        fatalError("Not implemented")
    }
    
    static func umask(_ mask: Int) -> Int {
        fatalError("Not implemented")
    }
}

// MARK: - Pattern Matching

public extension File {
    static func fnmatch(pattern: String, path: String, flags: FnmatchFlags = []) -> Bool {
        fatalError("Not implemented")
    }
}

// MARK: - Supporting Types

public struct FileStat {
    public let dev: Int          // Device ID
    public let ino: Int          // Inode number
    public let mode: Int         // File mode (permissions + type)
    public let nlink: Int        // Number of hard links
    public let uid: Int          // User ID of owner
    public let gid: Int          // Group ID of owner
    public let rdev: Int         // Device ID (if special file)
    public let size: Int64       // Total size in bytes
    public let blksize: Int      // Block size for filesystem I/O
    public let blocks: Int64     // Number of 512B blocks allocated
    public let atime: Date       // Last access time
    public let mtime: Date       // Last modification time
    public let ctime: Date       // Last status change time
    public let birthtime: Date?  // Creation time (if available)
}

public struct FnmatchFlags: OptionSet {
    public let rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let pathname    = FnmatchFlags(rawValue: 1 << 0)  // FNM_PATHNAME
    public static let noescape    = FnmatchFlags(rawValue: 1 << 1)  // FNM_NOESCAPE
    public static let period      = FnmatchFlags(rawValue: 1 << 2)  // FNM_PERIOD
    public static let casefold    = FnmatchFlags(rawValue: 1 << 3)  // FNM_CASEFOLD
    public static let extglob     = FnmatchFlags(rawValue: 1 << 4)  // FNM_EXTGLOB
    public static let dotmatch    = FnmatchFlags(rawValue: 1 << 5)  // FNM_DOTMATCH (custom)
}

public enum LockOperation {
    case shared         // LOCK_SH
    case exclusive      // LOCK_EX
    case unlock         // LOCK_UN
    case nonBlocking    // LOCK_NB (can be OR'd with others)
}

// MARK: - File Type enum

public enum FileType: String {
    case file = "file"
    case directory = "directory"
    case characterSpecial = "characterSpecial"
    case blockSpecial = "blockSpecial"
    case fifo = "fifo"
    case link = "link"
    case socket = "socket"
    case unknown = "unknown"
}

public extension File {
    static func ftype(_ url: URL) -> FileType {
        fatalError("Not implemented")
    }
}
