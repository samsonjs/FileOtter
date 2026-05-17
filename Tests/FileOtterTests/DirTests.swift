//
//  DirTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2024-04-24.
//

@testable import FileOtter
import XCTest

final class DirTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FileOtterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Well-known Directories Tests

    func testCachesDirectory() {
        let caches = Dir.caches
        XCTAssertTrue(FileManager.default.fileExists(atPath: caches.path))
        // Path-substring conventions are Apple-specific.
        #if canImport(Darwin)
        XCTAssertTrue(caches.path.contains("Caches"))
        #endif
    }

    func testPwd() {
        let pwd = Dir.pwd
        XCTAssertEqual(pwd.path, FileManager.default.currentDirectoryPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pwd.path))
    }

    func testDocumentsDirectory() {
        let documents = Dir.documents
        // On Apple platforms ~/Documents is always present; Linux just returns
        // a conventional path that may not have been created yet.
        #if canImport(Darwin)
        XCTAssertTrue(FileManager.default.fileExists(atPath: documents.path))
        XCTAssertTrue(documents.path.contains("Documents"))
        #else
        XCTAssertFalse(documents.path.isEmpty)
        #endif
    }

    func testHomeDirectory() {
        let home = Dir.home
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.path))
        XCTAssertEqual(home.path, FileManager.default.homeDirectoryForCurrentUser.path)
    }

    func testLibraryDirectory() {
        let library = Dir.library
        XCTAssertTrue(FileManager.default.fileExists(atPath: library.path))
        #if canImport(Darwin)
        XCTAssertTrue(library.path.contains("Library"))
        #endif
    }

    // MARK: - chdir Tests

    func testChdirChangesDirectory() throws {
        let originalDir = Dir.pwd

        XCTAssertNoThrow(try Dir.chdir(tempDir))
        XCTAssertEqual(Dir.pwd.resolvingSymlinksInPath().path, tempDir.resolvingSymlinksInPath().path)

        try Dir.chdir(originalDir)
    }

    func testChdirWithBlock() {
        let originalDir = Dir.pwd
        let testFile = tempDir.appendingPathComponent("test.txt")

        let result = Dir.chdir(tempDir) { url in
            XCTAssertEqual(Dir.pwd.resolvingSymlinksInPath().path, tempDir.resolvingSymlinksInPath().path)
            XCTAssertEqual(url.resolvingSymlinksInPath().path, tempDir.resolvingSymlinksInPath().path)

            try? "Testing chdir block".write(to: testFile, atomically: true, encoding: .utf8)
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(Dir.pwd.resolvingSymlinksInPath().path, originalDir.resolvingSymlinksInPath().path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))
    }

    func testChdirWithBlockRestoresDirectoryOnError() {
        let originalDir = Dir.pwd

        do {
            try Dir.chdir(tempDir) { url in
                // Verify we're in the temp directory
                let currentPath = Dir.pwd.resolvingSymlinksInPath().path
                let expectedPath = tempDir.resolvingSymlinksInPath().path
                XCTAssertEqual(currentPath, expectedPath)

                // Also verify the passed URL matches
                XCTAssertEqual(url.resolvingSymlinksInPath().path, expectedPath)

                throw NSError(domain: "TestError", code: 1)
            }
            XCTFail("Should have thrown an error")
        } catch {
            // Verify we're back in the original directory
            XCTAssertEqual(Dir.pwd.resolvingSymlinksInPath().path, originalDir.resolvingSymlinksInPath().path)
        }
    }

    // MARK: - unlink/rmdir Tests

    func testUnlinkRemovesDirectory() throws {
        let dirToRemove = tempDir.appendingPathComponent("dir-to-remove")
        try FileManager.default.createDirectory(at: dirToRemove, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dirToRemove.path))

        XCTAssertNoThrow(try Dir.unlink(dirToRemove))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dirToRemove.path))
    }

    func testRmdirRemovesDirectory() throws {
        let dirToRemove = tempDir.appendingPathComponent("dir-to-rmdir")
        try FileManager.default.createDirectory(at: dirToRemove, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dirToRemove.path))

        XCTAssertNoThrow(try Dir.rmdir(dirToRemove))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dirToRemove.path))
    }

    func testUnlinkThrowsForNonExistentDirectory() {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist")
        XCTAssertThrowsError(try Dir.unlink(nonExistent))
    }

    // MARK: - Reading Contents Tests

    func testChildren() throws {
        let file1 = tempDir.appendingPathComponent("file1.txt")
        let file2 = tempDir.appendingPathComponent("file2.txt")
        let subdir = tempDir.appendingPathComponent("subdir")

        try "Content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Content 2".write(to: file2, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let children = try Dir.children(tempDir)
        XCTAssertEqual(children.count, 3)

        let childNames = children.map(\.lastPathComponent).sorted()
        XCTAssertEqual(childNames, ["file1.txt", "file2.txt", "subdir"])
    }

    func testExists() throws {
        XCTAssertTrue(try Dir.exists(tempDir))
        XCTAssertTrue(try Dir.exists(Dir.home))

        let nonExistent = tempDir.appendingPathComponent("not-a-directory")
        XCTAssertFalse(try Dir.exists(nonExistent))

        let fileNotDir = tempDir.appendingPathComponent("file.txt")
        try "I'm a file".write(to: fileNotDir, atomically: true, encoding: .utf8)
        XCTAssertFalse(try Dir.exists(fileNotDir))
    }

    func testIsEmpty() throws {
        XCTAssertTrue(try Dir.isEmpty(tempDir))

        let file = tempDir.appendingPathComponent("file.txt")
        try "Content".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertFalse(try Dir.isEmpty(tempDir))
    }

    // MARK: - Dir Struct and Collection Tests

    func testDirInitialization() throws {
        let file1 = tempDir.appendingPathComponent("a.txt")
        let file2 = tempDir.appendingPathComponent("b.txt")
        try "A".write(to: file1, atomically: true, encoding: .utf8)
        try "B".write(to: file2, atomically: true, encoding: .utf8)

        let dir = try Dir(url: tempDir)
        XCTAssertEqual(dir.url, tempDir)
        XCTAssertEqual(dir.count, 2)
    }

    func testDirSubscript() throws {
        let file1 = tempDir.appendingPathComponent("1.txt")
        let file2 = tempDir.appendingPathComponent("2.txt")
        let file3 = tempDir.appendingPathComponent("3.txt")
        try "One".write(to: file1, atomically: true, encoding: .utf8)
        try "Two".write(to: file2, atomically: true, encoding: .utf8)
        try "Three".write(to: file3, atomically: true, encoding: .utf8)

        let dir = try Dir(url: tempDir)
        XCTAssertEqual(dir.count, 3)

        let firstItem = dir[0]
        XCTAssertTrue(["1.txt", "2.txt", "3.txt"].contains(firstItem.lastPathComponent))
    }

    func testDirIteration() throws {
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

        XCTAssertEqual(foundFiles.sorted(), files.sorted())
    }

    func testDirEquality() throws {
        let dir1 = try Dir(url: tempDir)
        let dir2 = try Dir(url: tempDir)
        XCTAssertEqual(dir1, dir2)

        let otherDir = URL.temporaryDirectory
            .appendingPathComponent("other-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: otherDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: otherDir) }

        let dir3 = try Dir(url: otherDir)
        XCTAssertNotEqual(dir1, dir3)
    }

    // MARK: - Glob Tests

    func testGlobBasicWildcard() throws {
        // Create test files
        try "content1".write(to: tempDir.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "content2".write(to: tempDir.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        try "content3".write(to: tempDir.appendingPathComponent("file3.md"), atomically: true, encoding: .utf8)

        let results = Dir.glob(base: tempDir, "*.txt")
        XCTAssertEqual(results.count, 2)

        let filenames = results.map(\.lastPathComponent).sorted()
        XCTAssertEqual(filenames, ["file1.txt", "file2.txt"])
    }

    func testGlobSubscript() throws {
        // Create test files
        try "swift1".write(to: tempDir.appendingPathComponent("app.swift"), atomically: true, encoding: .utf8)
        try "swift2".write(to: tempDir.appendingPathComponent("lib.swift"), atomically: true, encoding: .utf8)
        try "objc".write(to: tempDir.appendingPathComponent("bridge.m"), atomically: true, encoding: .utf8)

        let swiftFiles = Dir[tempDir, "*.swift"]
        XCTAssertEqual(swiftFiles.count, 2)

        let allFiles = Dir[tempDir, "*.*"]
        XCTAssertEqual(allFiles.count, 3)
    }

    func testGlobQuestionMark() throws {
        // Create test files with pattern
        try "a".write(to: tempDir.appendingPathComponent("a1.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: tempDir.appendingPathComponent("b2.txt"), atomically: true, encoding: .utf8)
        try "c".write(to: tempDir.appendingPathComponent("abc.txt"), atomically: true, encoding: .utf8)

        let results = Dir.glob(base: tempDir, "??.txt")
        XCTAssertEqual(results.count, 2)

        let filenames = results.map(\.lastPathComponent).sorted()
        XCTAssertEqual(filenames, ["a1.txt", "b2.txt"])
    }

    func testGlobCharacterClass() throws {
        // Create test files
        try "1".write(to: tempDir.appendingPathComponent("test1.txt"), atomically: true, encoding: .utf8)
        try "2".write(to: tempDir.appendingPathComponent("test2.txt"), atomically: true, encoding: .utf8)
        try "a".write(to: tempDir.appendingPathComponent("testa.txt"), atomically: true, encoding: .utf8)

        let numberFiles = Dir.glob(base: tempDir, "test[0-9].txt")
        XCTAssertEqual(numberFiles.count, 2)

        let letterFiles = Dir.glob(base: tempDir, "test[a-z].txt")
        XCTAssertEqual(letterFiles.count, 1)
        XCTAssertEqual(letterFiles.first?.lastPathComponent, "testa.txt")
    }

    func testGlobRecursive() throws {
        // Create nested directory structure
        let subdir1 = tempDir.appendingPathComponent("src")
        let subdir2 = subdir1.appendingPathComponent("lib")
        try FileManager.default.createDirectory(at: subdir2, withIntermediateDirectories: true)

        try "root".write(to: tempDir.appendingPathComponent("root.swift"), atomically: true, encoding: .utf8)
        try "src".write(to: subdir1.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        try "lib".write(to: subdir2.appendingPathComponent("utils.swift"), atomically: true, encoding: .utf8)
        try "lib2".write(to: subdir2.appendingPathComponent("helpers.swift"), atomically: true, encoding: .utf8)

        // Test ** for recursive matching
        let allSwiftFiles = Dir.glob(base: tempDir, "**/*.swift")
        XCTAssertEqual(allSwiftFiles.count, 4)

        // Test ** matching zero segments
        let srcSwiftFiles = Dir.glob(base: tempDir, "src/**/*.swift")
        XCTAssertEqual(srcSwiftFiles.count, 3) // main.swift, utils.swift, helpers.swift

        // Test specific path with **
        let libSwiftFiles = Dir.glob(base: tempDir, "**/lib/*.swift")
        XCTAssertEqual(libSwiftFiles.count, 2) // utils.swift, helpers.swift
    }

    func testGlobNoMatches() {
        let results = Dir.glob(base: tempDir, "*.nonexistent")
        XCTAssertTrue(results.isEmpty)

        let subscriptResults = Dir[tempDir, "no-such-file.*"]
        XCTAssertTrue(subscriptResults.isEmpty)
    }

    func testGlobHiddenFiles() throws {
        // Create hidden file
        try "hidden".write(to: tempDir.appendingPathComponent(".hidden.txt"), atomically: true, encoding: .utf8)
        try "visible".write(to: tempDir.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)

        // By default, * should not match hidden files (FNM_PERIOD flag)
        let starResults = Dir.glob(base: tempDir, "*.txt")
        XCTAssertEqual(starResults.count, 1)
        XCTAssertEqual(starResults.first?.lastPathComponent, "visible.txt")

        // Explicitly matching hidden files
        let hiddenResults = Dir.glob(base: tempDir, ".*.txt")
        XCTAssertEqual(hiddenResults.count, 1)
        XCTAssertEqual(hiddenResults.first?.lastPathComponent, ".hidden.txt")
    }

    // MARK: - Debug Description Tests

    func testDebugDescription() throws {
        let dir = try Dir(url: tempDir)
        let debugDescription = String(reflecting: dir)
        XCTAssertEqual(debugDescription, "<Dir:\(tempDir.path)>")

        let homeDir = try Dir(url: Dir.home)
        let homeDebugDescription = String(reflecting: homeDir)
        XCTAssertEqual(homeDebugDescription, "<Dir:\(Dir.home.path)>")
    }

    func testDescription() throws {
        let dir = try Dir(url: tempDir)
        let description = String(describing: dir)
        XCTAssertEqual(description, tempDir.path)

        let homeDir = try Dir(url: Dir.home)
        let homeDescription = String(describing: homeDir)
        XCTAssertEqual(homeDescription, Dir.home.path)
    }

    // MARK: - tmpdir Tests

    func testTmp() {
        let tmp = Dir.tmp
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.path))

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: tmp.path, isDirectory: &isDirectory)
        XCTAssertTrue(isDirectory.boolValue)

        XCTAssertEqual(tmp, URL.temporaryDirectory)
    }

    // MARK: - mkdir Tests

    func testMkdir() throws {
        let newDir = tempDir.appendingPathComponent("test-mkdir")
        XCTAssertFalse(FileManager.default.fileExists(atPath: newDir.path))

        try Dir.mkdir(newDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDir.path))

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: newDir.path, isDirectory: &isDirectory)
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testMkdirWithPermissions() throws {
        let newDir = tempDir.appendingPathComponent("test-mkdir-perms")

        try Dir.mkdir(newDir, permissions: 0o700)

        let attributes = try FileManager.default.attributesOfItem(atPath: newDir.path)
        let permissions = attributes[.posixPermissions] as? Int
        XCTAssertNotNil(permissions)

        #if os(macOS) || os(Linux)
            XCTAssertEqual(permissions! & 0o777, 0o700)
        #endif
    }

    func testMkdirFailsIfDirectoryExists() throws {
        let existingDir = tempDir.appendingPathComponent("existing")
        try Dir.mkdir(existingDir)

        XCTAssertThrowsError(try Dir.mkdir(existingDir)) { error in
            XCTAssertTrue(error is CocoaError)
        }
    }

    // MARK: - mktmpdir Tests

    func testMktmpdir() throws {
        let tmpDir = try Dir.mktmpdir()
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpDir.path))
        XCTAssertTrue(tmpDir.path.contains("d-"))

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: tmpDir.path, isDirectory: &isDirectory)
        XCTAssertTrue(isDirectory.boolValue)

        let attributes = try FileManager.default.attributesOfItem(atPath: tmpDir.path)
        let permissions = attributes[.posixPermissions] as? Int
        XCTAssertNotNil(permissions)

        #if os(macOS) || os(Linux)
            XCTAssertEqual(permissions! & 0o777, 0o700)
        #endif

        try FileManager.default.removeItem(at: tmpDir)
    }

    func testMktempdirWithPrefix() throws {
        let tmpDir = try Dir.mktmpdir(prefix: "fileotter")
        XCTAssertTrue(tmpDir.path.contains("fileotter-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpDir.path))

        try FileManager.default.removeItem(at: tmpDir)
    }

    func testMktempdirWithPrefixAndSuffix() throws {
        let tmpDir = try Dir.mktmpdir(prefix: "test", suffix: "tmp")
        XCTAssertTrue(tmpDir.lastPathComponent.hasPrefix("test-"))
        XCTAssertTrue(tmpDir.lastPathComponent.hasSuffix("-tmp"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpDir.path))

        try FileManager.default.removeItem(at: tmpDir)
    }

    func testMktempdirWithBlock() throws {
        var blockExecuted = false
        var tmpDirInBlock: URL?
        var fileCreated = false

        let result = try Dir.mktmpdir(prefix: "block") { tmpDir in
            blockExecuted = true
            tmpDirInBlock = tmpDir
            XCTAssertTrue(FileManager.default.fileExists(atPath: tmpDir.path))

            let testFile = tmpDir.appendingPathComponent("test.txt")
            try "Hello from mktmpdir block".write(to: testFile, atomically: true, encoding: .utf8)
            fileCreated = FileManager.default.fileExists(atPath: testFile.path)

            return "block result"
        }

        XCTAssertTrue(blockExecuted)
        XCTAssertEqual(result, "block result")
        XCTAssertTrue(fileCreated)

        if let tmpDirInBlock {
            XCTAssertFalse(FileManager.default.fileExists(atPath: tmpDirInBlock.path))
        }
    }

    func testMktempdirWithBlockThrowingError() {
        do {
            try Dir.mktmpdir { tmpDir in
                XCTAssertTrue(FileManager.default.fileExists(atPath: tmpDir.path))
                throw NSError(domain: "TestError", code: 42)
            }
            XCTFail("Should have thrown an error")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "TestError")
            XCTAssertEqual(nsError.code, 42)
        }
    }

    func testMktempdirEachCallCreatesUniqueDirectory() throws {
        let tmpDir1 = try Dir.mktmpdir()
        let tmpDir2 = try Dir.mktmpdir()

        XCTAssertNotEqual(tmpDir1, tmpDir2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpDir1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpDir2.path))

        try FileManager.default.removeItem(at: tmpDir1)
        try FileManager.default.removeItem(at: tmpDir2)
    }
}
