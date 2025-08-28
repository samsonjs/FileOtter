//
//  FilePermissionTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import XCTest

final class FilePermissionTests: XCTestCase {
    var tempDir: URL!
    var testFile: URL!
    var readOnlyFile: URL!
    var executableFile: URL!

    override func setUpWithError() throws {
        tempDir = URL.temporaryDirectory
            .appendingPathComponent("FilePermissionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        testFile = tempDir.appendingPathComponent("test.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        readOnlyFile = tempDir.appendingPathComponent("readonly.txt")
        try "Read only".write(to: readOnlyFile, atomically: true, encoding: .utf8)

        executableFile = tempDir.appendingPathComponent("script.sh")
        try "#!/bin/sh\necho hello".write(to: executableFile, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Basic Permission Tests

    func testIsReadable() throws {
        // Normal files should be readable
        XCTAssertTrue(File.isReadable(testFile))

        // System files are generally readable
        XCTAssertTrue(File.isReadable(URL(fileURLWithPath: "/etc/hosts")))

        // Non-existent files are not readable
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        XCTAssertFalse(File.isReadable(nonExistent))
    }

    func testIsWritable() throws {
        // Files we created should be writable
        XCTAssertTrue(File.isWritable(testFile))

        // System files are generally not writable
        XCTAssertFalse(File.isWritable(URL(fileURLWithPath: "/etc/hosts")))

        // Non-existent files are not writable
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        XCTAssertFalse(File.isWritable(nonExistent))
    }

    func testIsExecutable() throws {
        // Make the script executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableFile.path,
        )
        XCTAssertTrue(File.isExecutable(executableFile))

        // System executables
        XCTAssertTrue(File.isExecutable(URL(fileURLWithPath: "/bin/ls")))
        XCTAssertTrue(File.isExecutable(URL(fileURLWithPath: "/usr/bin/swift")))
    }

    func testIsExecutableForNonExecutable() throws {
        // Regular text files are not executable
        XCTAssertFalse(File.isExecutable(testFile))
        XCTAssertFalse(File.isExecutable(readOnlyFile))

        // Non-existent files are not executable
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        XCTAssertFalse(File.isExecutable(nonExistent))
    }

    // MARK: - Ownership Tests

    func testIsOwned() throws {
        // Files we create should be owned by us
        XCTAssertTrue(File.isOwned(testFile))
        XCTAssertTrue(File.isOwned(readOnlyFile))
        XCTAssertTrue(File.isOwned(executableFile))

        // System files may not be owned by us
        // This depends on the user running the test
    }

    func testIsGroupOwned() throws {
        // Files we create should be owned by our effective group
        XCTAssertTrue(File.isGroupOwned(testFile))
        XCTAssertTrue(File.isGroupOwned(readOnlyFile))
        XCTAssertTrue(File.isGroupOwned(executableFile))
    }

    // MARK: - World Permission Tests

    func testIsWorldReadable() throws {
        // Make file world readable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: testFile.path,
        )

        let perms = File.isWorldReadable(testFile)
        XCTAssertNotNil(perms)
        if let perms {
            XCTAssertEqual(perms & 0o004, 0o004) // Check world read bit
        }
    }

    func testIsWorldReadableForPrivate() throws {
        // Make file not world readable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o640],
            ofItemAtPath: readOnlyFile.path,
        )

        XCTAssertNil(File.isWorldReadable(readOnlyFile))
    }

    func testIsWorldWritable() throws {
        // Make file world writable (dangerous in practice!)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o666],
            ofItemAtPath: testFile.path,
        )

        let perms = File.isWorldWritable(testFile)
        XCTAssertNotNil(perms)
        if let perms {
            XCTAssertEqual(perms & 0o002, 0o002) // Check world write bit
        }
    }

    func testIsWorldWritableForProtected() throws {
        // Make file not world writable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: readOnlyFile.path,
        )

        XCTAssertNil(File.isWorldWritable(readOnlyFile))
    }

    // MARK: - Special Bit Tests

    func testIsSetuid() throws {
        // Setuid is rarely used on regular files
        // Most files should not have setuid
        XCTAssertFalse(File.isSetuid(testFile))

        // /usr/bin/sudo typically has setuid (if it exists)
        let sudo = URL(fileURLWithPath: "/usr/bin/sudo")
        if FileManager.default.fileExists(atPath: sudo.path) {
            // This might be true on some systems
            _ = File.isSetuid(sudo)
        }
    }

    func testIsSetgid() throws {
        // Setgid is rarely used on regular files
        XCTAssertFalse(File.isSetgid(testFile))
    }

    func testIsSticky() throws {
        // Sticky bit is typically set on /tmp
        let tmpDir = URL(fileURLWithPath: "/tmp")
        if FileManager.default.fileExists(atPath: tmpDir.path) {
            // /tmp usually has sticky bit
            _ = File.isSticky(tmpDir)
        }

        // Regular files should not have sticky bit
        XCTAssertFalse(File.isSticky(testFile))
    }

    // MARK: - chmod Tests

    func testChmod() throws {
        // TODO: Implement
        // File.chmod(url, permissions) changes file permissions
    }

    func testChmodThrowsForNonExistent() throws {
        // TODO: Implement
    }

    func testLchmod() throws {
        // TODO: Implement
        // File.lchmod(url, permissions) changes symlink permissions
    }

    func testInstanceChmod() throws {
        // TODO: Implement
        // file.chmod(permissions) changes open file permissions
    }

    // MARK: - chown Tests

    func testChown() throws {
        // TODO: Implement
        // File.chown(url, owner, group) changes ownership
        // Note: May require special privileges
    }

    func testChownWithNilValues() throws {
        // TODO: Implement
        // nil owner or group means don't change that value
    }

    func testLchown() throws {
        // TODO: Implement
        // File.lchown(url, owner, group) changes symlink ownership
    }

    func testInstanceChown() throws {
        // TODO: Implement
        // file.chown(owner, group) changes open file ownership
    }

    // MARK: - umask Tests

    func testUmask() throws {
        // TODO: Implement
        // File.umask() returns current umask
    }

    func testUmaskSet() throws {
        // TODO: Implement
        // File.umask(mask) sets umask and returns previous value
    }
}
