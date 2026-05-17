//
//  FileFnmatchTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import Testing

@Suite struct FileFnmatchTests {
    // MARK: - Basic Pattern Tests

    @Test func exactMatch() {
        #expect(File.fnmatch(pattern: "cat", path: "cat"))
        #expect(!File.fnmatch(pattern: "cat", path: "dog"))
    }

    @Test func partialMatch() {
        // Must match entire string
        #expect(!File.fnmatch(pattern: "cat", path: "category"))
        #expect(!File.fnmatch(pattern: "cat", path: "bobcat"))
    }

    // MARK: - Wildcard Tests

    @Test func starWildcard() {
        #expect(File.fnmatch(pattern: "c*", path: "cats"))
        #expect(File.fnmatch(pattern: "c*t", path: "cat"))
        #expect(File.fnmatch(pattern: "c*t", path: "coat"))
        #expect(File.fnmatch(pattern: "*at", path: "cat"))
        #expect(File.fnmatch(pattern: "*at", path: "bat"))
        #expect(!File.fnmatch(pattern: "c*t", path: "dog"))

        // Without pathname flag, * matches /
        #expect(File.fnmatch(pattern: "c*t", path: "c/a/b/t"))
    }

    @Test func questionMarkWildcard() {
        #expect(File.fnmatch(pattern: "c?t", path: "cat"))
        #expect(File.fnmatch(pattern: "c?t", path: "cot"))
        #expect(!File.fnmatch(pattern: "c??t", path: "cat"))
        #expect(File.fnmatch(pattern: "c??t", path: "coat"))

        // ? doesn't match / with pathname flag
        #expect(!File.fnmatch(pattern: "c?t", path: "c/t", flags: .pathname))
    }

    // MARK: - Character Set Tests

    @Test func characterSet() {
        #expect(File.fnmatch(pattern: "ca[a-z]", path: "cat"))
        #expect(!File.fnmatch(pattern: "ca[0-9]", path: "cat"))
        #expect(File.fnmatch(pattern: "ca[0-9]", path: "ca5"))
        #expect(File.fnmatch(pattern: "[abc]at", path: "cat"))
        #expect(File.fnmatch(pattern: "[abc]at", path: "bat"))
        #expect(!File.fnmatch(pattern: "[abc]at", path: "rat"))
    }

    @Test func negatedCharacterSet() {
        #expect(!File.fnmatch(pattern: "ca[^t]", path: "cat"))
        #expect(File.fnmatch(pattern: "ca[^t]", path: "cab"))
        #expect(File.fnmatch(pattern: "ca[^t]", path: "can"))
        #expect(!File.fnmatch(pattern: "ca[^bcd]", path: "cab"))
        #expect(File.fnmatch(pattern: "ca[^bcd]", path: "cat"))
    }

    // MARK: - Escape Tests

    @Test func escapedWildcard() {
        // With noescape flag, backslash is literal
        #expect(File.fnmatch(pattern: "\\*", path: "\\*", flags: .noescape))
        #expect(File.fnmatch(pattern: "\\?", path: "\\?", flags: .noescape))

        // Without noescape, backslash escapes the wildcard
        #expect(File.fnmatch(pattern: "\\*", path: "*"))
        #expect(File.fnmatch(pattern: "\\?", path: "?"))
        #expect(!File.fnmatch(pattern: "\\*", path: "anything"))
    }

    @Test func escapeInBrackets() {
        #expect(File.fnmatch(pattern: "[\\?]", path: "?"))
        #expect(File.fnmatch(pattern: "[\\*]", path: "*"))
        #expect(!File.fnmatch(pattern: "[\\?]", path: "a"))
    }

    // MARK: - Flag Tests

    @Test func caseFoldFlag() {
        #expect(!File.fnmatch(pattern: "cat", path: "CAT", flags: []))
        #expect(File.fnmatch(pattern: "cat", path: "CAT", flags: .casefold))
        #expect(File.fnmatch(pattern: "CaT", path: "cat", flags: .casefold))
    }

    @Test func pathnameFlag() {
        // Without pathname flag, * matches /
        #expect(File.fnmatch(pattern: "*", path: "a/b", flags: []))

        // With pathname flag, * doesn't match /
        #expect(!File.fnmatch(pattern: "*", path: "a/b", flags: .pathname))
        #expect(File.fnmatch(pattern: "a/*", path: "a/b", flags: .pathname))

        // ? also doesn't match / with pathname flag
        #expect(!File.fnmatch(pattern: "?", path: "/", flags: .pathname))
    }

    @Test func periodFlag() {
        // By default, * doesn't match leading period (FNM_PERIOD is set)
        #expect(!File.fnmatch(pattern: "*", path: ".profile", flags: .period))
        #expect(File.fnmatch(pattern: ".*", path: ".profile", flags: .period))

        // Without period flag, * can match leading period
        #expect(File.fnmatch(pattern: "*", path: ".profile", flags: []))
    }

    @Test func noescapeFlag() {
        // Without noescape, backslash escapes
        #expect(File.fnmatch(pattern: "\\a", path: "a", flags: []))
        #expect(!File.fnmatch(pattern: "\\a", path: "\\a", flags: []))

        // With noescape, backslash is literal
        #expect(!File.fnmatch(pattern: "\\a", path: "a", flags: .noescape))
        #expect(File.fnmatch(pattern: "\\a", path: "\\a", flags: .noescape))
    }

    @Test func leadingDirFlag() {
        // FNM_LEADING_DIR allows pattern to match a leading portion
        #expect(File.fnmatch(pattern: "*/foo", path: "bar/foo/baz", flags: .leadingDir))
        #expect(File.fnmatch(pattern: "bar/foo", path: "bar/foo/baz", flags: .leadingDir))
        #expect(!File.fnmatch(pattern: "bar/foo", path: "bar/foo/baz", flags: []))
    }

    // MARK: - Complex Pattern Tests

    @Test func complexGlobPatterns() {
        // Test various complex patterns
        #expect(File.fnmatch(pattern: "*.txt", path: "file.txt"))
        #expect(!File.fnmatch(pattern: "*.txt", path: "file.md"))

        // Multiple wildcards
        #expect(File.fnmatch(pattern: "*.*", path: "file.txt"))
        #expect(File.fnmatch(pattern: "test_*.rb", path: "test_file.rb"))
        #expect(!File.fnmatch(pattern: "test_*.rb", path: "spec_file.rb"))
    }

    @Test func hiddenFileMatching() {
        // Without special flags, * matches everything including paths with /
        #expect(File.fnmatch(pattern: "*", path: "dave/.profile", flags: []))

        // With pathname flag, we need to be more specific
        #expect(!File.fnmatch(pattern: "*", path: "dave/.profile", flags: .pathname))
        #expect(File.fnmatch(pattern: "dave/*", path: "dave/.profile", flags: .pathname))
        #expect(File.fnmatch(pattern: "dave/.*", path: "dave/.profile", flags: .pathname))

        // Hidden files in current directory
        #expect(!File.fnmatch(pattern: "*", path: ".hidden", flags: .period))
        #expect(File.fnmatch(pattern: ".*", path: ".hidden", flags: .period))
    }
}
