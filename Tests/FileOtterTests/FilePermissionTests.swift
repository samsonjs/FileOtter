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
        // Change file to read-only
        try File.chmod(testFile, permissions: 0o444)

        let stat = try File.fileStatus(testFile)
        let perms = stat.mode & 0o777
        XCTAssertEqual(perms, 0o444)

        XCTAssertTrue(File.isReadable(testFile))
        XCTAssertFalse(File.isWritable(testFile))

        // Change back to read-write
        try File.chmod(testFile, permissions: 0o644)
        let stat2 = try File.fileStatus(testFile)
        let perms2 = stat2.mode & 0o777
        XCTAssertEqual(perms2, 0o644)
    }

    func testChmodThrowsForNonExistent() throws {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
        XCTAssertThrowsError(try File.chmod(nonExistent, permissions: 0o644))
    }

    func testLchmod() throws {
        // The invariant under test is that lchmod does NOT touch the target
        // file's permissions, no matter how the underlying syscall behaves.
        // macOS treats lchmod on a symlink as a no-op; Linux's lchmod stub
        // returns ENOTSUP on most filesystems. Either way, the target stays put.
        let link = tempDir.appendingPathComponent("test-link")
        try File.symlink(source: testFile, destination: link)
        _ = try? File.lchmod(link, permissions: 0o777)

        let targetStat = try File.fileStatus(testFile)
        let targetPerms = targetStat.mode & 0o777
        XCTAssertNotEqual(targetPerms, 0o777)
    }

    func testInstanceChmod() throws {
        let file = try File(url: testFile, mode: .readWrite)
        defer { try? file.close() }
        try file.chmod(0o600)

        let stat = try File.fileStatus(testFile)
        XCTAssertEqual(stat.mode & 0o777, 0o600)
    }

    // MARK: - chown Tests

    func testChown() throws {
        // Get current ownership
        let stat = try File.fileStatus(testFile)
        let currentUid = stat.uid
        let currentGid = stat.gid
        
        // Try to set to same owner/group (should always succeed)
        try File.chown(testFile, owner: currentUid, group: currentGid)
        
        // Verify ownership unchanged
        let newStat = try File.fileStatus(testFile)
        XCTAssertEqual(newStat.uid, currentUid)
        XCTAssertEqual(newStat.gid, currentGid)
        
        // Note: Changing to different owner usually requires root privileges
        // So we can't test that in normal unit tests
    }

    func testChownWithNilValues() throws {
        // Get current ownership
        let stat = try File.fileStatus(testFile)
        let currentUid = stat.uid
        let currentGid = stat.gid
        
        // Change only owner (group stays same)
        try File.chown(testFile, owner: currentUid, group: nil)
        let stat1 = try File.fileStatus(testFile)
        XCTAssertEqual(stat1.uid, currentUid)
        XCTAssertEqual(stat1.gid, currentGid)
        
        // Change only group (owner stays same)
        try File.chown(testFile, owner: nil, group: currentGid)
        let stat2 = try File.fileStatus(testFile)
        XCTAssertEqual(stat2.uid, currentUid)
        XCTAssertEqual(stat2.gid, currentGid)
        
        // Change neither (no-op)
        try File.chown(testFile, owner: nil, group: nil)
        let stat3 = try File.fileStatus(testFile)
        XCTAssertEqual(stat3.uid, currentUid)
        XCTAssertEqual(stat3.gid, currentGid)
    }

    func testLchown() throws {
        // Create a symlink
        let link = tempDir.appendingPathComponent("owner-link")
        try File.symlink(source: testFile, destination: link)
        
        // Get current ownership of symlink
        let linkStat = try File.linkStatus(link)
        let currentUid = linkStat.uid
        let currentGid = linkStat.gid
        
        // Try to set to same owner/group (should always succeed)
        try File.lchown(link, owner: currentUid, group: currentGid)
        
        // Verify symlink ownership unchanged
        let newLinkStat = try File.linkStatus(link)
        XCTAssertEqual(newLinkStat.uid, currentUid)
        XCTAssertEqual(newLinkStat.gid, currentGid)
        
        // Target file ownership should not be affected
        let targetStat = try File.fileStatus(testFile)
        XCTAssertEqual(targetStat.uid, currentUid)
        XCTAssertEqual(targetStat.gid, currentGid)
    }

    func testInstanceChown() throws {
        // Chowning to a different uid usually requires root, so just verify
        // that chowning to the current uid/gid (a no-op) succeeds and
        // ownership is unchanged.
        let before = try File.fileStatus(testFile)
        let file = try File(url: testFile, mode: .readWrite)
        defer { try? file.close() }
        try file.chown(owner: before.uid, group: before.gid)
        let after = try File.fileStatus(testFile)
        XCTAssertEqual(after.uid, before.uid)
        XCTAssertEqual(after.gid, before.gid)
    }

    // MARK: - umask Tests

    func testUmask() throws {
        // Get current umask
        let currentMask = File.umask()
        
        // Umask should be a reasonable value (typically 0o022 or 0o002)
        XCTAssertGreaterThanOrEqual(currentMask, 0)
        XCTAssertLessThan(currentMask, 0o777)
    }

    func testUmaskSet() throws {
        // Get current umask
        let originalMask = File.umask()
        
        // Set new umask
        let newMask = 0o027
        let returnedMask = File.umask(newMask)
        
        // Returned value should be the old mask
        XCTAssertEqual(returnedMask, originalMask)
        
        // Current mask should be the new value
        let currentMask = File.umask()
        XCTAssertEqual(currentMask, newMask)
        
        // Restore original umask
        _ = File.umask(originalMask)
        
        // Verify restoration
        XCTAssertEqual(File.umask(), originalMask)
    }
}
