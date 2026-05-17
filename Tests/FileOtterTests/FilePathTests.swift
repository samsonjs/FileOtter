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
        XCTAssertEqual(File.basename("/Users/sjs/file.txt"), "file.txt")
        XCTAssertEqual(File.basename("/Users/sjs/dir/"), "dir")
        XCTAssertEqual(File.basename("/"), "/")
        XCTAssertEqual(File.basename("file.rb"), "file.rb")
    }

    func testBasenameEdgeCases() throws {
        // Empty path
        XCTAssertEqual(File.basename(""), "")
        // Trailing slashes are stripped (Ruby parity)
        XCTAssertEqual(File.basename("foo.txt/"), "foo.txt")
        XCTAssertEqual(File.basename("/foo/bar/"), "bar")
        XCTAssertEqual(File.basename("/foo/bar///"), "bar")
        XCTAssertEqual(File.basename("dir///base"), "base")
        XCTAssertEqual(File.basename("dir///base/"), "base")
        // Single component
        XCTAssertEqual(File.basename("foo"), "foo")
        // Dot paths are returned as-is
        XCTAssertEqual(File.basename("."), ".")
        XCTAssertEqual(File.basename(".."), "..")
        // Just slashes collapse to root
        XCTAssertEqual(File.basename("///"), "/")
        XCTAssertEqual(File.basename("//"), "/")
        // Short rooted paths
        XCTAssertEqual(File.basename("/a"), "a")
        XCTAssertEqual(File.basename("/a/b"), "b")
        XCTAssertEqual(File.basename("/tmp"), "tmp")
        XCTAssertEqual(File.basename("/tmp/"), "tmp")
        // Unicode
        XCTAssertEqual(File.basename("/path/Офис.m4a"), "Офис.m4a")
    }

    func testBasenameWithSuffix() throws {
        XCTAssertEqual(File.basename("/Users/sjs/file.txt", suffix: ".txt"), "file")
        XCTAssertEqual(File.basename("/Users/sjs/file.txt", suffix: ".rb"), "file.txt")
        XCTAssertEqual(File.basename("/Users/sjs/archive.tar.gz", suffix: ".gz"), "archive.tar")
        XCTAssertEqual(File.basename("/Users/sjs/archive.tar.gz", suffix: ".tar.gz"), "archive")
        // Ruby: stripping suffix can leave an empty string
        XCTAssertEqual(File.basename(".rb", suffix: ".rb"), "")
        // Suffix that doesn't match returns base unchanged
        XCTAssertEqual(File.basename("foo", suffix: ".ext"), "foo")
        XCTAssertEqual(File.basename("s", suffix: "_a"), "s")
        // Suffix can be any trailing substring, not just a dotted extension
        XCTAssertEqual(File.basename("baz.rb", suffix: "z.rb"), "ba")
        // Trailing slash stripped before suffix match
        XCTAssertEqual(File.basename("foo.rb/", suffix: ".rb"), "foo")
    }

    func testBasenameWithWildcardSuffix() throws {
        XCTAssertEqual(File.basename("/Users/sjs/file.txt", suffix: ".*"), "file")
        XCTAssertEqual(File.basename("/Users/sjs/archive.tar.gz", suffix: ".*"), "archive.tar")
        XCTAssertEqual(File.basename("/Users/sjs/noext", suffix: ".*"), "noext")
        // Dotfiles have no extension to strip
        XCTAssertEqual(File.basename(".profile", suffix: ".*"), ".profile")
        XCTAssertEqual(File.basename("/Users/sjs/.bashrc", suffix: ".*"), ".bashrc")
    }

    // MARK: - dirname Tests

    func testDirname() throws {
        XCTAssertEqual(File.dirname("/Users/sjs/file.txt"), "/Users/sjs")
        XCTAssertEqual(File.dirname("/Users/sjs/dir/"), "/Users/sjs")
        XCTAssertEqual(File.dirname("/file.txt"), "/")
        XCTAssertEqual(File.dirname("file.txt"), ".")
    }

    func testDirnameEdgeCases() throws {
        XCTAssertEqual(File.dirname(""), ".")
        XCTAssertEqual(File.dirname("/"), "/")
        XCTAssertEqual(File.dirname("."), ".")
        XCTAssertEqual(File.dirname("./"), ".")
        XCTAssertEqual(File.dirname(".."), ".")
        XCTAssertEqual(File.dirname("../"), ".")
        XCTAssertEqual(File.dirname("foo"), ".")
        // Trailing slash on a single component
        XCTAssertEqual(File.dirname("foo/"), ".")
        // Interior slash runs are preserved (Ruby parity)
        XCTAssertEqual(File.dirname("a/b//c"), "a/b")
        XCTAssertEqual(File.dirname("a//b"), "a")
        XCTAssertEqual(File.dirname("/holy///schnikies//w00t.bin"), "/holy///schnikies")
        // Dot components are not normalized
        XCTAssertEqual(File.dirname("/foo/."), "/foo")
        XCTAssertEqual(File.dirname("/foo/./"), "/foo")
        XCTAssertEqual(File.dirname("/foo/../."), "/foo/..")
        XCTAssertEqual(File.dirname("foo/../"), "foo")
        XCTAssertEqual(File.dirname("/."), "/")
        // Trailing slash above root
        XCTAssertEqual(File.dirname("/foo/"), "/")
    }

    func testDirnameLeadingSlashes() throws {
        // Ruby collapses 2+ leading slashes in the dirname result down to 1.
        XCTAssertEqual(File.dirname("/////foo/bar/"), "/foo")
        XCTAssertEqual(File.dirname("/////"), "/")
        XCTAssertEqual(File.dirname("//foo//"), "/")
    }

    func testDirnameWithLevel() throws {
        XCTAssertEqual(File.dirname("/Users/sjs/dir/file.txt", level: 1), "/Users/sjs/dir")
        XCTAssertEqual(File.dirname("/Users/sjs/dir/file.txt", level: 2), "/Users/sjs")
        XCTAssertEqual(File.dirname("/Users/sjs/dir/file.txt", level: 3), "/Users")
        XCTAssertEqual(File.dirname("/Users/sjs/dir/file.txt", level: 4), "/")
        XCTAssertEqual(File.dirname("/Users/sjs/dir/file.txt", level: 5), "/") // Can't go beyond root
        // Relative path overshoot
        XCTAssertEqual(File.dirname("a/b", level: 10), ".")
        XCTAssertEqual(File.dirname("/Users/sjs/dir/file.txt", level: 100), "/")
        // level: 0 is identity
        XCTAssertEqual(File.dirname("poot.txt", level: 0), "poot.txt")
        XCTAssertEqual(File.dirname("/", level: 0), "/")
    }

    // MARK: - extname Tests

    func testExtname() throws {
        XCTAssertEqual(File.extname("test.rb"), ".rb")
        XCTAssertEqual(File.extname("a/b/d/test.rb"), ".rb")
        XCTAssertEqual(File.extname(".a/b/d/test.rb"), ".rb")
        XCTAssertEqual(File.extname("test"), "")
        XCTAssertEqual(File.extname("test.tar.gz"), ".gz")
    }

    func testExtnameWithDotfile() throws {
        XCTAssertEqual(File.extname(".profile"), "")
        XCTAssertEqual(File.extname(".profile.sh"), ".sh")
        XCTAssertEqual(File.extname("/Users/sjs/.bashrc"), "")
        XCTAssertEqual(File.extname("/Users/sjs/.config.bak"), ".bak")
    }

    func testExtnameEdgeCases() throws {
        XCTAssertEqual(File.extname(""), "")
        // All-dots basenames have no extension
        XCTAssertEqual(File.extname("."), "")
        XCTAssertEqual(File.extname(".."), "")
        XCTAssertEqual(File.extname("..."), "")
        XCTAssertEqual(File.extname("...."), "")
        // Ruby keeps a trailing-dot extension as "." on POSIX
        XCTAssertEqual(File.extname("foo."), ".")
        XCTAssertEqual(File.extname("foo.bar."), ".")
        XCTAssertEqual(File.extname(".foo."), ".")
        // Leading double-dot file: ".rb" is the extension
        XCTAssertEqual(File.extname("..rb"), ".rb")
        // Dot only in a directory component, not the basename
        XCTAssertEqual(File.extname("/foo.bar/baz"), "")
        XCTAssertEqual(File.extname("/foo/bar.baz/qux"), "")
        XCTAssertEqual(File.extname("/foo.rb/bar.c"), ".c")
        // Interior slash runs
        XCTAssertEqual(File.extname("/tmp//bla.rb"), ".rb")
        // Multiple dots — last one wins
        XCTAssertEqual(File.extname("a.b.c.d.e"), ".e")
        XCTAssertEqual(File.extname(".app.conf"), ".conf")
        // Roots
        XCTAssertEqual(File.extname("/"), "")
        XCTAssertEqual(File.extname("/."), "")
        // Unicode
        XCTAssertEqual(File.extname("Имя.m4a"), ".m4a")
    }

    // MARK: - split Tests

    func testSplit() throws {
        let (dir1, name1) = File.split("/Users/sjs/file.txt")
        XCTAssertEqual(dir1, "/Users/sjs")
        XCTAssertEqual(name1, "file.txt")

        let (dir2, name2) = File.split("/file.txt")
        XCTAssertEqual(dir2, "/")
        XCTAssertEqual(name2, "file.txt")

        let (dir3, name3) = File.split("file.txt")
        XCTAssertEqual(dir3, ".")
        XCTAssertEqual(name3, "file.txt")

        let (dir4, name4) = File.split("/Users/sjs/")
        XCTAssertEqual(dir4, "/Users")
        XCTAssertEqual(name4, "sjs")

        // Ruby: split == (dirname, basename), so split("/") == ("/", "/")
        let (dir5, name5) = File.split("/")
        XCTAssertEqual(dir5, "/")
        XCTAssertEqual(name5, "/")
    }

    func testSplitEdgeCases() throws {
        // Empty path: dirname == ".", basename == ""
        let (dir1, name1) = File.split("")
        XCTAssertEqual(dir1, ".")
        XCTAssertEqual(name1, "")

        // Leading slashes collapse in dirname, trailing slashes strip in basename
        let (dir2, name2) = File.split("//foo////")
        XCTAssertEqual(dir2, "/")
        XCTAssertEqual(name2, "foo")

        // Path with extension
        let (dir3, name3) = File.split("/foo/bar/baz.rb")
        XCTAssertEqual(dir3, "/foo/bar")
        XCTAssertEqual(name3, "baz.rb")
    }

    // MARK: - join Tests

    func testJoin() throws {
        XCTAssertEqual(File.join("hello", "world"), "hello/world")
        XCTAssertEqual(File.join("usr", "mail", "gumby"), "usr/mail/gumby")
        XCTAssertEqual(File.join("/usr", "mail", "gumby"), "/usr/mail/gumby")
        XCTAssertEqual(File.join("/", "usr", "bin"), "/usr/bin")

        // Single component
        XCTAssertEqual(File.join("file.txt"), "file.txt")
        XCTAssertEqual(File.join("/file.txt"), "/file.txt")

        // Empty components in the middle collapse to a single separator
        XCTAssertEqual(File.join("usr", "", "bin"), "usr/bin")
        XCTAssertEqual(File.join("usr/", "", "bin"), "usr/bin")
        XCTAssertEqual(File.join("usr", "", "/bin"), "usr/bin")
        XCTAssertEqual(File.join("usr/", "", "/bin"), "usr/bin")

        // Adjacent boundary slashes dedup to one
        XCTAssertEqual(File.join("/usr/", "/local/", "/bin"), "/usr/local/bin")
        XCTAssertEqual(File.join("usr/", "/bin"), "usr/bin")

        // Trailing slash on the last component IS preserved
        XCTAssertEqual(File.join("/usr/", "local/", "bin/"), "/usr/local/bin/")
        XCTAssertEqual(File.join("a", ""), "a/")
        XCTAssertEqual(File.join("bin", "/"), "bin/")
        XCTAssertEqual(File.join("bin/", "/"), "bin/")
    }

    func testJoinPreservesInteriorSlashes() throws {
        // Ruby only dedups *at the boundary* between two components.
        // Interior slash runs are part of a component and stay verbatim.
        XCTAssertEqual(File.join("usr//", "bin"), "usr//bin")
        XCTAssertEqual(File.join("usr", "//bin"), "usr//bin")
        XCTAssertEqual(File.join("usr/", "//bin"), "usr//bin")
        // Only the boundary slash drops: "usr//" + "/bin" → strip trailing from left → "usr" + "/bin"
        XCTAssertEqual(File.join("usr//", "/bin"), "usr/bin")
        // URL-like prefixes survive
        XCTAssertEqual(File.join("file://usr", "bin"), "file://usr/bin")
    }

    func testJoinWithEmptyStrings() throws {
        // An empty string contributes a separator at the boundary.
        XCTAssertEqual(File.join("", ""), "/")
        XCTAssertEqual(File.join("", "bin"), "/bin")
        XCTAssertEqual(File.join("bin", ""), "bin/")
        // Slashes at one side absorb the boundary cleanly.
        XCTAssertEqual(File.join("/", "bin"), "/bin")
        XCTAssertEqual(File.join("/", "/bin"), "/bin")
        XCTAssertEqual(File.join(""), "")
    }

    func testJoinWithArray() throws {
        XCTAssertEqual(File.join(["usr", "local", "bin"]), "usr/local/bin")
        XCTAssertEqual(File.join(["/usr", "local", "bin"]), "/usr/local/bin")
        XCTAssertEqual(File.join(["file.txt"]), "file.txt")
        XCTAssertEqual(File.join([]), "")
        XCTAssertEqual(File.join([""]), "")
        XCTAssertEqual(File.join(["", ""]), "/")
        XCTAssertEqual(File.join(["a", "b", "c", "d"]), "a/b/c/d")
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
