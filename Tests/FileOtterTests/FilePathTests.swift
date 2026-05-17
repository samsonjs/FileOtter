//
//  FilePathTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import Foundation
import Testing

extension ProcessGlobalTests {
    @Suite final class FilePathTests {
        let tempDir: URL
        let originalWorkingDirectory: String

        init() throws {
            originalWorkingDirectory = FileManager.default.currentDirectoryPath
            tempDir = URL.temporaryDirectory
                .appendingPathComponent("FilePathTests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }

        deinit {
            FileManager.default.changeCurrentDirectoryPath(originalWorkingDirectory)
            try? FileManager.default.removeItem(at: tempDir)
        }

        // MARK: - basename Tests

        @Test func basename() {
            #expect(File.basename("/Users/sjs/file.txt") == "file.txt")
            #expect(File.basename("/Users/sjs/dir/") == "dir")
            #expect(File.basename("/") == "/")
            #expect(File.basename("file.rb") == "file.rb")
        }

        @Test func basenameEdgeCases() {
            // Empty path
            #expect(File.basename("") == "")
            // Trailing slashes are stripped (Ruby parity)
            #expect(File.basename("foo.txt/") == "foo.txt")
            #expect(File.basename("/foo/bar/") == "bar")
            #expect(File.basename("/foo/bar///") == "bar")
            #expect(File.basename("dir///base") == "base")
            #expect(File.basename("dir///base/") == "base")
            // Single component
            #expect(File.basename("foo") == "foo")
            // Dot paths are returned as-is
            #expect(File.basename(".") == ".")
            #expect(File.basename("..") == "..")
            // Just slashes collapse to root
            #expect(File.basename("///") == "/")
            #expect(File.basename("//") == "/")
            // Short rooted paths
            #expect(File.basename("/a") == "a")
            #expect(File.basename("/a/b") == "b")
            #expect(File.basename("/tmp") == "tmp")
            #expect(File.basename("/tmp/") == "tmp")
            // Unicode
            #expect(File.basename("/path/Офис.m4a") == "Офис.m4a")
        }

        @Test func basenameWithSuffix() {
            #expect(File.basename("/Users/sjs/file.txt", suffix: ".txt") == "file")
            #expect(File.basename("/Users/sjs/file.txt", suffix: ".rb") == "file.txt")
            #expect(File.basename("/Users/sjs/archive.tar.gz", suffix: ".gz") == "archive.tar")
            #expect(File.basename("/Users/sjs/archive.tar.gz", suffix: ".tar.gz") == "archive")
            // Ruby: stripping suffix can leave an empty string
            #expect(File.basename(".rb", suffix: ".rb") == "")
            // Suffix that doesn't match returns base unchanged
            #expect(File.basename("foo", suffix: ".ext") == "foo")
            #expect(File.basename("s", suffix: "_a") == "s")
            // Suffix can be any trailing substring, not just a dotted extension
            #expect(File.basename("baz.rb", suffix: "z.rb") == "ba")
            // Trailing slash stripped before suffix match
            #expect(File.basename("foo.rb/", suffix: ".rb") == "foo")
        }

        @Test func basenameWithWildcardSuffix() {
            #expect(File.basename("/Users/sjs/file.txt", suffix: ".*") == "file")
            #expect(File.basename("/Users/sjs/archive.tar.gz", suffix: ".*") == "archive.tar")
            #expect(File.basename("/Users/sjs/noext", suffix: ".*") == "noext")
            // Dotfiles have no extension to strip
            #expect(File.basename(".profile", suffix: ".*") == ".profile")
            #expect(File.basename("/Users/sjs/.bashrc", suffix: ".*") == ".bashrc")
        }

        // MARK: - dirname Tests

        @Test func dirname() {
            #expect(File.dirname("/Users/sjs/file.txt") == "/Users/sjs")
            #expect(File.dirname("/Users/sjs/dir/") == "/Users/sjs")
            #expect(File.dirname("/file.txt") == "/")
            #expect(File.dirname("file.txt") == ".")
        }

        @Test func dirnameEdgeCases() {
            #expect(File.dirname("") == ".")
            #expect(File.dirname("/") == "/")
            #expect(File.dirname(".") == ".")
            #expect(File.dirname("./") == ".")
            #expect(File.dirname("..") == ".")
            #expect(File.dirname("../") == ".")
            #expect(File.dirname("foo") == ".")
            // Trailing slash on a single component
            #expect(File.dirname("foo/") == ".")
            // Interior slash runs are preserved (Ruby parity)
            #expect(File.dirname("a/b//c") == "a/b")
            #expect(File.dirname("a//b") == "a")
            #expect(File.dirname("/holy///schnikies//w00t.bin") == "/holy///schnikies")
            // Dot components are not normalized
            #expect(File.dirname("/foo/.") == "/foo")
            #expect(File.dirname("/foo/./") == "/foo")
            #expect(File.dirname("/foo/../.") == "/foo/..")
            #expect(File.dirname("foo/../") == "foo")
            #expect(File.dirname("/.") == "/")
            // Trailing slash above root
            #expect(File.dirname("/foo/") == "/")
        }

        @Test func dirnameLeadingSlashes() {
            // Ruby collapses 2+ leading slashes in the dirname result down to 1.
            #expect(File.dirname("/////foo/bar/") == "/foo")
            #expect(File.dirname("/////") == "/")
            #expect(File.dirname("//foo//") == "/")
        }

        @Test func dirnameWithLevel() {
            #expect(File.dirname("/Users/sjs/dir/file.txt", level: 1) == "/Users/sjs/dir")
            #expect(File.dirname("/Users/sjs/dir/file.txt", level: 2) == "/Users/sjs")
            #expect(File.dirname("/Users/sjs/dir/file.txt", level: 3) == "/Users")
            #expect(File.dirname("/Users/sjs/dir/file.txt", level: 4) == "/")
            #expect(File.dirname("/Users/sjs/dir/file.txt", level: 5) == "/") // Can't go beyond root
            // Relative path overshoot
            #expect(File.dirname("a/b", level: 10) == ".")
            #expect(File.dirname("/Users/sjs/dir/file.txt", level: 100) == "/")
            // level: 0 is identity
            #expect(File.dirname("poot.txt", level: 0) == "poot.txt")
            #expect(File.dirname("/", level: 0) == "/")
        }

        // MARK: - extname Tests

        @Test func extname() {
            #expect(File.extname("test.rb") == ".rb")
            #expect(File.extname("a/b/d/test.rb") == ".rb")
            #expect(File.extname(".a/b/d/test.rb") == ".rb")
            #expect(File.extname("test") == "")
            #expect(File.extname("test.tar.gz") == ".gz")
        }

        @Test func extnameWithDotfile() {
            #expect(File.extname(".profile") == "")
            #expect(File.extname(".profile.sh") == ".sh")
            #expect(File.extname("/Users/sjs/.bashrc") == "")
            #expect(File.extname("/Users/sjs/.config.bak") == ".bak")
        }

        @Test func extnameEdgeCases() {
            #expect(File.extname("") == "")
            // All-dots basenames have no extension
            #expect(File.extname(".") == "")
            #expect(File.extname("..") == "")
            #expect(File.extname("...") == "")
            #expect(File.extname("....") == "")
            // Ruby keeps a trailing-dot extension as "." on POSIX
            #expect(File.extname("foo.") == ".")
            #expect(File.extname("foo.bar.") == ".")
            #expect(File.extname(".foo.") == ".")
            // Leading double-dot file: ".rb" is the extension
            #expect(File.extname("..rb") == ".rb")
            // Dot only in a directory component, not the basename
            #expect(File.extname("/foo.bar/baz") == "")
            #expect(File.extname("/foo/bar.baz/qux") == "")
            #expect(File.extname("/foo.rb/bar.c") == ".c")
            // Interior slash runs
            #expect(File.extname("/tmp//bla.rb") == ".rb")
            // Multiple dots — last one wins
            #expect(File.extname("a.b.c.d.e") == ".e")
            #expect(File.extname(".app.conf") == ".conf")
            // Roots
            #expect(File.extname("/") == "")
            #expect(File.extname("/.") == "")
            // Unicode
            #expect(File.extname("Имя.m4a") == ".m4a")
        }

        // MARK: - split Tests

        @Test func split() {
            let (dir1, name1) = File.split("/Users/sjs/file.txt")
            #expect(dir1 == "/Users/sjs")
            #expect(name1 == "file.txt")

            let (dir2, name2) = File.split("/file.txt")
            #expect(dir2 == "/")
            #expect(name2 == "file.txt")

            let (dir3, name3) = File.split("file.txt")
            #expect(dir3 == ".")
            #expect(name3 == "file.txt")

            let (dir4, name4) = File.split("/Users/sjs/")
            #expect(dir4 == "/Users")
            #expect(name4 == "sjs")

            // Ruby: split == (dirname, basename), so split("/") == ("/", "/")
            let (dir5, name5) = File.split("/")
            #expect(dir5 == "/")
            #expect(name5 == "/")
        }

        @Test func splitEdgeCases() {
            // Empty path: dirname == ".", basename == ""
            let (dir1, name1) = File.split("")
            #expect(dir1 == ".")
            #expect(name1 == "")

            // Leading slashes collapse in dirname, trailing slashes strip in basename
            let (dir2, name2) = File.split("//foo////")
            #expect(dir2 == "/")
            #expect(name2 == "foo")

            // Path with extension
            let (dir3, name3) = File.split("/foo/bar/baz.rb")
            #expect(dir3 == "/foo/bar")
            #expect(name3 == "baz.rb")
        }

        // MARK: - join Tests

        @Test func join() {
            #expect(File.join("hello", "world") == "hello/world")
            #expect(File.join("usr", "mail", "gumby") == "usr/mail/gumby")
            #expect(File.join("/usr", "mail", "gumby") == "/usr/mail/gumby")
            #expect(File.join("/", "usr", "bin") == "/usr/bin")

            // Single component
            #expect(File.join("file.txt") == "file.txt")
            #expect(File.join("/file.txt") == "/file.txt")

            // Empty components in the middle collapse to a single separator
            #expect(File.join("usr", "", "bin") == "usr/bin")
            #expect(File.join("usr/", "", "bin") == "usr/bin")
            #expect(File.join("usr", "", "/bin") == "usr/bin")
            #expect(File.join("usr/", "", "/bin") == "usr/bin")

            // Adjacent boundary slashes dedup to one
            #expect(File.join("/usr/", "/local/", "/bin") == "/usr/local/bin")
            #expect(File.join("usr/", "/bin") == "usr/bin")

            // Trailing slash on the last component IS preserved
            #expect(File.join("/usr/", "local/", "bin/") == "/usr/local/bin/")
            #expect(File.join("a", "") == "a/")
            #expect(File.join("bin", "/") == "bin/")
            #expect(File.join("bin/", "/") == "bin/")
        }

        @Test func joinPreservesInteriorSlashes() {
            // Ruby only dedups *at the boundary* between two components.
            // Interior slash runs are part of a component and stay verbatim.
            #expect(File.join("usr//", "bin") == "usr//bin")
            #expect(File.join("usr", "//bin") == "usr//bin")
            #expect(File.join("usr/", "//bin") == "usr//bin")
            // Only the boundary slash drops: "usr//" + "/bin" → strip trailing from left → "usr" + "/bin"
            #expect(File.join("usr//", "/bin") == "usr/bin")
            // URL-like prefixes survive
            #expect(File.join("file://usr", "bin") == "file://usr/bin")
        }

        @Test func joinWithEmptyStrings() {
            // An empty string contributes a separator at the boundary.
            #expect(File.join("", "") == "/")
            #expect(File.join("", "bin") == "/bin")
            #expect(File.join("bin", "") == "bin/")
            // Slashes at one side absorb the boundary cleanly.
            #expect(File.join("/", "bin") == "/bin")
            #expect(File.join("/", "/bin") == "/bin")
            #expect(File.join("") == "")
        }

        @Test func joinWithArray() {
            #expect(File.join(["usr", "local", "bin"]) == "usr/local/bin")
            #expect(File.join(["/usr", "local", "bin"]) == "/usr/local/bin")
            #expect(File.join(["file.txt"]) == "file.txt")
            #expect(File.join([]) == "")
            #expect(File.join([""]) == "")
            #expect(File.join(["", ""]) == "/")
            #expect(File.join(["a", "b", "c", "d"]) == "a/b/c/d")
        }

        // MARK: - absolutePath Tests

        @Test func absolutePath() {
            let absoluteURL = URL(fileURLWithPath: "/usr/bin/swift")
            #expect(File.absolutePath(absoluteURL).path == "/usr/bin/swift")

            // Relative path - URL constructor will use current directory
            FileManager.default.changeCurrentDirectoryPath(tempDir.path)
            let relativeURL = URL(fileURLWithPath: "file.txt")
            let absPath = File.absolutePath(relativeURL)
            // The URL is already absolute at this point, we just normalize it
            #expect(absPath.path.hasSuffix("file.txt"))
            #expect(absPath.path.hasPrefix("/"))
        }

        @Test func absolutePathNormalization() {
            // Test that .. and . are resolved
            let pathWithDots = URL(fileURLWithPath: "/usr/../bin/./swift")
            #expect(File.absolutePath(pathWithDots).path == "/bin/swift")

            // Test multiple .. segments
            let pathWithMultipleDots = URL(fileURLWithPath: "/usr/local/../../bin")
            #expect(File.absolutePath(pathWithMultipleDots).path == "/bin")

            // Test trailing slash removal
            let pathWithTrailingSlash = URL(fileURLWithPath: "/usr/bin/")
            #expect(File.absolutePath(pathWithTrailingSlash).path == "/usr/bin")
        }

        // MARK: - expandPath Tests

        @Test func expandPath() {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser

            // Test expanding ~
            let expanded1 = File.expandPath("~")
            #expect(expanded1.path == homeDir.path)

            // Test expanding ~/Documents
            let expanded2 = File.expandPath("~/Documents")
            #expect(expanded2.path == homeDir.appendingPathComponent("Documents").path)

            // Test regular path (no expansion needed)
            let expanded3 = File.expandPath("/usr/bin")
            #expect(expanded3.path == "/usr/bin")
        }

        // MARK: - realpath Tests

        @Test func realpath() throws {
            let fileURL = tempDir.appendingPathComponent("realfile.txt")
            try "test content".write(to: fileURL, atomically: true, encoding: .utf8)

            let resolved = try File.realpath(fileURL)
            #expect(resolved.path == fileURL.path)

            let symlinkURL = tempDir.appendingPathComponent("symlink.txt")
            try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: fileURL)

            let resolvedSymlink = try File.realpath(symlinkURL)
            #expect(resolvedSymlink.path == fileURL.path)
        }

        @Test func realpathThrowsForNonExistent() {
            let nonExistentURL = tempDir.appendingPathComponent("nonexistent.txt")

            let error = #expect(throws: NSError.self) {
                try File.realpath(nonExistentURL)
            }
            #expect(error?.domain == NSCocoaErrorDomain)
            #expect(error?.code == CocoaError.fileNoSuchFile.rawValue)
        }

        // MARK: - realdirpath Tests

        @Test func realdirpath() throws {
            let dirURL = tempDir.appendingPathComponent("realdir")
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

            let resolved = try File.realdirpath(dirURL)
            #expect(resolved.path == dirURL.path)

            let symlinkDirURL = tempDir.appendingPathComponent("symlinkdir")
            try FileManager.default.createSymbolicLink(at: symlinkDirURL, withDestinationURL: dirURL)

            let resolvedSymlink = try File.realdirpath(symlinkDirURL)
            #expect(resolvedSymlink.path == dirURL.path)
        }

        @Test func realdirpathWithNonExistentLast() throws {
            let dirURL = tempDir.appendingPathComponent("realdir")
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

            let nonExistentFile = dirURL.appendingPathComponent("future-file.txt")
            let resolved = try File.realdirpath(nonExistentFile)
            #expect(resolved.path == nonExistentFile.path)
        }
    }
}
