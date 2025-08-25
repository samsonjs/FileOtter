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
        // TODO: Implement
        // Create symlink and test File.isSymlink(url)
    }
    
    func testIsSymlinkForRegularFile() throws {
        // TODO: Implement
        // File.isSymlink(url) returns false for regular files
    }
    
    func testIsBlockDevice() throws {
        // TODO: Implement
        // File.isBlockDevice(url) - may need special test file
    }
    
    func testIsCharDevice() throws {
        // TODO: Implement
        // File.isCharDevice(url) - test with /dev/null or similar
    }
    
    func testIsPipe() throws {
        // TODO: Implement
        // File.isPipe(url) - create FIFO and test
    }
    
    func testIsSocket() throws {
        // TODO: Implement
        // File.isSocket(url) - create socket and test
    }
    
    // MARK: - Empty/Zero Tests
    
    func testIsEmpty() throws {
        // TODO: Implement
        // File.isEmpty(url) returns true for empty file
    }
    
    func testIsEmptyForNonEmpty() throws {
        // TODO: Implement
        // File.isEmpty(url) returns false for non-empty file
    }
    
    func testIsEmptyThrowsForNonExistent() throws {
        // TODO: Implement
    }
    
    func testIsZero() throws {
        // TODO: Implement
        // File.isZero(url) is alias for isEmpty
    }
    
    // MARK: - ftype Tests
    
    func testFtypeForFile() throws {
        // TODO: Implement
        // File.ftype(url) returns .file
    }
    
    func testFtypeForDirectory() throws {
        // TODO: Implement
        // File.ftype(url) returns .directory
    }
    
    func testFtypeForSymlink() throws {
        // TODO: Implement
        // File.ftype(url) returns .link
    }
    
    func testFtypeForCharDevice() throws {
        // TODO: Implement
        // File.ftype(url) returns .characterSpecial
    }
    
    func testFtypeForBlockDevice() throws {
        // TODO: Implement
        // File.ftype(url) returns .blockSpecial
    }
    
    func testFtypeForFifo() throws {
        // TODO: Implement
        // File.ftype(url) returns .fifo
    }
    
    func testFtypeForSocket() throws {
        // TODO: Implement
        // File.ftype(url) returns .socket
    }
    
    func testFtypeForUnknown() throws {
        // TODO: Implement
        // File.ftype(url) returns .unknown for unrecognized types
    }
}