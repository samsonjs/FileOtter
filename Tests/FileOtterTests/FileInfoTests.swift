//
//  FileInfoTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import Foundation
import Testing

@Suite final class FileInfoTests {
    let tempDir: URL
    let testFile: URL

    init() throws {
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FileInfoTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        testFile = tempDir.appendingPathComponent("test.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
    }

    deinit {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Time-based Tests

    @Test func atime() throws {
        let atime = try File.atime(testFile)
        // Access time should be recent (within last hour).
        #expect(Date().timeIntervalSince(atime) < 3600)
    }

    @Test func mtime() throws {
        let initialMtime = try File.mtime(testFile)

        Thread.sleep(forTimeInterval: 0.1)
        try "Modified content".write(to: testFile, atomically: true, encoding: .utf8)

        let newMtime = try File.mtime(testFile)
        #expect(newMtime > initialMtime)
    }

    @Test func ctime() throws {
        let ctime = try File.ctime(testFile)
        #expect(Date().timeIntervalSince(ctime) < 3600)
    }

    @Test func birthtime() throws {
        let newFile = tempDir.appendingPathComponent("birthtime-test.txt")
        let beforeCreation = Date()
        Thread.sleep(forTimeInterval: 0.01)
        try "content".write(to: newFile, atomically: true, encoding: .utf8)
        Thread.sleep(forTimeInterval: 0.01)
        let afterCreation = Date()

        let birthtime = try File.birthtime(newFile)
        #expect(birthtime >= beforeCreation)
        #expect(birthtime <= afterCreation)
    }

    // MARK: - Size Tests

    @Test func size() throws {
        let content = "Test content"
        let expectedSize = content.data(using: .utf8)!.count
        #expect(try File.size(testFile) == expectedSize)

        let largeFile = tempDir.appendingPathComponent("large.txt")
        let largeContent = String(repeating: "Hello World! ", count: 100)
        try largeContent.write(to: largeFile, atomically: true, encoding: .utf8)
        let largeExpectedSize = largeContent.data(using: .utf8)!.count
        #expect(try File.size(largeFile) == largeExpectedSize)
    }

    @Test func sizeThrowsForNonExistent() {
        let nonExistent = tempDir.appendingPathComponent("no-such-file.txt")
        #expect(throws: (any Error).self) {
            try File.size(nonExistent)
        }
    }

    @Test func sizeForEmptyFile() throws {
        let emptyFile = tempDir.appendingPathComponent("empty.txt")
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)
        #expect(try File.size(emptyFile) == 0)
    }

    // MARK: - Stat Tests

    @Test func stat() throws {
        let stat = try File.fileStatus(testFile)

        #expect(stat.ino > 0)
        #expect(stat.uid > 0)
        #expect(stat.gid > 0)
        #expect(stat.size == 12)

        #expect(Date().timeIntervalSince(stat.mtime) < 3600)
        #expect(Date().timeIntervalSince(stat.atime) < 3600)
        // birthtime is only exposed in Darwin's stat; Linux requires statx(2).
        #if canImport(Darwin)
        #expect(stat.birthtime != nil)
        #endif
    }

    @Test func statThrowsForNonExistent() {
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        #expect(throws: (any Error).self) {
            try File.fileStatus(nonExistent)
        }
    }

    @Test func lstat() throws {
        // For regular files, lstat should be same as stat.
        let lstat = try File.linkStatus(testFile)
        let stat = try File.fileStatus(testFile)

        #expect(lstat.size == stat.size)
        #expect(lstat.ino == stat.ino)
        #expect(lstat.mode == stat.mode)
    }

    @Test func lstatForSymlink() throws {
        let targetFile = tempDir.appendingPathComponent("target.txt")
        let targetContent = "This is the target file content"
        try targetContent.write(to: targetFile, atomically: true, encoding: .utf8)

        let symlinkURL = tempDir.appendingPathComponent("symlink.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: targetFile)

        let lstat = try File.linkStatus(symlinkURL)
        let stat = try File.fileStatus(symlinkURL)

        // lstat returns the symlink's own stats; stat follows it to the target.
        #expect(lstat.size != stat.size)
        #expect(stat.size == Int64(targetContent.data(using: .utf8)!.count))

        let isLink = (lstat.mode & 0o170000) == 0o120000 // S_IFLNK
        #expect(isLink)
    }

    // MARK: - Instance Method Tests

    @Test func instanceAtime() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        #expect(Date().timeIntervalSince(file.atime) < 3600)
    }

    @Test func instanceMtime() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        let viaInstance = file.mtime
        let viaStatic = try File.mtime(testFile)
        // Same file, same mtime (within sub-second precision).
        #expect(abs(viaInstance.timeIntervalSince1970 - viaStatic.timeIntervalSince1970) < 1.0)
    }

    @Test func instanceCtime() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        #expect(Date().timeIntervalSince(file.ctime) < 3600)
    }

    @Test func instanceBirthtime() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        // birthtime is Date? — Darwin returns a value; Linux returns nil
        // because the kernel only exposes creation time via statx(2).
        #if canImport(Darwin)
        let viaInstance = try #require(file.birthtime)
        let viaStatic = try File.birthtime(testFile)
        #expect(abs(viaInstance.timeIntervalSince1970 - viaStatic.timeIntervalSince1970) < 1.0)
        #else
        #expect(file.birthtime == nil)
        #endif
    }

    @Test func instanceSize() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        #expect(file.size == "Test content".utf8.count)
    }

    @Test func instanceStat() throws {
        let file = try File(url: testFile, mode: .read)
        defer { try? file.close() }
        let stat = try file.fileStat()
        #expect(stat.size == 12)
        #expect(stat.ino > 0)
    }

    @Test func instanceLstat() throws {
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
        #expect(viaLstat.size != viaStat.size)
        let isLink = (viaLstat.mode & 0o170000) == 0o120000 // S_IFLNK
        #expect(isLink)
    }

    // MARK: - FileStat Tests

    @Test func fileStatProperties() throws {
        let stat = try File.fileStatus(testFile)
        // Every field should be populated with something sensible.
        #expect(stat.ino > 0)
        #expect(stat.nlink > 0)
        #expect(stat.uid >= 0)
        #expect(stat.gid >= 0)
        #expect(stat.size == 12)
        #expect(stat.blksize > 0)
        #expect(stat.blocks >= 0)
        // Mode contains both type bits and permission bits.
        let isRegularFile = (stat.mode & 0o170000) == 0o100000
        #expect(isRegularFile)
        // Times should be recent.
        #expect(Date().timeIntervalSince(stat.atime) < 3600)
        #expect(Date().timeIntervalSince(stat.mtime) < 3600)
        #expect(Date().timeIntervalSince(stat.ctime) < 3600)
    }

    @Test func fileStatForDirectory() throws {
        let stat = try File.fileStatus(tempDir)
        let isDirectory = (stat.mode & 0o170000) == 0o040000
        #expect(isDirectory)
    }

    @Test func fileStatForSymlink() throws {
        let target = tempDir.appendingPathComponent("target2.txt")
        try "x".write(to: target, atomically: true, encoding: .utf8)
        let link = tempDir.appendingPathComponent("link2.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        // fileStatus follows the symlink; linkStatus inspects the link itself.
        let followed = try File.fileStatus(link)
        let linkOnly = try File.linkStatus(link)
        let followedIsRegular = (followed.mode & 0o170000) == 0o100000
        let linkIsSymlink = (linkOnly.mode & 0o170000) == 0o120000
        #expect(followedIsRegular)
        #expect(linkIsSymlink)
    }
}
