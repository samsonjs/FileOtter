//
//  FileFnmatchTests.swift
//  FileOtterTests
//
//  Created by Sami Samhuri on 2025-08-19.
//

@testable import FileOtter
import XCTest

final class FileFnmatchTests: XCTestCase {
    // MARK: - Basic Pattern Tests

    func testExactMatch() throws {
        XCTAssertTrue(File.fnmatch(pattern: "cat", path: "cat"))
        XCTAssertFalse(File.fnmatch(pattern: "cat", path: "dog"))
    }

    func testPartialMatch() throws {
        // Must match entire string
        XCTAssertFalse(File.fnmatch(pattern: "cat", path: "category"))
        XCTAssertFalse(File.fnmatch(pattern: "cat", path: "bobcat"))
    }

    // MARK: - Wildcard Tests

    func testStarWildcard() throws {
        XCTAssertTrue(File.fnmatch(pattern: "c*", path: "cats"))
        XCTAssertTrue(File.fnmatch(pattern: "c*t", path: "cat"))
        XCTAssertTrue(File.fnmatch(pattern: "c*t", path: "coat"))
        XCTAssertTrue(File.fnmatch(pattern: "*at", path: "cat"))
        XCTAssertTrue(File.fnmatch(pattern: "*at", path: "bat"))
        XCTAssertFalse(File.fnmatch(pattern: "c*t", path: "dog"))
        
        // Without pathname flag, * matches /
        XCTAssertTrue(File.fnmatch(pattern: "c*t", path: "c/a/b/t"))
    }

    func testQuestionMarkWildcard() throws {
        XCTAssertTrue(File.fnmatch(pattern: "c?t", path: "cat"))
        XCTAssertTrue(File.fnmatch(pattern: "c?t", path: "cot"))
        XCTAssertFalse(File.fnmatch(pattern: "c??t", path: "cat"))
        XCTAssertTrue(File.fnmatch(pattern: "c??t", path: "coat"))
        
        // ? doesn't match / with pathname flag
        XCTAssertFalse(File.fnmatch(pattern: "c?t", path: "c/t", flags: .pathname))
    }

    // MARK: - Character Set Tests

    func testCharacterSet() throws {
        XCTAssertTrue(File.fnmatch(pattern: "ca[a-z]", path: "cat"))
        XCTAssertFalse(File.fnmatch(pattern: "ca[0-9]", path: "cat"))
        XCTAssertTrue(File.fnmatch(pattern: "ca[0-9]", path: "ca5"))
        XCTAssertTrue(File.fnmatch(pattern: "[abc]at", path: "cat"))
        XCTAssertTrue(File.fnmatch(pattern: "[abc]at", path: "bat"))
        XCTAssertFalse(File.fnmatch(pattern: "[abc]at", path: "rat"))
    }

    func testNegatedCharacterSet() throws {
        XCTAssertFalse(File.fnmatch(pattern: "ca[^t]", path: "cat"))
        XCTAssertTrue(File.fnmatch(pattern: "ca[^t]", path: "cab"))
        XCTAssertTrue(File.fnmatch(pattern: "ca[^t]", path: "can"))
        XCTAssertFalse(File.fnmatch(pattern: "ca[^bcd]", path: "cab"))
        XCTAssertTrue(File.fnmatch(pattern: "ca[^bcd]", path: "cat"))
    }

    // MARK: - Escape Tests

    func testEscapedWildcard() throws {
        // With noescape flag, backslash is literal
        XCTAssertTrue(File.fnmatch(pattern: "\\*", path: "\\*", flags: .noescape))
        XCTAssertTrue(File.fnmatch(pattern: "\\?", path: "\\?", flags: .noescape))
        
        // Without noescape, backslash escapes the wildcard
        XCTAssertTrue(File.fnmatch(pattern: "\\*", path: "*"))
        XCTAssertTrue(File.fnmatch(pattern: "\\?", path: "?"))
        XCTAssertFalse(File.fnmatch(pattern: "\\*", path: "anything"))
    }

    func testEscapeInBrackets() throws {
        XCTAssertTrue(File.fnmatch(pattern: "[\\?]", path: "?"))
        XCTAssertTrue(File.fnmatch(pattern: "[\\*]", path: "*"))
        XCTAssertFalse(File.fnmatch(pattern: "[\\?]", path: "a"))
    }

    // MARK: - Flag Tests

    func testCaseFoldFlag() throws {
        XCTAssertFalse(File.fnmatch(pattern: "cat", path: "CAT", flags: []))
        XCTAssertTrue(File.fnmatch(pattern: "cat", path: "CAT", flags: .casefold))
        XCTAssertTrue(File.fnmatch(pattern: "CaT", path: "cat", flags: .casefold))
    }

    func testPathnameFlag() throws {
        // Without pathname flag, * matches /
        XCTAssertTrue(File.fnmatch(pattern: "*", path: "a/b", flags: []))
        
        // With pathname flag, * doesn't match /
        XCTAssertFalse(File.fnmatch(pattern: "*", path: "a/b", flags: .pathname))
        XCTAssertTrue(File.fnmatch(pattern: "a/*", path: "a/b", flags: .pathname))
        
        // ? also doesn't match / with pathname flag
        XCTAssertFalse(File.fnmatch(pattern: "?", path: "/", flags: .pathname))
    }

    func testPeriodFlag() throws {
        // By default, * doesn't match leading period (FNM_PERIOD is set)
        XCTAssertFalse(File.fnmatch(pattern: "*", path: ".profile", flags: .period))
        XCTAssertTrue(File.fnmatch(pattern: ".*", path: ".profile", flags: .period))
        
        // Without period flag, * can match leading period
        XCTAssertTrue(File.fnmatch(pattern: "*", path: ".profile", flags: []))
    }

    func testNoescapeFlag() throws {
        // Without noescape, backslash escapes
        XCTAssertTrue(File.fnmatch(pattern: "\\a", path: "a", flags: []))
        XCTAssertFalse(File.fnmatch(pattern: "\\a", path: "\\a", flags: []))
        
        // With noescape, backslash is literal
        XCTAssertFalse(File.fnmatch(pattern: "\\a", path: "a", flags: .noescape))
        XCTAssertTrue(File.fnmatch(pattern: "\\a", path: "\\a", flags: .noescape))
    }

    func testLeadingDirFlag() throws {
        // FNM_LEADING_DIR allows pattern to match a leading portion
        XCTAssertTrue(File.fnmatch(pattern: "*/foo", path: "bar/foo/baz", flags: .leadingDir))
        XCTAssertTrue(File.fnmatch(pattern: "bar/foo", path: "bar/foo/baz", flags: .leadingDir))
        XCTAssertFalse(File.fnmatch(pattern: "bar/foo", path: "bar/foo/baz", flags: []))
    }

    // MARK: - Complex Pattern Tests

    func testComplexGlobPatterns() throws {
        // Test various complex patterns
        XCTAssertTrue(File.fnmatch(pattern: "*.txt", path: "file.txt"))
        XCTAssertFalse(File.fnmatch(pattern: "*.txt", path: "file.md"))
        
        // Multiple wildcards
        XCTAssertTrue(File.fnmatch(pattern: "*.*", path: "file.txt"))
        XCTAssertTrue(File.fnmatch(pattern: "test_*.rb", path: "test_file.rb"))
        XCTAssertFalse(File.fnmatch(pattern: "test_*.rb", path: "spec_file.rb"))
    }

    func testHiddenFileMatching() throws {
        // Without special flags, * matches everything including paths with /
        XCTAssertTrue(File.fnmatch(pattern: "*", path: "dave/.profile", flags: []))
        
        // With pathname flag, we need to be more specific
        XCTAssertFalse(File.fnmatch(pattern: "*", path: "dave/.profile", flags: .pathname))
        XCTAssertTrue(File.fnmatch(pattern: "dave/*", path: "dave/.profile", flags: .pathname))
        XCTAssertTrue(File.fnmatch(pattern: "dave/.*", path: "dave/.profile", flags: .pathname))
        
        // Hidden files in current directory
        XCTAssertFalse(File.fnmatch(pattern: "*", path: ".hidden", flags: .period))
        XCTAssertTrue(File.fnmatch(pattern: ".*", path: ".hidden", flags: .period))
    }
}