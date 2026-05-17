//
//  FileOperationTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import Foundation
import Testing

@Suite final class FileOperationTests {
    let tempDir: URL
    let sourceFile: URL
    let destFile: URL

    init() throws {
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FileOperationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        sourceFile = tempDir.appendingPathComponent("source.txt")
        try "Source content".write(to: sourceFile, atomically: true, encoding: .utf8)

        destFile = tempDir.appendingPathComponent("dest.txt")
    }

    deinit {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Link Tests

    @Test func link() throws {
        let hardLink = tempDir.appendingPathComponent("hardlink.txt")
        try File.link(source: sourceFile, destination: hardLink)

        #expect(FileManager.default.fileExists(atPath: sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: hardLink.path))

        #expect(try String(contentsOf: hardLink) == "Source content")

        // Same inode.
        #expect(try File.identical(sourceFile, hardLink))
    }

    @Test func linkThrowsIfDestExists() throws {
        try "Existing content".write(to: destFile, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) {
            try File.link(source: sourceFile, destination: destFile)
        }

        #expect(try String(contentsOf: destFile) == "Existing content")
    }

    @Test func symlink() throws {
        let target = tempDir.appendingPathComponent("target.txt")
        try "Target content".write(to: target, atomically: true, encoding: .utf8)

        let link = tempDir.appendingPathComponent("symlink.txt")
        try File.symlink(source: target, destination: link)

        #expect(FileManager.default.fileExists(atPath: link.path))
        #expect(try String(contentsOf: link) == "Target content")
    }

    @Test func symlinkThrowsIfDestExists() throws {
        let target = tempDir.appendingPathComponent("target.txt")
        try "Target".write(to: target, atomically: true, encoding: .utf8)

        let existingFile = tempDir.appendingPathComponent("existing.txt")
        try "Existing".write(to: existingFile, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) {
            try File.symlink(source: target, destination: existingFile)
        }
    }

    @Test func readlink() throws {
        let target = tempDir.appendingPathComponent("readlink-target.txt")
        try "Content".write(to: target, atomically: true, encoding: .utf8)

        let link = tempDir.appendingPathComponent("readlink-symlink.txt")
        try File.symlink(source: target, destination: link)

        let readTarget = try File.readlink(link)
        #expect(readTarget.lastPathComponent == "readlink-target.txt")
    }

    @Test func readlinkThrowsForNonSymlink() {
        #expect(throws: (any Error).self) {
            try File.readlink(sourceFile)
        }
    }

    // MARK: - Delete Tests

    @Test func unlink() throws {
        let fileToDelete = tempDir.appendingPathComponent("delete-me.txt")
        try "Delete this file".write(to: fileToDelete, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: fileToDelete.path))

        try File.unlink(fileToDelete)
        #expect(!FileManager.default.fileExists(atPath: fileToDelete.path))
    }

    @Test func unlinkThrowsForNonExistent() {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
        #expect(throws: (any Error).self) {
            try File.unlink(nonExistent)
        }
    }

    @Test func delete() throws {
        let fileToDelete = tempDir.appendingPathComponent("delete-me-too.txt")
        try "Delete this too".write(to: fileToDelete, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: fileToDelete.path))

        // Delete is an alias for unlink.
        try File.delete(fileToDelete)
        #expect(!FileManager.default.fileExists(atPath: fileToDelete.path))
    }

    // MARK: - Rename Tests

    @Test func rename() throws {
        let source = tempDir.appendingPathComponent("original.txt")
        let dest = tempDir.appendingPathComponent("renamed.txt")
        let content = "Original content"
        try content.write(to: source, atomically: true, encoding: .utf8)

        try File.rename(source: source, destination: dest)

        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: dest.path))
        #expect(try String(contentsOf: dest) == content)
    }

    @Test func renameOverwritesExisting() throws {
        let source = tempDir.appendingPathComponent("source.txt")
        let dest = tempDir.appendingPathComponent("existing.txt")
        try "Source content".write(to: source, atomically: true, encoding: .utf8)
        try "Old content".write(to: dest, atomically: true, encoding: .utf8)

        try File.rename(source: source, destination: dest)

        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(try String(contentsOf: dest) == "Source content")
    }

    @Test func renameThrowsForNonExistentSource() throws {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")

        // When destination doesn't exist.
        let newDest = tempDir.appendingPathComponent("new-dest.txt")
        #expect(throws: (any Error).self) {
            try File.rename(source: nonExistent, destination: newDest)
        }
        #expect(!FileManager.default.fileExists(atPath: newDest.path))

        // When destination exists, it should be preserved on failure.
        let existingDest = tempDir.appendingPathComponent("existing.txt")
        let importantContent = "Important data that must not be lost"
        try importantContent.write(to: existingDest, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) {
            try File.rename(source: nonExistent, destination: existingDest)
        }

        #expect(FileManager.default.fileExists(atPath: existingDest.path))
        #expect(try String(contentsOf: existingDest) == importantContent)
    }

    // MARK: - Truncate Tests

    @Test func truncate() throws {
        let file = tempDir.appendingPathComponent("truncate-test.txt")
        let originalContent = "This is a longer piece of content that will be truncated"
        try originalContent.write(to: file, atomically: true, encoding: .utf8)

        try File.truncate(file, to: 10)

        #expect(try File.size(file) == 10)
        #expect(try String(contentsOf: file) == "This is a ")
    }

    @Test func truncateExpands() throws {
        let file = tempDir.appendingPathComponent("expand-test.txt")
        try "Short".write(to: file, atomically: true, encoding: .utf8)

        // Expand to 20 bytes (should pad with zeros).
        try File.truncate(file, to: 20)

        #expect(try File.size(file) == 20)

        let data = try Data(contentsOf: file)
        #expect(data.count == 20)

        // First 5 bytes should be "Short".
        let shortData = "Short".data(using: .utf8)!
        #expect(data.prefix(5) == shortData)

        // Remaining bytes should be zeros.
        for i in 5..<20 {
            #expect(data[i] == 0)
        }
    }

    @Test func truncateThrowsForNonExistent() {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
        #expect(throws: (any Error).self) {
            try File.truncate(nonExistent, to: 10)
        }
    }

    @Test func instanceTruncate() throws {
        try "hello, world".write(to: sourceFile, atomically: true, encoding: .utf8)
        #expect(try File.size(sourceFile) == 12)

        let file = try File(url: sourceFile, mode: .readWrite)
        defer { try? file.close() }
        try file.truncate(to: 5)

        #expect(try File.size(sourceFile) == 5)
        #expect(try String(contentsOf: sourceFile, encoding: .utf8) == "hello")
    }

    // MARK: - Touch Tests

    @Test func touch() throws {
        let file = tempDir.appendingPathComponent("touch-test.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let initialMtime = try File.mtime(file)

        Thread.sleep(forTimeInterval: 0.1)
        try File.touch(file)

        let newMtime = try File.mtime(file)
        #expect(newMtime > initialMtime)
    }

    @Test func touchCreatesFile() throws {
        let newFile = tempDir.appendingPathComponent("created-by-touch.txt")
        #expect(!FileManager.default.fileExists(atPath: newFile.path))

        try File.touch(newFile)

        #expect(FileManager.default.fileExists(atPath: newFile.path))
        #expect(try File.size(newFile) == 0)
    }

    // MARK: - utime Tests

    @Test func utime() throws {
        let file = tempDir.appendingPathComponent("utime-test.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let atime = Date(timeIntervalSince1970: 1000000)
        let mtime = Date(timeIntervalSince1970: 2000000)

        try File.utime(file, atime: atime, mtime: mtime)

        let newMtime = try File.mtime(file)
        #expect(abs(newMtime.timeIntervalSince1970 - mtime.timeIntervalSince1970) < 1.0)
    }

    @Test func utimeFollowsSymlinks() throws {
        let target = tempDir.appendingPathComponent("utime-target.txt")
        try "content".write(to: target, atomically: true, encoding: .utf8)

        let link = tempDir.appendingPathComponent("utime-link.txt")
        try File.symlink(source: target, destination: link)

        let atime = Date(timeIntervalSince1970: 1000000)
        let mtime = Date(timeIntervalSince1970: 2000000)

        try File.utime(link, atime: atime, mtime: mtime)

        let targetMtime = try File.mtime(target)
        #expect(abs(targetMtime.timeIntervalSince1970 - mtime.timeIntervalSince1970) < 1.0)
    }

    @Test func lutime() throws {
        let target = tempDir.appendingPathComponent("lutime-target.txt")
        try "content".write(to: target, atomically: true, encoding: .utf8)

        let link = tempDir.appendingPathComponent("lutime-link.txt")
        try File.symlink(source: target, destination: link)

        let originalTargetMtime = try File.mtime(target)

        let atime = Date(timeIntervalSince1970: 1000000)
        let mtime = Date(timeIntervalSince1970: 2000000)

        try File.lutime(link, atime: atime, mtime: mtime)

        // Target should still have original time.
        let targetMtime = try File.mtime(target)
        #expect(abs(targetMtime.timeIntervalSince1970 - originalTargetMtime.timeIntervalSince1970) < 1.0)

        // Symlink should have new time (check with lstat).
        let linkStat = try File.linkStatus(link)
        #expect(abs(linkStat.mtime.timeIntervalSince1970 - mtime.timeIntervalSince1970) < 1.0)
    }

    // MARK: - mkfifo Tests

    @Test func mkfifo() throws {
        let fifo = tempDir.appendingPathComponent("test.fifo")
        try File.mkfifo(fifo)

        #expect(File.isPipe(fifo))
        #expect(!File.isFile(fifo))
        #expect(!File.isDirectory(fifo))
    }

    @Test func mkfifoWithPermissions() throws {
        let fifo = tempDir.appendingPathComponent("test-perms.fifo")
        try File.mkfifo(fifo, permissions: 0o644)

        #expect(File.isPipe(fifo))

        let stat = try File.fileStatus(fifo)
        let perms = stat.mode & 0o777
        // Actual permissions may be affected by umask.
        #expect(perms <= 0o644)
    }

    @Test func mkfifoThrowsIfExists() throws {
        let file = tempDir.appendingPathComponent("existing.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) {
            try File.mkfifo(file)
        }

        #expect(File.isFile(file))
        #expect(!File.isPipe(file))
    }

    // MARK: - identical Tests

    @Test func identical() throws {
        #expect(try File.identical(sourceFile, sourceFile))
    }

    @Test func identicalForHardLink() throws {
        let hardLink = tempDir.appendingPathComponent("hardlink.txt")
        try File.link(source: sourceFile, destination: hardLink)

        // Hard links point to same inode.
        #expect(try File.identical(sourceFile, hardLink))
        #expect(try File.identical(hardLink, sourceFile))
    }

    @Test func identicalForSymlink() throws {
        let symlink = tempDir.appendingPathComponent("symlink.txt")
        try File.symlink(source: sourceFile, destination: symlink)

        // Symlink and target should be identical (stat follows symlinks).
        #expect(try File.identical(sourceFile, symlink))
        #expect(try File.identical(symlink, sourceFile))
    }

    @Test func identicalForDifferent() throws {
        let otherFile = tempDir.appendingPathComponent("other.txt")
        try "Other content".write(to: otherFile, atomically: true, encoding: .utf8)

        #expect(try !File.identical(sourceFile, otherFile))
        #expect(try !File.identical(otherFile, sourceFile))
    }

    @Test func identicalForSameContent() throws {
        let copyFile = tempDir.appendingPathComponent("copy.txt")
        try "Source content".write(to: copyFile, atomically: true, encoding: .utf8)

        // Files with same content but different inodes are not identical.
        #expect(try !File.identical(sourceFile, copyFile))
        #expect(try !File.identical(copyFile, sourceFile))
    }
}
