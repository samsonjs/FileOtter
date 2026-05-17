//
//  Dir.swift
//  FileOtter
//
//  Created by Sami Samhuri on 2024-04-24.
//

import Foundation

public struct Dir: Equatable, Hashable, RandomAccessCollection, CustomStringConvertible, CustomDebugStringConvertible {
    public let startIndex: Int

    public let endIndex: Int

    public let url: URL

    public init(url: URL) throws {
        try self.init(url: url, children: Dir.children(url))
    }

    private let children: [URL]

    private init(url: URL, children: [URL]) {
        self.url = url
        self.children = children
        startIndex = children.startIndex
        endIndex = children.endIndex
    }

    public var description: String {
        url.path
    }

    public var debugDescription: String {
        "<Dir:\(url.path)>"
    }
}

// MARK: - Well-known Directories

public extension Dir {
    static var caches: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? home
    }

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? home
    }

    static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var library: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first ?? home
    }

    static var pwd: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static var tmp: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
}

// MARK: - Mutations

public extension Dir {
    static func chdir(_ url: URL) throws {
        guard FileManager.default.changeCurrentDirectoryPath(url.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    @discardableResult
    static func chdir<T>(_ url: URL, block: (URL) throws -> T) rethrows -> T {
        let previousDir = pwd
        FileManager.default.changeCurrentDirectoryPath(url.path)
        defer {
            FileManager.default.changeCurrentDirectoryPath(previousDir.path)
        }
        return try block(url)
    }

    static func unlink(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    static func rmdir(_ url: URL) throws {
        try unlink(url)
    }

    static func mkdir(_ url: URL, permissions: Int = 0o755) throws {
        let attributes: [FileAttributeKey: Any] = [
            .posixPermissions: permissions,
        ]
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: false,
            attributes: attributes,
        )
    }

    @discardableResult
    static func mktmpdir(prefix: String = "d", suffix: String = "") throws -> URL {
        let tmpBase = URL.temporaryDirectory
        let dirName = suffix.isEmpty ? "\(prefix)-\(UUID().uuidString)" : "\(prefix)-\(UUID().uuidString)-\(suffix)"
        let tmpDir = tmpBase.appendingPathComponent(dirName)
        try FileManager.default.createDirectory(
            at: tmpDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700],
        )
        return tmpDir
    }

    @discardableResult
    static func mktmpdir<T>(
        prefix: String = "d",
        suffix: String = "",
        _ block: (URL) throws -> T,
    ) throws -> T {
        let tmpDir = try mktmpdir(prefix: prefix, suffix: suffix)
        defer {
            try? FileManager.default.removeItem(at: tmpDir)
        }
        return try block(tmpDir)
    }
}

// MARK: - Reading Contents

public extension Dir {
    static func children(_ url: URL) throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }

    static func exists(_ url: URL) throws -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    static func isEmpty(_ url: URL) throws -> Bool {
        try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            .isEmpty
    }
}

// MARK: - Globbing

public extension Dir {
    static func glob(base: URL? = nil, _ patterns: String...) -> [URL] {
        _glob(base: base, patterns: patterns)
    }

    static subscript(base: URL?, _ patterns: String...) -> [URL] {
        _glob(base: base, patterns: patterns)
    }

    static subscript(_ patterns: String...) -> [URL] {
        _glob(base: nil, patterns: Array(patterns))
    }

    private static func _glob(base: URL?, patterns: [String]) -> [URL] {
        patterns.flatMap { pattern in
            globstar(pattern, base: base)
        }.map { URL(fileURLWithPath: $0) }
    }
}

// MARK: - RandomAccessCollection

public extension Dir {
    func makeIterator() -> any IteratorProtocol<URL> {
        children.makeIterator()
    }

    subscript(position: Int) -> URL {
        children[position]
    }
}
