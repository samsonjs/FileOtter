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
        let url1 = URL(fileURLWithPath: "/Users/sjs/file.txt")
        XCTAssertEqual(File.basename(url1), "file.txt")
        
        let url2 = URL(fileURLWithPath: "/Users/sjs/dir/")
        XCTAssertEqual(File.basename(url2), "dir")
        
        let url3 = URL(fileURLWithPath: "/")
        XCTAssertEqual(File.basename(url3), "/")
        
        let url4 = URL(fileURLWithPath: "file.rb")
        XCTAssertEqual(File.basename(url4), "file.rb")
    }
    
    func testBasenameWithSuffix() throws {
        let url = URL(fileURLWithPath: "/Users/sjs/file.txt")
        XCTAssertEqual(File.basename(url, suffix: ".txt"), "file")
        XCTAssertEqual(File.basename(url, suffix: ".rb"), "file.txt")
        
        let url2 = URL(fileURLWithPath: "/Users/sjs/archive.tar.gz")
        XCTAssertEqual(File.basename(url2, suffix: ".gz"), "archive.tar")
        XCTAssertEqual(File.basename(url2, suffix: ".tar.gz"), "archive")
    }
    
    func testBasenameWithWildcardSuffix() throws {
        let url = URL(fileURLWithPath: "/Users/sjs/file.txt")
        XCTAssertEqual(File.basename(url, suffix: ".*"), "file")
        
        let url2 = URL(fileURLWithPath: "/Users/sjs/archive.tar.gz")
        XCTAssertEqual(File.basename(url2, suffix: ".*"), "archive.tar")
        
        let url3 = URL(fileURLWithPath: "/Users/sjs/noext")
        XCTAssertEqual(File.basename(url3, suffix: ".*"), "noext")
    }
    
    // MARK: - dirname Tests
    
    func testDirname() throws {
        let url1 = URL(fileURLWithPath: "/Users/sjs/file.txt")
        XCTAssertEqual(File.dirname(url1).path(), "/Users/sjs/")

        let url2 = URL(fileURLWithPath: "/Users/sjs/dir/")
        XCTAssertEqual(File.dirname(url2).path(), "/Users/sjs/")

        let url3 = URL(fileURLWithPath: "/file.txt")
        XCTAssertEqual(File.dirname(url3).path(), "/")

        let url4 = URL(fileURLWithPath: "file.txt")
        XCTAssertEqual(File.dirname(url4).path(), "./")
    }
    
    func testDirnameWithLevel() throws {
        let url = URL(fileURLWithPath: "/Users/sjs/dir/file.txt")
        XCTAssertEqual(File.dirname(url, level: 1).path(), "/Users/sjs/dir/")
        XCTAssertEqual(File.dirname(url, level: 2).path(), "/Users/sjs/")
        XCTAssertEqual(File.dirname(url, level: 3).path(), "/Users/")
        XCTAssertEqual(File.dirname(url, level: 4).path(), "/")
        XCTAssertEqual(File.dirname(url, level: 5).path(), "/")  // Can't go beyond root
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
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "/Users/sjs/.bashrc")), "")
        XCTAssertEqual(File.extname(URL(fileURLWithPath: "/Users/sjs/.config.bak")), ".bak")
    }
    
    // MARK: - split Tests
    
    func testSplit() throws {
        let (dir1, name1) = File.split(URL(fileURLWithPath: "/Users/sjs/file.txt"))
        XCTAssertEqual(dir1.path, "/Users/sjs")
        XCTAssertEqual(name1, "file.txt")
        
        let (dir2, name2) = File.split(URL(fileURLWithPath: "/file.txt"))
        XCTAssertEqual(dir2.path, "/")
        XCTAssertEqual(name2, "file.txt")
        
        let (dir3, name3) = File.split(URL(fileURLWithPath: "file.txt"))
        XCTAssertEqual(dir3.path(), "./")
        XCTAssertEqual(name3, "file.txt")
        
        let (dir4, name4) = File.split(URL(fileURLWithPath: "/Users/sjs/"))
        XCTAssertEqual(dir4.path, "/Users")
        XCTAssertEqual(name4, "sjs")
        
        // Root path edge case
        let (dir5, name5) = File.split(URL(fileURLWithPath: "/"))
        XCTAssertEqual(dir5.path, "/")
        XCTAssertEqual(name5, "")
    }
    
    // MARK: - join Tests
    
    func testJoin() throws {
        let u = URL(fileURLWithPath: "hello")
        XCTAssertEqual(File.join(u.path(), "world").path(), "hello/world")

        XCTAssertEqual(File.join("usr", "mail", "gumby").path(), "usr/mail/gumby")
        XCTAssertEqual(File.join("/usr", "mail", "gumby").path(), "/usr/mail/gumby")
        XCTAssertEqual(File.join("/", "usr", "bin").path(), "/usr/bin/")

        // Single component
        XCTAssertEqual(File.join("file.txt").path(), "file.txt")
        XCTAssertEqual(File.join("/file.txt").path(), "/file.txt")

        // Empty components are ignored
        XCTAssertEqual(File.join("usr", "", "bin").path(), "usr/bin")

        // Handles trailing slashes
        XCTAssertEqual(File.join("/usr/", "local/", "bin").path(), "/usr/local/bin/")
    }
    
    func testJoinWithArray() throws {
        let components = ["usr", "local", "bin"]
        XCTAssertEqual(File.join(components).path(), "usr/local/bin")

        let absoluteComponents = ["/usr", "local", "bin"]
        XCTAssertEqual(File.join(absoluteComponents).path(), "/usr/local/bin/")

        let singleComponent = ["file.txt"]
        XCTAssertEqual(File.join(singleComponent).path(), "file.txt")
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
