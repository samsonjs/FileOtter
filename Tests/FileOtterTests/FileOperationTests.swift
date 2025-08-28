//
//  FileOperationTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import XCTest

final class FileOperationTests: XCTestCase {
    var tempDir: URL!
    var sourceFile: URL!
    var destFile: URL!

    override func setUpWithError() throws {
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FileOperationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        sourceFile = tempDir.appendingPathComponent("source.txt")
        try "Source content".write(to: sourceFile, atomically: true, encoding: .utf8)

        destFile = tempDir.appendingPathComponent("dest.txt")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Link Tests

    func testLink() throws {
        // TODO: Implement
        // File.link(source, destination) creates hard link
    }

    func testLinkThrowsIfDestExists() throws {
        // TODO: Implement
        // File.link should not overwrite existing file
    }

    func testSymlink() throws {
        // Create a file to link to
        let target = tempDir.appendingPathComponent("target.txt")
        try "Target content".write(to: target, atomically: true, encoding: .utf8)

        // Create symlink
        let link = tempDir.appendingPathComponent("symlink.txt")
        try File.symlink(source: target, destination: link)

        // Verify symlink exists and points to target
        XCTAssertTrue(FileManager.default.fileExists(atPath: link.path))

        // Reading through symlink should get target's content
        XCTAssertEqual(try String(contentsOf: link), "Target content")
    }

    func testSymlinkThrowsIfDestExists() throws {
        let target = tempDir.appendingPathComponent("target.txt")
        try "Target".write(to: target, atomically: true, encoding: .utf8)

        let existingFile = tempDir.appendingPathComponent("existing.txt")
        try "Existing".write(to: existingFile, atomically: true, encoding: .utf8)

        // Should throw because destination exists
        XCTAssertThrowsError(try File.symlink(source: target, destination: existingFile))
    }

    func testReadlink() throws {
        // Create target and symlink
        let target = tempDir.appendingPathComponent("readlink-target.txt")
        try "Content".write(to: target, atomically: true, encoding: .utf8)

        let link = tempDir.appendingPathComponent("readlink-symlink.txt")
        try File.symlink(source: target, destination: link)

        // readlink should return the target path
        let readTarget = try File.readlink(link)
        XCTAssertEqual(readTarget.lastPathComponent, "readlink-target.txt")
    }

    func testReadlinkThrowsForNonSymlink() throws {
        // Regular file, not a symlink
        XCTAssertThrowsError(try File.readlink(sourceFile))
    }

    // MARK: - Delete Tests

    func testUnlink() throws {
        // Create a file to delete
        let fileToDelete = tempDir.appendingPathComponent("delete-me.txt")
        try "Delete this file".write(to: fileToDelete, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileToDelete.path))

        // Delete it
        try File.unlink(fileToDelete)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileToDelete.path))
    }

    func testUnlinkThrowsForNonExistent() throws {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
        XCTAssertThrowsError(try File.unlink(nonExistent))
    }

    func testDelete() throws {
        // Create a file to delete
        let fileToDelete = tempDir.appendingPathComponent("delete-me-too.txt")
        try "Delete this too".write(to: fileToDelete, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileToDelete.path))

        // Delete is an alias for unlink
        try File.delete(fileToDelete)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileToDelete.path))
    }

    // MARK: - Rename Tests

    func testRename() throws {
        // Create source file
        let source = tempDir.appendingPathComponent("original.txt")
        let dest = tempDir.appendingPathComponent("renamed.txt")
        let content = "Original content"
        try content.write(to: source, atomically: true, encoding: .utf8)

        // Rename it
        try File.rename(source: source, destination: dest)

        // Source should not exist, dest should exist with same content
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
        XCTAssertEqual(try String(contentsOf: dest), content)
    }

    func testRenameOverwritesExisting() throws {
        // Create source and destination files
        let source = tempDir.appendingPathComponent("source.txt")
        let dest = tempDir.appendingPathComponent("existing.txt")
        try "Source content".write(to: source, atomically: true, encoding: .utf8)
        try "Old content".write(to: dest, atomically: true, encoding: .utf8)

        // Rename should overwrite destination
        try File.rename(source: source, destination: dest)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: dest), "Source content")
    }

    func testRenameThrowsForNonExistentSource() throws {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")

        // Test 1: When destination doesn't exist
        let newDest = tempDir.appendingPathComponent("new-dest.txt")
        XCTAssertThrowsError(try File.rename(source: nonExistent, destination: newDest))
        XCTAssertFalse(FileManager.default.fileExists(atPath: newDest.path))

        // Test 2: When destination exists (should be preserved on failure)
        let existingDest = tempDir.appendingPathComponent("existing.txt")
        let importantContent = "Important data that must not be lost"
        try importantContent.write(to: existingDest, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try File.rename(source: nonExistent, destination: existingDest))

        // Destination should still exist with original content
        XCTAssertTrue(FileManager.default.fileExists(atPath: existingDest.path))
        XCTAssertEqual(try String(contentsOf: existingDest), importantContent)
    }

    // MARK: - Truncate Tests

    func testTruncate() throws {
        // TODO: Implement
        // File.truncate(url, size) truncates file to size
    }

    func testTruncateExpands() throws {
        // TODO: Implement
        // truncate can expand file with zero padding
    }

    func testTruncateThrowsForNonExistent() throws {
        // TODO: Implement
    }

    func testInstanceTruncate() throws {
        // TODO: Implement
        // file.truncate(size) truncates open file
    }

    // MARK: - Touch Tests

    func testTouch() throws {
        // Create a file with old times
        let file = tempDir.appendingPathComponent("touch-test.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        // Get initial mtime
        let initialMtime = try File.mtime(file)

        // Wait a moment and touch
        Thread.sleep(forTimeInterval: 0.1)
        try File.touch(file)

        // mtime should be updated
        let newMtime = try File.mtime(file)
        XCTAssertGreaterThan(newMtime, initialMtime)
    }

    func testTouchCreatesFile() throws {
        // Touch non-existent file should create it
        let newFile = tempDir.appendingPathComponent("created-by-touch.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: newFile.path))

        try File.touch(newFile)

        XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
        XCTAssertEqual(try File.size(newFile), 0) // Should be empty
    }

    // MARK: - utime Tests

    func testUtime() throws {
        // TODO: Implement
        // File.utime(url, atime, mtime) sets specific times
    }

    func testUtimeFollowsSymlinks() throws {
        // TODO: Implement
        // utime affects target of symlink
    }

    func testLutime() throws {
        // TODO: Implement
        // File.lutime(url, atime, mtime) sets symlink times
    }

    // MARK: - mkfifo Tests

    func testMkfifo() throws {
        // TODO: Implement
        // File.mkfifo(url) creates named pipe
    }

    func testMkfifoWithPermissions() throws {
        // TODO: Implement
        // File.mkfifo(url, permissions) creates with specific perms
    }

    func testMkfifoThrowsIfExists() throws {
        // TODO: Implement
    }

    // MARK: - identical Tests

    func testIdentical() throws {
        // TODO: Implement
        // File.identical(url1, url2) returns true for same file
    }

    func testIdenticalForHardLink() throws {
        // TODO: Implement
        // identical returns true for hard links to same file
    }

    func testIdenticalForSymlink() throws {
        // TODO: Implement
        // identical returns true for symlink and target
    }

    func testIdenticalForDifferent() throws {
        // TODO: Implement
        // identical returns false for different files
    }

    func testIdenticalForSameContent() throws {
        // TODO: Implement
        // identical returns false for files with same content but different inodes
    }
}
