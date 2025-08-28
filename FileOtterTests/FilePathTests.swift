//
//  FilePathTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import XCTest

final class FilePathTests: XCTestCase {
    var tempDir: URL!
    var originalWorkingDirectory: String!

    override func setUpWithError() throws {
        originalWorkingDirectory = FileManager.default.currentDirectoryPath
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FilePathTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(originalWorkingDirectory)
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - basename Tests

    func testBasename() throws {
        let url1 = URL(fileURLWithPath: "/Users/sjs/file.txt")
        XCTAssertEqual(File.basename(url1), "file.txt")

        let url2 = URL(fileURLWithPath: "/Users/sjs/dir/")
        XCTAssertEqual(File.basename(url2), "dir")

        let url3 = URL(fileURLWithPath: "/")
        XCTAssertEqual(File.basename(url3), "/")

        let url4 = URL(fileURLWithPath: "file.rb")
        XCTAssertEqual(File.basename(url4), "file.rb")
    }

    func testBasenameWithSuffix() throws {
        let url = URL(fileURLWithPath: "/Users/sjs/file.txt")
        XCTAssertEqual(File.basename(url, suffix: ".txt"), "file")
        XCTAssertEqual(File.basename(url, suffix: ".rb"), "file.txt")

        let url2 = URL(fileURLWithPath: "/Users/sjs/archive.tar.gz")
        XCTAssertEqual(File.basename(url2, suffix: ".gz"), "archive.tar")
        XCTAssertEqual(File.basename(url2, suffix: ".tar.gz"), "archive")
    }

    func testBasenameWithWildcardSuffix() throws {
        let url = URL(fileURLWithPath: "/Users/sjs/file.txt")
        XCTAssertEqual(File.basename(url, suffix: ".*"), "file")

        let url2 = URL(fileURLWithPath: "/Users/sjs/archive.tar.gz")
        XCTAssertEqual(File.basename(url2, suffix: ".*"), "archive.tar")

        let url3 = URL(fileURLWithPath: "/Users/sjs/noext")
        XCTAssertEqual(File.basename(url3, suffix: ".*"), "noext")
    }

    // MARK: - dirname Tests

    func testDirname() throws {
        let url1 = URL(fileURLWithPath: "/Users/sjs/file.txt")
        XCTAssertEqual(File.dirname(url1).path(), "/Users/sjs/")

        let url2 = URL(fileURLWithPath: "/Users/sjs/dir/")
        XCTAssertEqual(File.dirname(url2).path(), "/Users/sjs/")

        let url3 = URL(fileURLWithPath: "/file.txt")
        XCTAssertEqual(File.dirname(url3).path(), "/")

        let url4 = URL(fileURLWithPath: "file.txt")
        XCTAssertEqual(File.dirname(url4).path(), "./")
    }

    func testDirnameWithLevel() throws {
        let url = URL(fileURLWithPath: "/Users/sjs/dir/file.txt")
        XCTAssertEqual(File.dirname(url, level: 1).path(), "/Users/sjs/dir/")
        XCTAssertEqual(File.dirname(url, level: 2).path(), "/Users/sjs/")
        XCTAssertEqual(File.dirname(url, level: 3).path(), "/Users/")
        XCTAssertEqual(File.dirname(url, level: 4).path(), "/")
        XCTAssertEqual(File.dirname(url, level: 5).path(), "/") // Can't go beyond root
    }

    // MARK: - extname Tests

    func testExtname() throws {
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "test.rb")), ".rb")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "a/b/d/test.rb")), ".rb")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: ".a/b/d/test.rb")), ".rb")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "test")), "")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "test.tar.gz")), ".gz")
    }

    func testExtnameWithDotfile() throws {
        XCTAssertEqual(File.extname(URL(fileURLWithPath: ".profile")), "")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: ".profile.sh")), ".sh")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "/Users/sjs/.bashrc")), "")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "/Users/sjs/.config.bak")), ".bak")
    }

    // MARK: - split Tests

    func testSplit() throws {
        let (dir1, name1) = File.split(URL(fileURLWithPath: "/Users/sjs/file.txt"))
        XCTAssertEqual(dir1.path, "/Users/sjs")
        XCTAssertEqual(name1, "file.txt")

        let (dir2, name2) = File.split(URL(fileURLWithPath: "/file.txt"))
        XCTAssertEqual(dir2.path, "/")
        XCTAssertEqual(name2, "file.txt")

        let (dir3, name3) = File.split(URL(fileURLWithPath: "file.txt"))
        XCTAssertEqual(dir3.path(), "./")
        XCTAssertEqual(name3, "file.txt")

        let (dir4, name4) = File.split(URL(fileURLWithPath: "/Users/sjs/"))
        XCTAssertEqual(dir4.path, "/Users")
        XCTAssertEqual(name4, "sjs")

        // Root path edge case
        let (dir5, name5) = File.split(URL(fileURLWithPath: "/"))
        XCTAssertEqual(dir5.path, "/")
        XCTAssertEqual(name5, "")
    }

    // MARK: - join Tests

    func testJoin() throws {
        let u = URL(fileURLWithPath: "hello")
        XCTAssertEqual(File.join(u.path(), "world").path(), "hello/world")

        XCTAssertEqual(File.join("usr", "mail", "gumby").path(), "usr/mail/gumby")
        XCTAssertEqual(File.join("/usr", "mail", "gumby").path(), "/usr/mail/gumby")
        XCTAssertEqual(File.join("/", "usr", "bin").path(), "/usr/bin/")

        // Single component
        XCTAssertEqual(File.join("file.txt").path(), "file.txt")
        XCTAssertEqual(File.join("/file.txt").path(), "/file.txt")

        // Empty components are ignored
        XCTAssertEqual(File.join("usr", "", "bin").path(), "usr/bin")

        // Handles trailing slashes
        XCTAssertEqual(File.join("/usr/", "local/", "bin").path(), "/usr/local/bin/")
    }

    func testJoinWithArray() throws {
        let components = ["usr", "local", "bin"]
        XCTAssertEqual(File.join(components).path(), "usr/local/bin")

        let absoluteComponents = ["/usr", "local", "bin"]
        XCTAssertEqual(File.join(absoluteComponents).path(), "/usr/local/bin/")

        let singleComponent = ["file.txt"]
        XCTAssertEqual(File.join(singleComponent).path(), "file.txt")
    }

    // MARK: - absolutePath Tests

    func testAbsolutePath() throws {
        // Test already absolute path
        let absoluteURL = URL(fileURLWithPath: "/usr/bin/swift")
        XCTAssertEqual(File.absolutePath(absoluteURL).path, "/usr/bin/swift")

        // Test relative path - URL constructor will use current directory
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        let relativeURL = URL(fileURLWithPath: "file.txt")
        let absPath = File.absolutePath(relativeURL)
        // The URL is already absolute at this point, we just normalize it
        XCTAssertTrue(absPath.path.hasSuffix("file.txt"))
        XCTAssertTrue(absPath.path.hasPrefix("/"))
    }

    func testAbsolutePathNormalization() throws {
        // Test that .. and . are resolved
        let pathWithDots = URL(fileURLWithPath: "/usr/../bin/./swift")
        XCTAssertEqual(File.absolutePath(pathWithDots).path, "/bin/swift")

        // Test multiple .. segments
        let pathWithMultipleDots = URL(fileURLWithPath: "/usr/local/../../bin")
        XCTAssertEqual(File.absolutePath(pathWithMultipleDots).path, "/bin")

        // Test trailing slash removal
        let pathWithTrailingSlash = URL(fileURLWithPath: "/usr/bin/")
        XCTAssertEqual(File.absolutePath(pathWithTrailingSlash).path, "/usr/bin")
    }

    // MARK: - expandPath Tests

    func testExpandPath() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser

        // Test expanding ~
        let expanded1 = File.expandPath("~")
        XCTAssertEqual(expanded1.path, homeDir.path)

        // Test expanding ~/Documents
        let expanded2 = File.expandPath("~/Documents")
        XCTAssertEqual(expanded2.path, homeDir.appendingPathComponent("Documents").path)

        // Test regular path (no expansion needed)
        let expanded3 = File.expandPath("/usr/bin")
        XCTAssertEqual(expanded3.path, "/usr/bin")
    }

    // MARK: - realpath Tests

    func testRealpath() throws {
        // Create a real file
        let fileURL = tempDir.appendingPathComponent("realfile.txt")
        try "test content".write(to: fileURL, atomically: true, encoding: .utf8)

        // Test resolving a real file
        let resolved = try File.realpath(fileURL)
        XCTAssertEqual(resolved.path, fileURL.path)

        // Create a symlink
        let symlinkURL = tempDir.appendingPathComponent("symlink.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: fileURL)

        // Test resolving symlink
        let resolvedSymlink = try File.realpath(symlinkURL)
        XCTAssertEqual(resolvedSymlink.path, fileURL.path)
    }

    func testRealpathThrowsForNonExistent() throws {
        let nonExistentURL = tempDir.appendingPathComponent("nonexistent.txt")

        XCTAssertThrowsError(try File.realpath(nonExistentURL)) { error in
            // Should throw file not found error
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, CocoaError.fileNoSuchFile.rawValue)
        }
    }

    // MARK: - realdirpath Tests

    func testRealdirpath() throws {
        // Create a directory
        let dirURL = tempDir.appendingPathComponent("realdir")
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        // Test resolving existing directory
        let resolved = try File.realdirpath(dirURL)
        XCTAssertEqual(resolved.path, dirURL.path)

        // Create a symlink to the directory
        let symlinkDirURL = tempDir.appendingPathComponent("symlinkdir")
        try FileManager.default.createSymbolicLink(at: symlinkDirURL, withDestinationURL: dirURL)

        // Test resolving symlinked directory
        let resolvedSymlink = try File.realdirpath(symlinkDirURL)
        XCTAssertEqual(resolvedSymlink.path, dirURL.path)
    }

    func testRealdirpathWithNonExistentLast() throws {
        // Create a real directory
        let dirURL = tempDir.appendingPathComponent("realdir")
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        // Test with non-existent file in existing directory
        let nonExistentFile = dirURL.appendingPathComponent("future-file.txt")
        let resolved = try File.realdirpath(nonExistentFile)
        XCTAssertEqual(resolved.path, nonExistentFile.path)
    }
}
