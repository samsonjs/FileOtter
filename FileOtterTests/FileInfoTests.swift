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
        // TODO: Implement
        // File.atime(url) returns last access time
    }
    
    func testMtime() throws {
        // TODO: Implement
        // File.mtime(url) returns last modification time
    }
    
    func testCtime() throws {
        // TODO: Implement
        // File.ctime(url) returns last status change time
    }
    
    func testBirthtime() throws {
        // TODO: Implement
        // File.birthtime(url) returns creation time
    }
    
    func testBirthtimeThrowsOnUnsupportedPlatform() throws {
        // TODO: Implement if platform doesn't support birthtime
    }
    
    // MARK: - Size Tests
    
    func testSize() throws {
        // TODO: Implement
        // File.size(url) returns file size in bytes
    }
    
    func testSizeThrowsForNonExistent() throws {
        // TODO: Implement
    }
    
    func testSizeForEmptyFile() throws {
        // TODO: Implement
    }
    
    // MARK: - Stat Tests
    
    func testStat() throws {
        // TODO: Implement
        // File.stat(url) returns FileStat object
    }
    
    func testStatThrowsForNonExistent() throws {
        // TODO: Implement
    }
    
    func testLstat() throws {
        // TODO: Implement
        // File.lstat(url) doesn't follow symlinks
    }
    
    func testLstatForSymlink() throws {
        // TODO: Implement
        // Create symlink and verify lstat returns symlink stats, not target
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