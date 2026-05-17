//
//  FileTypeTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import Foundation
import Testing

@Suite final class FileTypeTests {
    let tempDir: URL
    let testFile: URL
    let testDir: URL

    init() throws {
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FileTypeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        testFile = tempDir.appendingPathComponent("test.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        testDir = tempDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Existence Tests

    @Test func exists() {
        #expect(File.exists(testFile))
        #expect(File.exists(testDir))
        #expect(File.exists(tempDir))
    }

    @Test func existsForNonExistent() {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
        #expect(!File.exists(nonExistent))

        let nonExistentDir = tempDir.appendingPathComponent("no-such-dir")
        #expect(!File.exists(nonExistentDir))
    }

    @Test func existsForDirectory() {
        // File.exists returns true for directories (like Ruby)
        #expect(File.exists(tempDir))
        #expect(File.exists(testDir))

        // Also test system directories
        #expect(File.exists(URL(fileURLWithPath: "/tmp")))
        #expect(File.exists(URL(fileURLWithPath: "/")))
    }

    // MARK: - File Type Tests

    @Test func isFile() throws {
        #expect(File.isFile(testFile))

        let anotherFile = tempDir.appendingPathComponent("another.txt")
        try "content".write(to: anotherFile, atomically: true, encoding: .utf8)
        #expect(File.isFile(anotherFile))
    }

    @Test func isFileForDirectory() {
        #expect(!File.isFile(testDir))
        #expect(!File.isFile(tempDir))
        #expect(!File.isFile(URL(fileURLWithPath: "/")))

        let nonExistent = tempDir.appendingPathComponent("no-such-file.txt")
        #expect(!File.isFile(nonExistent))
    }

    @Test func isDirectory() {
        #expect(File.isDirectory(testDir))
        #expect(File.isDirectory(tempDir))
        #expect(File.isDirectory(URL(fileURLWithPath: "/")))
        #expect(File.isDirectory(URL(fileURLWithPath: "/tmp")))
    }

    @Test func isDirectoryForFile() {
        #expect(!File.isDirectory(testFile))

        let nonExistent = tempDir.appendingPathComponent("no-such-dir")
        #expect(!File.isDirectory(nonExistent))
    }

    @Test func isSymlink() throws {
        let symlinkURL = tempDir.appendingPathComponent("symlink.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: testFile)
        #expect(File.isSymlink(symlinkURL))

        let dirSymlinkURL = tempDir.appendingPathComponent("dirlink")
        try FileManager.default.createSymbolicLink(at: dirSymlinkURL, withDestinationURL: testDir)
        #expect(File.isSymlink(dirSymlinkURL))
    }

    @Test func isSymlinkForRegularFile() {
        #expect(!File.isSymlink(testFile))
        #expect(!File.isSymlink(testDir))

        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        #expect(!File.isSymlink(nonExistent))
    }

    @Test func isBlockDevice() {
        // Block devices are rare on macOS, but /dev/disk* exists.
        // This test might fail in sandboxed environments.
        if FileManager.default.fileExists(atPath: "/dev/disk0") {
            #expect(File.isBlockDevice(URL(fileURLWithPath: "/dev/disk0")))
        }

        #expect(!File.isBlockDevice(testFile))
        #expect(!File.isBlockDevice(testDir))
    }

    @Test func isCharDevice() {
        let devNull = URL(fileURLWithPath: "/dev/null")
        #expect(File.isCharDevice(devNull))

        let devRandom = URL(fileURLWithPath: "/dev/random")
        if FileManager.default.fileExists(atPath: devRandom.path) {
            #expect(File.isCharDevice(devRandom))
        }

        #expect(!File.isCharDevice(testFile))
        #expect(!File.isCharDevice(testDir))
    }

    @Test func isPipe() {
        // Creating FIFOs requires mkfifo; skip exercising real pipes here.
        #expect(!File.isPipe(testFile))
        #expect(!File.isPipe(testDir))
    }

    @Test func isSocket() {
        // Unix domain sockets are rare and hard to create in tests.
        #expect(!File.isSocket(testFile))
        #expect(!File.isSocket(testDir))
    }

    // MARK: - Empty/Zero Tests

    @Test func isEmpty() throws {
        let emptyFile = tempDir.appendingPathComponent("empty.txt")
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)
        #expect(try File.isEmpty(emptyFile))
    }

    @Test func isEmptyForNonEmpty() throws {
        #expect(try !File.isEmpty(testFile))

        let nonEmptyFile = tempDir.appendingPathComponent("nonempty.txt")
        try "Some content".write(to: nonEmptyFile, atomically: true, encoding: .utf8)
        #expect(try !File.isEmpty(nonEmptyFile))
    }

    @Test func isEmptyThrowsForNonExistent() {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
        #expect(throws: (any Error).self) {
            try File.isEmpty(nonExistent)
        }
    }

    @Test func isZero() throws {
        let emptyFile = tempDir.appendingPathComponent("zero.txt")
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)

        // isZero is alias for isEmpty
        #expect(try File.isZero(emptyFile))
        #expect(try !File.isZero(testFile))
    }

    // MARK: - ftype Tests

    @Test func ftypeForFile() throws {
        #expect(File.ftype(testFile) == .file)

        let anotherFile = tempDir.appendingPathComponent("another.dat")
        try Data().write(to: anotherFile)
        #expect(File.ftype(anotherFile) == .file)
    }

    @Test func ftypeForDirectory() {
        #expect(File.ftype(testDir) == .directory)
        #expect(File.ftype(tempDir) == .directory)
        #expect(File.ftype(URL(fileURLWithPath: "/")) == .directory)
    }

    @Test func ftypeForSymlink() throws {
        let symlinkURL = tempDir.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: testFile)
        #expect(File.ftype(symlinkURL) == .link)

        let dirSymlinkURL = tempDir.appendingPathComponent("dirlink")
        try FileManager.default.createSymbolicLink(at: dirSymlinkURL, withDestinationURL: testDir)
        #expect(File.ftype(dirSymlinkURL) == .link)
    }

    @Test func ftypeForCharDevice() {
        let devNull = URL(fileURLWithPath: "/dev/null")
        #expect(File.ftype(devNull) == .characterSpecial)
    }

    @Test func ftypeForBlockDevice() {
        if FileManager.default.fileExists(atPath: "/dev/disk0") {
            #expect(File.ftype(URL(fileURLWithPath: "/dev/disk0")) == .blockSpecial)
        }
    }

    @Test func ftypeForUnknown() {
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        #expect(File.ftype(nonExistent) == .unknown)
    }
}
