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

        XCTAssertGreaterThan(stat.ino, 0)
        XCTAssertGreaterThan(stat.uid, 0)
        XCTAssertGreaterThan(stat.gid, 0)
        XCTAssertEqual(stat.size, 12)

        XCTAssertLessThan(Date().timeIntervalSince(stat.mtime), 3600)
        XCTAssertLessThan(Date().timeIntervalSince(stat.atime), 3600)
        // birthtime is only exposed in Darwin's stat; Linux requires statx(2).
        #if canImport(Darwin)
        XCTAssertNotNil(stat.birthtime)
        #endif
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
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        XCTAssertLessThan(Date().timeIntervalSince(file.atime), 3600)
    }

    func testInstanceMtime() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        let viaInstance = file.mtime
        let viaStatic = try File.mtime(testFile)
        // Same file, same mtime (within sub-second precision).
        XCTAssertEqual(viaInstance.timeIntervalSince1970, viaStatic.timeIntervalSince1970, accuracy: 1.0)
    }

    func testInstanceCtime() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        XCTAssertLessThan(Date().timeIntervalSince(file.ctime), 3600)
    }

    func testInstanceBirthtime() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        // birthtime is Date? — Darwin returns a value; Linux returns nil
        // because the kernel only exposes creation time via statx(2).
        #if canImport(Darwin)
        let viaInstance = try XCTUnwrap(file.birthtime)
        let viaStatic = try File.birthtime(testFile)
        XCTAssertEqual(viaInstance.timeIntervalSince1970, viaStatic.timeIntervalSince1970, accuracy: 1.0)
        #else
        XCTAssertNil(file.birthtime)
        #endif
    }

    func testInstanceSize() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        XCTAssertEqual(file.size, "Test content".utf8.count)
    }

    func testInstanceStat() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        let stat = try file.fileStat()
        XCTAssertEqual(stat.size, 12)
        XCTAssertGreaterThan(stat.ino, 0)
    }

    func testInstanceLstat() throws {
        // Create a symlink and open the symlink path. instance lstat reports the
        // *link* itself; instance fileStat follows it to the target.
        let target = tempDir.appendingPathComponent("target.txt")
        try "This is the target file content".write(to: target, atomically: true, encoding: .utf8)
        let link = tempDir.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let file = try File(url: link, mode: .read)
        defer { try? file.close() }

        let viaStat = try file.fileStat()
        let viaLstat = try file.fileLstat()
        XCTAssertNotEqual(viaLstat.size, viaStat.size)
        let isLink = (viaLstat.mode & 0o170000) == 0o120000 // S_IFLNK
        XCTAssertTrue(isLink)
    }

    // MARK: - FileStat Tests

    func testFileStatProperties() throws {
        let stat = try File.fileStatus(testFile)
        // Every field should be populated with something sensible.
        XCTAssertGreaterThan(stat.ino, 0)
        XCTAssertGreaterThan(stat.nlink, 0)
        XCTAssertGreaterThanOrEqual(stat.uid, 0)
        XCTAssertGreaterThanOrEqual(stat.gid, 0)
        XCTAssertEqual(stat.size, 12)
        XCTAssertGreaterThan(stat.blksize, 0)
        XCTAssertGreaterThanOrEqual(stat.blocks, 0)
        // Mode contains both type bits and permission bits.
        let isRegularFile = (stat.mode & 0o170000) == 0o100000
        XCTAssertTrue(isRegularFile)
        // Times should be recent.
        XCTAssertLessThan(Date().timeIntervalSince(stat.atime), 3600)
        XCTAssertLessThan(Date().timeIntervalSince(stat.mtime), 3600)
        XCTAssertLessThan(Date().timeIntervalSince(stat.ctime), 3600)
    }

    func testFileStatForDirectory() throws {
        let stat = try File.fileStatus(tempDir)
        let isDirectory = (stat.mode & 0o170000) == 0o040000
        XCTAssertTrue(isDirectory)
    }

    func testFileStatForSymlink() throws {
        let target = tempDir.appendingPathComponent("target2.txt")
        try "x".write(to: target, atomically: true, encoding: .utf8)
        let link = tempDir.appendingPathComponent("link2.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        // fileStatus follows the symlink; linkStatus inspects the link itself.
        let followed = try File.fileStatus(link)
        let linkOnly = try File.linkStatus(link)
        let followedIsRegular = (followed.mode & 0o170000) == 0o100000
        let linkIsSymlink = (linkOnly.mode & 0o170000) == 0o120000
        XCTAssertTrue(followedIsRegular)
        XCTAssertTrue(linkIsSymlink)
    }
}
