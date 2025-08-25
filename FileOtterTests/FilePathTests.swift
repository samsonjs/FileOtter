//
//  FilePathTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import XCTest

final class FilePathTests: XCTestCase {
    var tempDir: URL!
    
    override func setUpWithError() throws {
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FilePathTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }
    
    // MARK: - basename Tests
    
    func testBasename() throws {
        let url1 = URL(fileURLWithPath: "/home/user/file.txt")
        XCTAssertEqual(File.basename(url1), "file.txt")
        
        let url2 = URL(fileURLWithPath: "/home/user/dir/")
        XCTAssertEqual(File.basename(url2), "dir")
        
        let url3 = URL(fileURLWithPath: "/")
        XCTAssertEqual(File.basename(url3), "/")
        
        let url4 = URL(fileURLWithPath: "file.rb")
        XCTAssertEqual(File.basename(url4), "file.rb")
    }
    
    func testBasenameWithSuffix() throws {
        let url = URL(fileURLWithPath: "/home/user/file.txt")
        XCTAssertEqual(File.basename(url, suffix: ".txt"), "file")
        XCTAssertEqual(File.basename(url, suffix: ".rb"), "file.txt")
        
        let url2 = URL(fileURLWithPath: "/home/user/archive.tar.gz")
        XCTAssertEqual(File.basename(url2, suffix: ".gz"), "archive.tar")
        XCTAssertEqual(File.basename(url2, suffix: ".tar.gz"), "archive")
    }
    
    func testBasenameWithWildcardSuffix() throws {
        let url = URL(fileURLWithPath: "/home/user/file.txt")
        XCTAssertEqual(File.basename(url, suffix: ".*"), "file")
        
        let url2 = URL(fileURLWithPath: "/home/user/archive.tar.gz")
        XCTAssertEqual(File.basename(url2, suffix: ".*"), "archive.tar")
        
        let url3 = URL(fileURLWithPath: "/home/user/noext")
        XCTAssertEqual(File.basename(url3, suffix: ".*"), "noext")
    }
    
    // MARK: - dirname Tests
    
    func testDirname() throws {
        let url1 = URL(fileURLWithPath: "/home/user/file.txt")
        XCTAssertEqual(File.dirname(url1).path, "/home/user")
        
        let url2 = URL(fileURLWithPath: "/home/user/dir/")
        XCTAssertEqual(File.dirname(url2).path, "/home/user")
        
        let url3 = URL(fileURLWithPath: "/file.txt")
        XCTAssertEqual(File.dirname(url3).path, "/")
        
        let url4 = URL(fileURLWithPath: "file.txt")
        XCTAssertEqual(File.dirname(url4).path, ".")
    }
    
    func testDirnameWithLevel() throws {
        let url = URL(fileURLWithPath: "/home/user/dir/file.txt")
        XCTAssertEqual(File.dirname(url, level: 1).path, "/home/user/dir")
        XCTAssertEqual(File.dirname(url, level: 2).path, "/home/user")
        XCTAssertEqual(File.dirname(url, level: 3).path, "/home")
        XCTAssertEqual(File.dirname(url, level: 4).path, "/")
        XCTAssertEqual(File.dirname(url, level: 5).path, "/")  // Can't go beyond root
    }
    
    // MARK: - extname Tests
    
    func testExtname() throws {
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "test.rb")), ".rb")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "a/b/d/test.rb")), ".rb")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: ".a/b/d/test.rb")), ".rb")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "test")), "")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "test.tar.gz")), ".gz")
    }
    
    func testExtnameWithDotfile() throws {
        XCTAssertEqual(File.extname(URL(fileURLWithPath: ".profile")), "")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: ".profile.sh")), ".sh")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "/home/user/.bashrc")), "")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "/home/user/.config.bak")), ".bak")
    }
    
    // MARK: - split Tests
    
    func testSplit() throws {
        // TODO: Implement
        // File.split("/home/user/file.txt") => ("/home/user", "file.txt")
    }
    
    // MARK: - join Tests
    
    func testJoin() throws {
        // TODO: Implement
        // File.join("usr", "mail", "gumby") => "usr/mail/gumby"
    }
    
    func testJoinWithArray() throws {
        // TODO: Implement
    }
    
    // MARK: - absolutePath Tests
    
    func testAbsolutePath() throws {
        // TODO: Implement
        // Converts relative to absolute
    }
    
    func testAbsolutePathWithBase() throws {
        // TODO: Implement
    }
    
    // MARK: - expandPath Tests
    
    func testExpandPath() throws {
        // TODO: Implement
        // File.expandPath("~") => home directory
        // File.expandPath("~/Documents") => home/Documents
    }
    
    func testExpandPathWithRelative() throws {
        // TODO: Implement
    }
    
    // MARK: - realpath Tests
    
    func testRealpath() throws {
        // TODO: Implement
        // Resolves symlinks, all components must exist
    }
    
    func testRealpathThrowsForNonExistent() throws {
        // TODO: Implement
    }
    
    // MARK: - realdirpath Tests
    
    func testRealdirpath() throws {
        // TODO: Implement
        // Resolves symlinks, last component may not exist
    }
    
    func testRealdirpathWithNonExistentLast() throws {
        // TODO: Implement
    }
}