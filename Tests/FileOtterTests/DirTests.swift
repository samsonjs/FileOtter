//
//  DirTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2024-04-24.
//

@testable import FileOtter
import Foundation
import Testing

extension ProcessGlobalTests {
    @Suite final class DirTests {
        let tempDir: URL

        init() throws {
            tempDir = URL.temporaryDirectory
                .appendingPathComponent("FileOtterTests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }

        deinit {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // MARK: - Well-known Directories Tests

        @Test func cachesDirectory() {
            let caches = Dir.caches
            #expect(FileManager.default.fileExists(atPath: caches.path))
            // Path-substring conventions are Apple-specific.
            #if canImport(Darwin)
            #expect(caches.path.contains("Caches"))
            #endif
        }

        @Test func pwd() {
            let pwd = Dir.pwd
            #expect(pwd.path == FileManager.default.currentDirectoryPath)
            #expect(FileManager.default.fileExists(atPath: pwd.path))
        }

        @Test func documentsDirectory() {
            let documents = Dir.documents
            // On Apple platforms ~/Documents is always present; Linux just returns
            // a conventional path that may not have been created yet.
            #if canImport(Darwin)
            #expect(FileManager.default.fileExists(atPath: documents.path))
            #expect(documents.path.contains("Documents"))
            #else
            #expect(!documents.path.isEmpty)
            #endif
        }

        @Test func homeDirectory() {
            let home = Dir.home
            #expect(FileManager.default.fileExists(atPath: home.path))
            #expect(home.path == FileManager.default.homeDirectoryForCurrentUser.path)
        }

        @Test func libraryDirectory() {
            let library = Dir.library
            #expect(FileManager.default.fileExists(atPath: library.path))
            #if canImport(Darwin)
            #expect(library.path.contains("Library"))
            #endif
        }

        // MARK: - chdir Tests

        @Test func chdirChangesDirectory() throws {
            let originalDir = Dir.pwd

            try Dir.chdir(tempDir)
            #expect(Dir.pwd.resolvingSymlinksInPath().path == tempDir.resolvingSymlinksInPath().path)

            try Dir.chdir(originalDir)
        }

        @Test func chdirWithBlock() {
            let originalDir = Dir.pwd
            let testFile = tempDir.appendingPathComponent("test.txt")

            let result = Dir.chdir(tempDir) { url in
                #expect(Dir.pwd.resolvingSymlinksInPath().path == tempDir.resolvingSymlinksInPath().path)
                #expect(url.resolvingSymlinksInPath().path == tempDir.resolvingSymlinksInPath().path)

                try? "Testing chdir block".write(to: testFile, atomically: true, encoding: .utf8)
                return "success"
            }

            #expect(result == "success")
            #expect(Dir.pwd.resolvingSymlinksInPath().path == originalDir.resolvingSymlinksInPath().path)
            #expect(FileManager.default.fileExists(atPath: testFile.path))
        }

        @Test func chdirWithBlockRestoresDirectoryOnError() {
            let originalDir = Dir.pwd

            #expect(throws: (any Error).self) {
                try Dir.chdir(tempDir) { url in
                    let currentPath = Dir.pwd.resolvingSymlinksInPath().path
                    let expectedPath = tempDir.resolvingSymlinksInPath().path
                    #expect(currentPath == expectedPath)
                    #expect(url.resolvingSymlinksInPath().path == expectedPath)

                    throw NSError(domain: "TestError", code: 1)
                }
            }

            #expect(Dir.pwd.resolvingSymlinksInPath().path == originalDir.resolvingSymlinksInPath().path)
        }

        // MARK: - unlink/rmdir Tests

        @Test func unlinkRemovesDirectory() throws {
            let dirToRemove = tempDir.appendingPathComponent("dir-to-remove")
            try FileManager.default.createDirectory(at: dirToRemove, withIntermediateDirectories: true)
            #expect(FileManager.default.fileExists(atPath: dirToRemove.path))

            try Dir.unlink(dirToRemove)
            #expect(!FileManager.default.fileExists(atPath: dirToRemove.path))
        }

        @Test func rmdirRemovesDirectory() throws {
            let dirToRemove = tempDir.appendingPathComponent("dir-to-rmdir")
            try FileManager.default.createDirectory(at: dirToRemove, withIntermediateDirectories: true)
            #expect(FileManager.default.fileExists(atPath: dirToRemove.path))

            try Dir.rmdir(dirToRemove)
            #expect(!FileManager.default.fileExists(atPath: dirToRemove.path))
        }

        @Test func unlinkThrowsForNonExistentDirectory() {
            let nonExistent = tempDir.appendingPathComponent("does-not-exist")
            #expect(throws: (any Error).self) {
                try Dir.unlink(nonExistent)
            }
        }

        // MARK: - Reading Contents Tests

        @Test func children() throws {
            let file1 = tempDir.appendingPathComponent("file1.txt")
            let file2 = tempDir.appendingPathComponent("file2.txt")
            let subdir = tempDir.appendingPathComponent("subdir")

            try "Content 1".write(to: file1, atomically: true, encoding: .utf8)
            try "Content 2".write(to: file2, atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

            let children = try Dir.children(tempDir)
            #expect(children.count == 3)

            let childNames = children.map(\.lastPathComponent).sorted()
            #expect(childNames == ["file1.txt", "file2.txt", "subdir"])
        }

        @Test func exists() throws {
            #expect(try Dir.exists(tempDir))
            #expect(try Dir.exists(Dir.home))

            let nonExistent = tempDir.appendingPathComponent("not-a-directory")
            #expect(try !Dir.exists(nonExistent))

            let fileNotDir = tempDir.appendingPathComponent("file.txt")
            try "I'm a file".write(to: fileNotDir, atomically: true, encoding: .utf8)
            #expect(try !Dir.exists(fileNotDir))
        }

        @Test func isEmpty() throws {
            #expect(try Dir.isEmpty(tempDir))

            let file = tempDir.appendingPathComponent("file.txt")
            try "Content".write(to: file, atomically: true, encoding: .utf8)

            #expect(try !Dir.isEmpty(tempDir))
        }

        // MARK: - Dir Struct and Collection Tests

        @Test func dirInitialization() throws {
            let file1 = tempDir.appendingPathComponent("a.txt")
            let file2 = tempDir.appendingPathComponent("b.txt")
            try "A".write(to: file1, atomically: true, encoding: .utf8)
            try "B".write(to: file2, atomically: true, encoding: .utf8)

            let dir = try Dir(url: tempDir)
            #expect(dir.url == tempDir)
            #expect(dir.count == 2)
        }

        @Test func dirSubscript() throws {
            let file1 = tempDir.appendingPathComponent("1.txt")
            let file2 = tempDir.appendingPathComponent("2.txt")
            let file3 = tempDir.appendingPathComponent("3.txt")
            try "One".write(to: file1, atomically: true, encoding: .utf8)
            try "Two".write(to: file2, atomically: true, encoding: .utf8)
            try "Three".write(to: file3, atomically: true, encoding: .utf8)

            let dir = try Dir(url: tempDir)
            #expect(dir.count == 3)

            let firstItem = dir[0]
            #expect(["1.txt", "2.txt", "3.txt"].contains(firstItem.lastPathComponent))
        }

        @Test func dirIteration() throws {
            let files = ["rock.mp3", "jazz.mp3", "punk.mp3"]
            for filename in files {
                let file = tempDir.appendingPathComponent(filename)
                try filename.write(to: file, atomically: true, encoding: .utf8)
            }

            let dir = try Dir(url: tempDir)
            var foundFiles: [String] = []

            for url in dir {
                foundFiles.append(url.lastPathComponent)
            }

            #expect(foundFiles.sorted() == files.sorted())
        }

        @Test func dirEquality() throws {
            let dir1 = try Dir(url: tempDir)
            let dir2 = try Dir(url: tempDir)
            #expect(dir1 == dir2)

            let otherDir = URL.temporaryDirectory
                .appendingPathComponent("other-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: otherDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: otherDir) }

            let dir3 = try Dir(url: otherDir)
            #expect(dir1 != dir3)
        }

        // MARK: - Glob Tests

        @Test func globBasicWildcard() throws {
            try "content1".write(to: tempDir.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
            try "content2".write(to: tempDir.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
            try "content3".write(to: tempDir.appendingPathComponent("file3.md"), atomically: true, encoding: .utf8)

            let results = Dir.glob(base: tempDir, "*.txt")
            #expect(results.count == 2)

            let filenames = results.map(\.lastPathComponent).sorted()
            #expect(filenames == ["file1.txt", "file2.txt"])
        }

        @Test func globSubscript() throws {
            try "swift1".write(to: tempDir.appendingPathComponent("app.swift"), atomically: true, encoding: .utf8)
            try "swift2".write(to: tempDir.appendingPathComponent("lib.swift"), atomically: true, encoding: .utf8)
            try "objc".write(to: tempDir.appendingPathComponent("bridge.m"), atomically: true, encoding: .utf8)

            let swiftFiles = Dir[tempDir, "*.swift"]
            #expect(swiftFiles.count == 2)

            let allFiles = Dir[tempDir, "*.*"]
            #expect(allFiles.count == 3)
        }

        @Test func globQuestionMark() throws {
            try "a".write(to: tempDir.appendingPathComponent("a1.txt"), atomically: true, encoding: .utf8)
            try "b".write(to: tempDir.appendingPathComponent("b2.txt"), atomically: true, encoding: .utf8)
            try "c".write(to: tempDir.appendingPathComponent("abc.txt"), atomically: true, encoding: .utf8)

            let results = Dir.glob(base: tempDir, "??.txt")
            #expect(results.count == 2)

            let filenames = results.map(\.lastPathComponent).sorted()
            #expect(filenames == ["a1.txt", "b2.txt"])
        }

        @Test func globCharacterClass() throws {
            try "1".write(to: tempDir.appendingPathComponent("test1.txt"), atomically: true, encoding: .utf8)
            try "2".write(to: tempDir.appendingPathComponent("test2.txt"), atomically: true, encoding: .utf8)
            try "a".write(to: tempDir.appendingPathComponent("testa.txt"), atomically: true, encoding: .utf8)

            let numberFiles = Dir.glob(base: tempDir, "test[0-9].txt")
            #expect(numberFiles.count == 2)

            let letterFiles = Dir.glob(base: tempDir, "test[a-z].txt")
            #expect(letterFiles.count == 1)
            #expect(letterFiles.first?.lastPathComponent == "testa.txt")
        }

        @Test func globRecursive() throws {
            let subdir1 = tempDir.appendingPathComponent("src")
            let subdir2 = subdir1.appendingPathComponent("lib")
            try FileManager.default.createDirectory(at: subdir2, withIntermediateDirectories: true)

            try "root".write(to: tempDir.appendingPathComponent("root.swift"), atomically: true, encoding: .utf8)
            try "src".write(to: subdir1.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
            try "lib".write(to: subdir2.appendingPathComponent("utils.swift"), atomically: true, encoding: .utf8)
            try "lib2".write(to: subdir2.appendingPathComponent("helpers.swift"), atomically: true, encoding: .utf8)

            let allSwiftFiles = Dir.glob(base: tempDir, "**/*.swift")
            #expect(allSwiftFiles.count == 4)

            let srcSwiftFiles = Dir.glob(base: tempDir, "src/**/*.swift")
            #expect(srcSwiftFiles.count == 3) // main.swift, utils.swift, helpers.swift

            let libSwiftFiles = Dir.glob(base: tempDir, "**/lib/*.swift")
            #expect(libSwiftFiles.count == 2) // utils.swift, helpers.swift
        }

        @Test func globNoMatches() {
            let results = Dir.glob(base: tempDir, "*.nonexistent")
            #expect(results.isEmpty)

            let subscriptResults = Dir[tempDir, "no-such-file.*"]
            #expect(subscriptResults.isEmpty)
        }

        @Test func globHiddenFiles() throws {
            try "hidden".write(to: tempDir.appendingPathComponent(".hidden.txt"), atomically: true, encoding: .utf8)
            try "visible".write(to: tempDir.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)

            // By default, * should not match hidden files (FNM_PERIOD flag)
            let starResults = Dir.glob(base: tempDir, "*.txt")
            #expect(starResults.count == 1)
            #expect(starResults.first?.lastPathComponent == "visible.txt")

            let hiddenResults = Dir.glob(base: tempDir, ".*.txt")
            #expect(hiddenResults.count == 1)
            #expect(hiddenResults.first?.lastPathComponent == ".hidden.txt")
        }

        // MARK: - Debug Description Tests

        @Test func debugDescription() throws {
            let dir = try Dir(url: tempDir)
            let debugDescription = String(reflecting: dir)
            #expect(debugDescription == "<Dir:\(tempDir.path)>")

            let homeDir = try Dir(url: Dir.home)
            let homeDebugDescription = String(reflecting: homeDir)
            #expect(homeDebugDescription == "<Dir:\(Dir.home.path)>")
        }

        @Test func description() throws {
            let dir = try Dir(url: tempDir)
            let description = String(describing: dir)
            #expect(description == tempDir.path)

            let homeDir = try Dir(url: Dir.home)
            let homeDescription = String(describing: homeDir)
            #expect(homeDescription == Dir.home.path)
        }

        // MARK: - tmpdir Tests

        @Test func tmp() {
            let tmp = Dir.tmp
            #expect(FileManager.default.fileExists(atPath: tmp.path))

            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: tmp.path, isDirectory: &isDirectory)
            #expect(isDirectory.boolValue)

            #expect(tmp == URL.temporaryDirectory)
        }

        // MARK: - mkdir Tests

        @Test func mkdir() throws {
            let newDir = tempDir.appendingPathComponent("test-mkdir")
            #expect(!FileManager.default.fileExists(atPath: newDir.path))

            try Dir.mkdir(newDir)
            #expect(FileManager.default.fileExists(atPath: newDir.path))

            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: newDir.path, isDirectory: &isDirectory)
            #expect(isDirectory.boolValue)
        }

        @Test func mkdirWithPermissions() throws {
            let newDir = tempDir.appendingPathComponent("test-mkdir-perms")

            try Dir.mkdir(newDir, permissions: 0o700)

            let attributes = try FileManager.default.attributesOfItem(atPath: newDir.path)
            let permissions = try #require(attributes[.posixPermissions] as? Int)

            #if os(macOS) || os(Linux)
            #expect(permissions & 0o777 == 0o700)
            #endif
        }

        @Test func mkdirFailsIfDirectoryExists() throws {
            let existingDir = tempDir.appendingPathComponent("existing")
            try Dir.mkdir(existingDir)

            #expect(throws: CocoaError.self) {
                try Dir.mkdir(existingDir)
            }
        }

        // MARK: - mktmpdir Tests

        @Test func mktmpdir() throws {
            let tmpDir = try Dir.mktmpdir()
            #expect(FileManager.default.fileExists(atPath: tmpDir.path))
            #expect(tmpDir.path.contains("d-"))

            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: tmpDir.path, isDirectory: &isDirectory)
            #expect(isDirectory.boolValue)

            let attributes = try FileManager.default.attributesOfItem(atPath: tmpDir.path)
            let permissions = try #require(attributes[.posixPermissions] as? Int)

            #if os(macOS) || os(Linux)
            #expect(permissions & 0o777 == 0o700)
            #endif

            try FileManager.default.removeItem(at: tmpDir)
        }

        @Test func mktempdirWithPrefix() throws {
            let tmpDir = try Dir.mktmpdir(prefix: "fileotter")
            #expect(tmpDir.path.contains("fileotter-"))
            #expect(FileManager.default.fileExists(atPath: tmpDir.path))

            try FileManager.default.removeItem(at: tmpDir)
        }

        @Test func mktempdirWithPrefixAndSuffix() throws {
            let tmpDir = try Dir.mktmpdir(prefix: "test", suffix: "tmp")
            #expect(tmpDir.lastPathComponent.hasPrefix("test-"))
            #expect(tmpDir.lastPathComponent.hasSuffix("-tmp"))
            #expect(FileManager.default.fileExists(atPath: tmpDir.path))

            try FileManager.default.removeItem(at: tmpDir)
        }

        @Test func mktempdirWithBlock() throws {
            var blockExecuted = false
            var tmpDirInBlock: URL?
            var fileCreated = false

            let result = try Dir.mktmpdir(prefix: "block") { tmpDir in
                blockExecuted = true
                tmpDirInBlock = tmpDir
                #expect(FileManager.default.fileExists(atPath: tmpDir.path))

                let testFile = tmpDir.appendingPathComponent("test.txt")
                try "Hello from mktmpdir block".write(to: testFile, atomically: true, encoding: .utf8)
                fileCreated = FileManager.default.fileExists(atPath: testFile.path)

                return "block result"
            }

            #expect(blockExecuted)
            #expect(result == "block result")
            #expect(fileCreated)

            if let tmpDirInBlock {
                #expect(!FileManager.default.fileExists(atPath: tmpDirInBlock.path))
            }
        }

        @Test func mktempdirWithBlockThrowingError() {
            let nsError = #expect(throws: NSError.self) {
                try Dir.mktmpdir { tmpDir in
                    #expect(FileManager.default.fileExists(atPath: tmpDir.path))
                    throw NSError(domain: "TestError", code: 42)
                }
            }
            #expect(nsError?.domain == "TestError")
            #expect(nsError?.code == 42)
        }

        @Test func mktempdirEachCallCreatesUniqueDirectory() throws {
            let tmpDir1 = try Dir.mktmpdir()
            let tmpDir2 = try Dir.mktmpdir()

            #expect(tmpDir1 != tmpDir2)
            #expect(FileManager.default.fileExists(atPath: tmpDir1.path))
            #expect(FileManager.default.fileExists(atPath: tmpDir2.path))

            try FileManager.default.removeItem(at: tmpDir1)
            try FileManager.default.removeItem(at: tmpDir2)
        }
    }
}
