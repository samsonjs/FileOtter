//
//  FilePermissionTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import Foundation
import Testing

extension ProcessGlobalTests {
    @Suite final class FilePermissionTests {
        let tempDir: URL
        let testFile: URL
        let readOnlyFile: URL
        let executableFile: URL

        init() throws {
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

        deinit {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // MARK: - Basic Permission Tests

        @Test func isReadable() {
            // Normal files should be readable
            #expect(File.isReadable(testFile))

            // System files are generally readable
            #expect(File.isReadable(URL(fileURLWithPath: "/etc/hosts")))

            let nonExistent = tempDir.appendingPathComponent("nonexistent")
            #expect(!File.isReadable(nonExistent))
        }

        @Test func isWritable() {
            // Files we created should be writable
            #expect(File.isWritable(testFile))

            // System files are generally not writable
            #expect(!File.isWritable(URL(fileURLWithPath: "/etc/hosts")))

            let nonExistent = tempDir.appendingPathComponent("nonexistent")
            #expect(!File.isWritable(nonExistent))
        }

        @Test func isExecutable() throws {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executableFile.path,
            )
            #expect(File.isExecutable(executableFile))

            #expect(File.isExecutable(URL(fileURLWithPath: "/bin/ls")))
            #expect(File.isExecutable(URL(fileURLWithPath: "/usr/bin/swift")))
        }

        @Test func isExecutableForNonExecutable() {
            #expect(!File.isExecutable(testFile))
            #expect(!File.isExecutable(readOnlyFile))

            let nonExistent = tempDir.appendingPathComponent("nonexistent")
            #expect(!File.isExecutable(nonExistent))
        }

        // MARK: - Ownership Tests

        @Test func isOwned() {
            // Files we create should be owned by us
            #expect(File.isOwned(testFile))
            #expect(File.isOwned(readOnlyFile))
            #expect(File.isOwned(executableFile))
        }

        @Test func isGroupOwned() {
            // Files we create should be owned by our effective group
            #expect(File.isGroupOwned(testFile))
            #expect(File.isGroupOwned(readOnlyFile))
            #expect(File.isGroupOwned(executableFile))
        }

        // MARK: - World Permission Tests

        @Test func isWorldReadable() throws {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: testFile.path,
            )

            let perms = try #require(File.isWorldReadable(testFile))
            #expect(perms & 0o004 == 0o004) // Check world read bit
        }

        @Test func isWorldReadableForPrivate() throws {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o640],
                ofItemAtPath: readOnlyFile.path,
            )

            #expect(File.isWorldReadable(readOnlyFile) == nil)
        }

        @Test func isWorldWritable() throws {
            // Dangerous in practice — fine for a test fixture.
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o666],
                ofItemAtPath: testFile.path,
            )

            let perms = try #require(File.isWorldWritable(testFile))
            #expect(perms & 0o002 == 0o002) // Check world write bit
        }

        @Test func isWorldWritableForProtected() throws {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: readOnlyFile.path,
            )

            #expect(File.isWorldWritable(readOnlyFile) == nil)
        }

        // MARK: - Special Bit Tests

        @Test func isSetuid() {
            // Setuid is rarely used on regular files.
            #expect(!File.isSetuid(testFile))

            // /usr/bin/sudo typically has setuid (if it exists); just exercise the call.
            let sudo = URL(fileURLWithPath: "/usr/bin/sudo")
            if FileManager.default.fileExists(atPath: sudo.path) {
                _ = File.isSetuid(sudo)
            }
        }

        @Test func isSetgid() {
            #expect(!File.isSetgid(testFile))
        }

        @Test func isSticky() {
            let tmpDir = URL(fileURLWithPath: "/tmp")
            if FileManager.default.fileExists(atPath: tmpDir.path) {
                // /tmp usually has sticky bit; just exercise the call.
                _ = File.isSticky(tmpDir)
            }

            #expect(!File.isSticky(testFile))
        }

        // MARK: - chmod Tests

        @Test func chmod() throws {
            try File.chmod(testFile, permissions: 0o444)

            let stat = try File.fileStatus(testFile)
            let perms = stat.mode & 0o777
            #expect(perms == 0o444)

            #expect(File.isReadable(testFile))
            #expect(!File.isWritable(testFile))

            try File.chmod(testFile, permissions: 0o644)
            let stat2 = try File.fileStatus(testFile)
            let perms2 = stat2.mode & 0o777
            #expect(perms2 == 0o644)
        }

        @Test func chmodThrowsForNonExistent() {
            let nonExistent = tempDir.appendingPathComponent("does-not-exist.txt")
            #expect(throws: (any Error).self) {
                try File.chmod(nonExistent, permissions: 0o644)
            }
        }

        @Test func lchmod() throws {
            // The invariant under test is that lchmod does NOT touch the target
            // file's permissions, no matter how the underlying syscall behaves.
            // macOS treats lchmod on a symlink as a no-op; Linux's lchmod stub
            // returns ENOTSUP on most filesystems. Either way, the target stays put.
            let link = tempDir.appendingPathComponent("test-link")
            try File.symlink(source: testFile, destination: link)
            _ = try? File.lchmod(link, permissions: 0o777)

            let targetStat = try File.fileStatus(testFile)
            let targetPerms = targetStat.mode & 0o777
            #expect(targetPerms != 0o777)
        }

        @Test func instanceChmod() throws {
            let file = try File(url: testFile, mode: .readWrite)
            defer { try? file.close() }
            try file.chmod(0o600)

            let stat = try File.fileStatus(testFile)
            #expect(stat.mode & 0o777 == 0o600)
        }

        // MARK: - chown Tests

        @Test func chown() throws {
            let stat = try File.fileStatus(testFile)
            let currentUid = stat.uid
            let currentGid = stat.gid

            // Set to same owner/group should always succeed.
            try File.chown(testFile, owner: currentUid, group: currentGid)

            let newStat = try File.fileStatus(testFile)
            #expect(newStat.uid == currentUid)
            #expect(newStat.gid == currentGid)

            // Changing to different owner usually requires root, so untested here.
        }

        @Test func chownWithNilValues() throws {
            let stat = try File.fileStatus(testFile)
            let currentUid = stat.uid
            let currentGid = stat.gid

            // Change only owner (group stays same).
            try File.chown(testFile, owner: currentUid, group: nil)
            let stat1 = try File.fileStatus(testFile)
            #expect(stat1.uid == currentUid)
            #expect(stat1.gid == currentGid)

            // Change only group (owner stays same).
            try File.chown(testFile, owner: nil, group: currentGid)
            let stat2 = try File.fileStatus(testFile)
            #expect(stat2.uid == currentUid)
            #expect(stat2.gid == currentGid)

            // Change neither (no-op).
            try File.chown(testFile, owner: nil, group: nil)
            let stat3 = try File.fileStatus(testFile)
            #expect(stat3.uid == currentUid)
            #expect(stat3.gid == currentGid)
        }

        @Test func lchown() throws {
            let link = tempDir.appendingPathComponent("owner-link")
            try File.symlink(source: testFile, destination: link)

            let linkStat = try File.linkStatus(link)
            let currentUid = linkStat.uid
            let currentGid = linkStat.gid

            try File.lchown(link, owner: currentUid, group: currentGid)

            let newLinkStat = try File.linkStatus(link)
            #expect(newLinkStat.uid == currentUid)
            #expect(newLinkStat.gid == currentGid)

            // Target file ownership should not be affected.
            let targetStat = try File.fileStatus(testFile)
            #expect(targetStat.uid == currentUid)
            #expect(targetStat.gid == currentGid)
        }

        @Test func instanceChown() throws {
            // Chowning to a different uid usually requires root, so just verify
            // that chowning to the current uid/gid (a no-op) succeeds and
            // ownership is unchanged.
            let before = try File.fileStatus(testFile)
            let file = try File(url: testFile, mode: .readWrite)
            defer { try? file.close() }
            try file.chown(owner: before.uid, group: before.gid)
            let after = try File.fileStatus(testFile)
            #expect(after.uid == before.uid)
            #expect(after.gid == before.gid)
        }

        // MARK: - umask Tests

        @Test func umask() {
            let currentMask = File.umask()

            // Umask should be a reasonable value (typically 0o022 or 0o002).
            #expect(currentMask >= 0)
            #expect(currentMask < 0o777)
        }

        @Test func umaskSet() {
            let originalMask = File.umask()

            let newMask = 0o027
            let returnedMask = File.umask(newMask)

            // Returned value should be the old mask.
            #expect(returnedMask == originalMask)

            let currentMask = File.umask()
            #expect(currentMask == newMask)

            _ = File.umask(originalMask)

            #expect(File.umask() == originalMask)
        }
    }
}
