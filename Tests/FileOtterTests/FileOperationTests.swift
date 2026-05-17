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
        // Create hard link
        let hardLink = tempDir.appendingPathComponent("hardlink.txt")
        try File.link(source: sourceFile, destination: hardLink)
        
        // Both files should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: hardLink.path))
        
        // They should have the same content
        XCTAssertEqual(try String(contentsOf: hardLink), "Source content")
        
        // They should be the same file (same inode)
        XCTAssertTrue(try File.identical(sourceFile, hardLink))
    }

    func testLinkThrowsIfDestExists() throws {
        try "Existing content".write(to: destFile, atomically: true, encoding: .utf8)
        
        // Should throw because destination exists
        XCTAssertThrowsError(try File.link(source: sourceFile, destination: destFile))
        
        // Destination should still have original content
        XCTAssertEqual(try String(contentsOf: destFile), "Existing content")
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
        // Create file with content
        let file = tempDir.appendingPathComponent("truncate-test.txt")
        let originalContent = "This is a longer piece of content that will be truncated"
        try originalContent.write(to: file, atomically: true, encoding: .utf8)
        
        // Truncate to 10 bytes
        try File.truncate(file, to: 10)
        
        // File should be truncated
        XCTAssertEqual(try File.size(file), 10)
        XCTAssertEqual(try String(contentsOf: file), "This is a ")
    }

    func testTruncateExpands() throws {
        // Create small file
        let file = tempDir.appendingPathComponent("expand-test.txt")
        try "Short".write(to: file, atomically: true, encoding: .utf8)
        
        // Expand to 20 bytes (should pad with zeros)
        try File.truncate(file, to: 20)
        
        XCTAssertEqual(try File.size(file), 20)
        
        // Read raw data to check padding
        let data = try Data(contentsOf: file)
        XCTAssertEqual(data.count, 20)
        
        // First 5 bytes should be "Short"
        let shortData = "Short".data(using: .utf8)!
        XCTAssertEqual(data.prefix(5), shortData)
        
        // Remaining bytes should be zeros
        for i in 5..<20 {
            XCTAssertEqual(data[i], 0)
        }
    }

    func testTruncateThrowsForNonExistent() throws {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
        XCTAssertThrowsError(try File.truncate(nonExistent, to: 10))
    }

    func testInstanceTruncate() throws {
        try "hello, world".write(to: sourceFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(try File.size(sourceFile), 12)

        let file = try File(url: sourceFile, mode: .readWrite)
        defer { try? file.close() }
        try file.truncate(to: 5)

        XCTAssertEqual(try File.size(sourceFile), 5)
        XCTAssertEqual(try String(contentsOf: sourceFile, encoding: .utf8), "hello")
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
        // Create file
        let file = tempDir.appendingPathComponent("utime-test.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        // Set specific times
        let atime = Date(timeIntervalSince1970: 1000000)
        let mtime = Date(timeIntervalSince1970: 2000000)
        
        try File.utime(file, atime: atime, mtime: mtime)
        
        // Verify times were set
        let newMtime = try File.mtime(file)
        XCTAssertEqual(newMtime.timeIntervalSince1970, mtime.timeIntervalSince1970, accuracy: 1.0)
    }

    func testUtimeFollowsSymlinks() throws {
        // Create target and symlink
        let target = tempDir.appendingPathComponent("utime-target.txt")
        try "content".write(to: target, atomically: true, encoding: .utf8)
        
        let link = tempDir.appendingPathComponent("utime-link.txt")
        try File.symlink(source: target, destination: link)
        
        // Set times via symlink
        let atime = Date(timeIntervalSince1970: 1000000)
        let mtime = Date(timeIntervalSince1970: 2000000)
        
        try File.utime(link, atime: atime, mtime: mtime)
        
        // Target should have new times
        let targetMtime = try File.mtime(target)
        XCTAssertEqual(targetMtime.timeIntervalSince1970, mtime.timeIntervalSince1970, accuracy: 1.0)
    }

    func testLutime() throws {
        // Create target and symlink
        let target = tempDir.appendingPathComponent("lutime-target.txt")
        try "content".write(to: target, atomically: true, encoding: .utf8)
        
        let link = tempDir.appendingPathComponent("lutime-link.txt")
        try File.symlink(source: target, destination: link)
        
        // Get original target mtime
        let originalTargetMtime = try File.mtime(target)
        
        // Set times on symlink itself (not target)
        let atime = Date(timeIntervalSince1970: 1000000)
        let mtime = Date(timeIntervalSince1970: 2000000)
        
        try File.lutime(link, atime: atime, mtime: mtime)
        
        // Target should still have original time
        let targetMtime = try File.mtime(target)
        XCTAssertEqual(targetMtime.timeIntervalSince1970, originalTargetMtime.timeIntervalSince1970, accuracy: 1.0)
        
        // Symlink should have new time (check with lstat)
        let linkStat = try File.linkStatus(link)
        XCTAssertEqual(linkStat.mtime.timeIntervalSince1970, mtime.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - mkfifo Tests

    func testMkfifo() throws {
        // Create named pipe
        let fifo = tempDir.appendingPathComponent("test.fifo")
        try File.mkfifo(fifo)
        
        // Verify it's a pipe
        XCTAssertTrue(File.isPipe(fifo))
        XCTAssertFalse(File.isFile(fifo))
        XCTAssertFalse(File.isDirectory(fifo))
    }

    func testMkfifoWithPermissions() throws {
        // Create named pipe with specific permissions
        let fifo = tempDir.appendingPathComponent("test-perms.fifo")
        try File.mkfifo(fifo, permissions: 0o644)
        
        // Verify it's a pipe
        XCTAssertTrue(File.isPipe(fifo))
        
        // Verify permissions (masking out file type bits)
        let stat = try File.fileStatus(fifo)
        let perms = stat.mode & 0o777
        // Actual permissions may be affected by umask
        XCTAssertTrue(perms <= 0o644)
    }

    func testMkfifoThrowsIfExists() throws {
        // Create a regular file
        let file = tempDir.appendingPathComponent("existing.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        // Should throw when trying to create fifo with same name
        XCTAssertThrowsError(try File.mkfifo(file))
        
        // Original file should still be a regular file
        XCTAssertTrue(File.isFile(file))
        XCTAssertFalse(File.isPipe(file))
    }

    // MARK: - identical Tests

    func testIdentical() throws {
        // Same file should be identical to itself
        XCTAssertTrue(try File.identical(sourceFile, sourceFile))
    }

    func testIdenticalForHardLink() throws {
        // Create hard link
        let hardLink = tempDir.appendingPathComponent("hardlink.txt")
        try File.link(source: sourceFile, destination: hardLink)
        
        // Hard links point to same inode
        XCTAssertTrue(try File.identical(sourceFile, hardLink))
        XCTAssertTrue(try File.identical(hardLink, sourceFile))
    }

    func testIdenticalForSymlink() throws {
        // Create symlink
        let symlink = tempDir.appendingPathComponent("symlink.txt")
        try File.symlink(source: sourceFile, destination: symlink)
        
        // Symlink and target should be identical (stat follows symlinks)
        XCTAssertTrue(try File.identical(sourceFile, symlink))
        XCTAssertTrue(try File.identical(symlink, sourceFile))
    }

    func testIdenticalForDifferent() throws {
        // Create another file
        let otherFile = tempDir.appendingPathComponent("other.txt")
        try "Other content".write(to: otherFile, atomically: true, encoding: .utf8)
        
        // Different files should not be identical
        XCTAssertFalse(try File.identical(sourceFile, otherFile))
        XCTAssertFalse(try File.identical(otherFile, sourceFile))
    }

    func testIdenticalForSameContent() throws {
        // Create another file with same content
        let copyFile = tempDir.appendingPathComponent("copy.txt")
        try "Source content".write(to: copyFile, atomically: true, encoding: .utf8)
        
        // Files with same content but different inodes are not identical
        XCTAssertFalse(try File.identical(sourceFile, copyFile))
        XCTAssertFalse(try File.identical(copyFile, sourceFile))
    }
}
