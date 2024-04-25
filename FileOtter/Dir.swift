//
//  Dir.swift
//  FileOtter
//
//  Created by Sami Samhuri on 2024-04-24.
//

import Foundation

public struct Dir: Equatable, Hashable, RandomAccessCollection {
    public let startIndex: Int

    public let endIndex: Int

    public let url: URL

    public init(url: URL) throws {
        self.init(url: url, children: try Dir.children(url))
    }

    private let children: [URL]

    private init(url: URL, children: [URL]) {
        self.url = url
        self.children = children
        startIndex = children.startIndex
        endIndex = children.endIndex
    }
}

// MARK: - Well-known Directories
extension Dir {
    public static var caches: URL {
        URL.cachesDirectory
    }

    public static var current: URL {
        URL.currentDirectory()
    }

    public static var documents: URL {
        URL.documentsDirectory
    }

    public static var home: URL {
        URL.homeDirectory
    }

    public static var library: URL {
        URL.libraryDirectory
    }

    public static var pwd: URL {
        .currentDirectory()
    }

    public static var getwd: URL {
        .currentDirectory()
    }
}

// MARK: - Mutations
extension Dir {
    @discardableResult
    public static func chdir(_ url: URL) -> Bool {
        FileManager.default.changeCurrentDirectoryPath(url.path)
    }

    @discardableResult
    public static func chdir<T>(_ url: URL, block: (URL) -> T) -> T {
        let previousDir = pwd
        FileManager.default.changeCurrentDirectoryPath(url.path)
        defer {
            FileManager.default.changeCurrentDirectoryPath(previousDir.path)
        }
        return block(url)
    }

    @discardableResult
    public static func unlink(_ url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public static func rmdir(_ url: URL) -> Bool {
        unlink(url)
    }

    @discardableResult
    public static func delete(_ url: URL) -> Bool {
        unlink(url)
    }
}

// MARK: - Reading Contents
extension Dir {
    public static func children(_ url: URL) throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }

    public static func entries(_ url: URL) throws -> [String] {
        #warning("TODO: implement this ... maybe, it's dumb")
        return []
    }

    public static func exists(_ url: URL) throws -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    public static func isEmpty(_ url: URL) throws -> Bool {
        try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            .isEmpty
    }
}

// MARK: - Globbing
extension Dir {
    public static func glob(base: URL? = nil, _ patterns: String...) -> [URL] {
        _glob(base: base, patterns: patterns)
    }

    public static subscript(base: URL? = nil, _ patterns: String...) -> [URL] {
        _glob(base: base, patterns: patterns)
    }

    private static func _glob(base: URL?, patterns: [String]) -> [URL] {
        #warning("TODO: implement me")
        return []
    }
}

// MARK: - RandomAccessCollection
extension Dir {
    public func makeIterator() -> any IteratorProtocol<URL> {
        children.makeIterator()
    }

    public subscript(position: Int) -> URL {
        children[position]
    }
}
