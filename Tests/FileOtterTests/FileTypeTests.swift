//
//  FileTypeTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import XCTest

final class FileTypeTests: XCTestCase {
    var tempDir: URL!
    var testFile: URL!
    var testDir: URL!

    override func setUpWithError() throws {
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FileTypeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        testFile = tempDir.appendingPathComponent("test.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        testDir = tempDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Existence Tests

    func testExists() throws {
        // Test with existing file
        XCTAssertTrue(File.exists(testFile))

        // Test with existing directory
        XCTAssertTrue(File.exists(testDir))
        XCTAssertTrue(File.exists(tempDir))
    }

    func testExistsForNonExistent() throws {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
        XCTAssertFalse(File.exists(nonExistent))

        let nonExistentDir = tempDir.appendingPathComponent("no-such-dir")
        XCTAssertFalse(File.exists(nonExistentDir))
    }

    func testExistsForDirectory() throws {
        // File.exists returns true for directories (like Ruby)
        XCTAssertTrue(File.exists(tempDir))
        XCTAssertTrue(File.exists(testDir))

        // Also test system directories
        XCTAssertTrue(File.exists(URL(fileURLWithPath: "/tmp")))
        XCTAssertTrue(File.exists(URL(fileURLWithPath: "/")))
    }

    // MARK: - File Type Tests

    func testIsFile() throws {
        // Returns true for regular files
        XCTAssertTrue(File.isFile(testFile))

        // Create another test file
        let anotherFile = tempDir.appendingPathComponent("another.txt")
        try "content".write(to: anotherFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(File.isFile(anotherFile))
    }

    func testIsFileForDirectory() throws {
        // Returns false for directories
        XCTAssertFalse(File.isFile(testDir))
        XCTAssertFalse(File.isFile(tempDir))
        XCTAssertFalse(File.isFile(URL(fileURLWithPath: "/")))

        // Returns false for non-existent paths
        let nonExistent = tempDir.appendingPathComponent("no-such-file.txt")
        XCTAssertFalse(File.isFile(nonExistent))
    }

    func testIsDirectory() throws {
        // Returns true for directories
        XCTAssertTrue(File.isDirectory(testDir))
        XCTAssertTrue(File.isDirectory(tempDir))
        XCTAssertTrue(File.isDirectory(URL(fileURLWithPath: "/")))
        XCTAssertTrue(File.isDirectory(URL(fileURLWithPath: "/tmp")))
    }

    func testIsDirectoryForFile() throws {
        // Returns false for files
        XCTAssertFalse(File.isDirectory(testFile))

        // Returns false for non-existent paths
        let nonExistent = tempDir.appendingPathComponent("no-such-dir")
        XCTAssertFalse(File.isDirectory(nonExistent))
    }

    func testIsSymlink() throws {
        // Create symlink to test file
        let symlinkURL = tempDir.appendingPathComponent("symlink.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: testFile)
        XCTAssertTrue(File.isSymlink(symlinkURL))

        // Create symlink to directory
        let dirSymlinkURL = tempDir.appendingPathComponent("dirlink")
        try FileManager.default.createSymbolicLink(at: dirSymlinkURL, withDestinationURL: testDir)
        XCTAssertTrue(File.isSymlink(dirSymlinkURL))
    }

    func testIsSymlinkForRegularFile() throws {
        // Regular files are not symlinks
        XCTAssertFalse(File.isSymlink(testFile))

        // Directories are not symlinks
        XCTAssertFalse(File.isSymlink(testDir))

        // Non-existent paths are not symlinks
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        XCTAssertFalse(File.isSymlink(nonExistent))
    }

    func testIsBlockDevice() throws {
        // Block devices are rare on macOS, but /dev/disk* exists
        // This test might fail in sandboxed environments
        if FileManager.default.fileExists(atPath: "/dev/disk0") {
            XCTAssertTrue(File.isBlockDevice(URL(fileURLWithPath: "/dev/disk0")))
        }

        // Regular files are not block devices
        XCTAssertFalse(File.isBlockDevice(testFile))
        XCTAssertFalse(File.isBlockDevice(testDir))
    }

    func testIsCharDevice() throws {
        // /dev/null is always a character device
        let devNull = URL(fileURLWithPath: "/dev/null")
        XCTAssertTrue(File.isCharDevice(devNull))

        // /dev/random is also a character device
        let devRandom = URL(fileURLWithPath: "/dev/random")
        if FileManager.default.fileExists(atPath: devRandom.path) {
            XCTAssertTrue(File.isCharDevice(devRandom))
        }

        // Regular files are not character devices
        XCTAssertFalse(File.isCharDevice(testFile))
        XCTAssertFalse(File.isCharDevice(testDir))
    }

    func testIsPipe() throws {
        // Creating FIFOs requires mkfifo system call
        // Skip this test for now as it requires additional implementation
        // Regular files are not pipes
        XCTAssertFalse(File.isPipe(testFile))
        XCTAssertFalse(File.isPipe(testDir))
    }

    func testIsSocket() throws {
        // Unix domain sockets are rare and hard to create in tests
        // Regular files are not sockets
        XCTAssertFalse(File.isSocket(testFile))
        XCTAssertFalse(File.isSocket(testDir))
    }

    // MARK: - Empty/Zero Tests

    func testIsEmpty() throws {
        // Create empty file
        let emptyFile = tempDir.appendingPathComponent("empty.txt")
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(try File.isEmpty(emptyFile))
    }

    func testIsEmptyForNonEmpty() throws {
        // testFile has content
        XCTAssertFalse(try File.isEmpty(testFile))

        // Create another non-empty file
        let nonEmptyFile = tempDir.appendingPathComponent("nonempty.txt")
        try "Some content".write(to: nonEmptyFile, atomically: true, encoding: .utf8)
        XCTAssertFalse(try File.isEmpty(nonEmptyFile))
    }

    func testIsEmptyThrowsForNonExistent() throws {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
        XCTAssertThrowsError(try File.isEmpty(nonExistent))
    }

    func testIsZero() throws {
        // Create empty file
        let emptyFile = tempDir.appendingPathComponent("zero.txt")
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)

        // isZero is alias for isEmpty
        XCTAssertTrue(try File.isZero(emptyFile))
        XCTAssertFalse(try File.isZero(testFile))
    }

    // MARK: - ftype Tests

    func testFtypeForFile() throws {
        XCTAssertEqual(File.ftype(testFile), .file)

        // Create another file to test
        let anotherFile = tempDir.appendingPathComponent("another.dat")
        try Data().write(to: anotherFile)
        XCTAssertEqual(File.ftype(anotherFile), .file)
    }

    func testFtypeForDirectory() throws {
        XCTAssertEqual(File.ftype(testDir), .directory)
        XCTAssertEqual(File.ftype(tempDir), .directory)
        XCTAssertEqual(File.ftype(URL(fileURLWithPath: "/")), .directory)
    }

    func testFtypeForSymlink() throws {
        let symlinkURL = tempDir.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: testFile)
        XCTAssertEqual(File.ftype(symlinkURL), .link)

        // Symlink to directory
        let dirSymlinkURL = tempDir.appendingPathComponent("dirlink")
        try FileManager.default.createSymbolicLink(at: dirSymlinkURL, withDestinationURL: testDir)
        XCTAssertEqual(File.ftype(dirSymlinkURL), .link)
    }

    func testFtypeForCharDevice() throws {
        // /dev/null is a character device
        let devNull = URL(fileURLWithPath: "/dev/null")
        XCTAssertEqual(File.ftype(devNull), .characterSpecial)
    }

    func testFtypeForBlockDevice() throws {
        // Block devices are rare on macOS
        // This test might fail in sandboxed environments
        if FileManager.default.fileExists(atPath: "/dev/disk0") {
            XCTAssertEqual(File.ftype(URL(fileURLWithPath: "/dev/disk0")), .blockSpecial)
        }
    }

    func testFtypeForFifo() throws {
        // FIFOs require special creation
        // Skip for now
    }

    func testFtypeForSocket() throws {
        // Sockets require special creation
        // Skip for now
    }

    func testFtypeForUnknown() throws {
        // Non-existent files return unknown
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        XCTAssertEqual(File.ftype(nonExistent), .unknown)
    }
}
