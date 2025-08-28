//
//  FileInfoTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import XCTest

final class FileInfoTests: XCTestCase {
    var tempDir: URL!
    var testFile: URL!

    override func setUpWithError() throws {
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FileInfoTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        testFile = tempDir.appendingPathComponent("test.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Time-based Tests

    func testAtime() throws {
        let atime = try File.atime(testFile)
        XCTAssertNotNil(atime)
        // Access time should be recent (within last hour)
        XCTAssertLessThan(Date().timeIntervalSince(atime), 3600)
    }

    func testMtime() throws {
        // Get initial mtime
        let initialMtime = try File.mtime(testFile)

        // Wait a moment and modify the file
        Thread.sleep(forTimeInterval: 0.1)
        try "Modified content".write(to: testFile, atomically: true, encoding: .utf8)

        // mtime should be updated
        let newMtime = try File.mtime(testFile)
        XCTAssertGreaterThan(newMtime, initialMtime)
    }

    func testCtime() throws {
        let ctime = try File.ctime(testFile)
        XCTAssertNotNil(ctime)
        // Status change time should be recent
        XCTAssertLessThan(Date().timeIntervalSince(ctime), 3600)
    }

    func testBirthtime() throws {
        // Create a new file
        let newFile = tempDir.appendingPathComponent("birthtime-test.txt")
        let beforeCreation = Date()
        Thread.sleep(forTimeInterval: 0.01)
        try "content".write(to: newFile, atomically: true, encoding: .utf8)
        Thread.sleep(forTimeInterval: 0.01)
        let afterCreation = Date()

        let birthtime = try File.birthtime(newFile)
        XCTAssertGreaterThanOrEqual(birthtime, beforeCreation)
        XCTAssertLessThanOrEqual(birthtime, afterCreation)
    }

    func testBirthtimeThrowsOnUnsupportedPlatform() throws {
        // TODO: Implement if platform doesn't support birthtime
    }

    // MARK: - Size Tests

    func testSize() throws {
        // Test with known content
        let content = "Test content"
        let expectedSize = content.data(using: .utf8)!.count
        XCTAssertEqual(try File.size(testFile), expectedSize)

        // Test with larger file
        let largeFile = tempDir.appendingPathComponent("large.txt")
        let largeContent = String(repeating: "Hello World! ", count: 100)
        try largeContent.write(to: largeFile, atomically: true, encoding: .utf8)
        let largeExpectedSize = largeContent.data(using: .utf8)!.count
        XCTAssertEqual(try File.size(largeFile), largeExpectedSize)
    }

    func testSizeThrowsForNonExistent() throws {
        let nonExistent = tempDir.appendingPathComponent("no-such-file.txt")
        XCTAssertThrowsError(try File.size(nonExistent))
    }

    func testSizeForEmptyFile() throws {
        let emptyFile = tempDir.appendingPathComponent("empty.txt")
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(try File.size(emptyFile), 0)
    }

    // MARK: - Stat Tests

    func testStat() throws {
        let stat = try File.fileStatus(testFile)

        // Verify basic properties
        XCTAssertGreaterThan(stat.ino, 0) // inode should be positive
        XCTAssertGreaterThan(stat.uid, 0) // uid should be positive
        XCTAssertGreaterThan(stat.gid, 0) // gid should be positive
        XCTAssertEqual(stat.size, 12) // "Test content" is 12 bytes

        // Verify times are reasonable
        XCTAssertLessThan(Date().timeIntervalSince(stat.mtime), 3600)
        XCTAssertLessThan(Date().timeIntervalSince(stat.atime), 3600)
        XCTAssertNotNil(stat.birthtime)
    }

    func testStatThrowsForNonExistent() throws {
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        XCTAssertThrowsError(try File.fileStatus(nonExistent))
    }

    func testLstat() throws {
        // For regular files, lstat should be same as stat
        let lstat = try File.linkStatus(testFile)
        let stat = try File.fileStatus(testFile)

        XCTAssertEqual(lstat.size, stat.size)
        XCTAssertEqual(lstat.ino, stat.ino)
        XCTAssertEqual(lstat.mode, stat.mode)
    }

    func testLstatForSymlink() throws {
        // Create a larger target file
        let targetFile = tempDir.appendingPathComponent("target.txt")
        let targetContent = "This is the target file content"
        try targetContent.write(to: targetFile, atomically: true, encoding: .utf8)

        // Create symlink
        let symlinkURL = tempDir.appendingPathComponent("symlink.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: targetFile)

        let lstat = try File.linkStatus(symlinkURL)
        let stat = try File.fileStatus(symlinkURL)

        // lstat should return symlink's own stats (smaller size)
        // stat should follow the symlink to the target (larger size)
        XCTAssertNotEqual(lstat.size, stat.size)
        XCTAssertEqual(stat.size, Int64(targetContent.data(using: .utf8)!.count))

        // lstat should indicate it's a symlink via mode
        let isLink = (lstat.mode & 0o170000) == 0o120000 // S_IFLNK
        XCTAssertTrue(isLink)
    }

    // MARK: - Instance Method Tests

    func testInstanceAtime() throws {
        // TODO: Implement
        // file.atime returns access time
    }

    func testInstanceMtime() throws {
        // TODO: Implement
        // file.mtime returns modification time
    }

    func testInstanceCtime() throws {
        // TODO: Implement
        // file.ctime returns status change time
    }

    func testInstanceBirthtime() throws {
        // TODO: Implement
        // file.birthtime returns creation time
    }

    func testInstanceSize() throws {
        // TODO: Implement
        // file.size returns file size
    }

    func testInstanceStat() throws {
        // TODO: Implement
        // file.stat() returns FileStat object
    }

    func testInstanceLstat() throws {
        // TODO: Implement
        // file.lstat() doesn't follow symlinks
    }

    // MARK: - FileStat Tests

    func testFileStatProperties() throws {
        // TODO: Implement
        // Verify all FileStat properties are populated correctly
    }

    func testFileStatForDirectory() throws {
        // TODO: Implement
    }

    func testFileStatForSymlink() throws {
        // TODO: Implement
    }
}
