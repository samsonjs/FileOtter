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
        // TODO: Implement
        // File.fnmatch("cat", "cat") => true
        // File.fnmatch("cat", "dog") => false
    }

    func testPartialMatch() throws {
        // TODO: Implement
        // File.fnmatch("cat", "category") => false (must match entire string)
    }

    // MARK: - Wildcard Tests

    func testStarWildcard() throws {
        // TODO: Implement
        // File.fnmatch("c*", "cats") => true
        // File.fnmatch("c*t", "cat") => true
        // File.fnmatch("c*t", "c/a/b/t") => true
    }

    func testQuestionMarkWildcard() throws {
        // TODO: Implement
        // File.fnmatch("c?t", "cat") => true
        // File.fnmatch("c??t", "cat") => false
    }

    func testDoubleStarWildcard() throws {
        // TODO: Implement
        // File.fnmatch("**/*.rb", "main.rb") => false
        // File.fnmatch("**/*.rb", "lib/song.rb") => true
        // File.fnmatch("**.rb", "main.rb") => true
    }

    // MARK: - Character Set Tests

    func testCharacterSet() throws {
        // TODO: Implement
        // File.fnmatch("ca[a-z]", "cat") => true
        // File.fnmatch("ca[0-9]", "cat") => false
    }

    func testNegatedCharacterSet() throws {
        // TODO: Implement
        // File.fnmatch("ca[^t]", "cat") => false
        // File.fnmatch("ca[^t]", "cab") => true
    }

    // MARK: - Escape Tests

    func testEscapedWildcard() throws {
        // TODO: Implement
        // File.fnmatch("\\?", "?") => true
        // File.fnmatch("\\*", "*") => true
    }

    func testEscapeInBrackets() throws {
        // TODO: Implement
        // File.fnmatch("[\\?]", "?") => true
    }

    // MARK: - Flag Tests

    func testCaseFoldFlag() throws {
        // TODO: Implement
        // File.fnmatch("cat", "CAT", flags: []) => false
        // File.fnmatch("cat", "CAT", flags: .casefold) => true
    }

    func testPathnameFlag() throws {
        // TODO: Implement
        // File.fnmatch("*", "/", flags: []) => true
        // File.fnmatch("*", "/", flags: .pathname) => false
        // File.fnmatch("?", "/", flags: .pathname) => false
    }

    func testPeriodFlag() throws {
        // TODO: Implement
        // File.fnmatch("*", ".profile", flags: []) => false (FNM_PERIOD by default)
        // File.fnmatch(".*", ".profile", flags: []) => true
    }

    func testDotmatchFlag() throws {
        // TODO: Implement
        // File.fnmatch("*", ".profile", flags: .dotmatch) => true
    }

    func testNoescapeFlag() throws {
        // TODO: Implement
        // File.fnmatch("\\a", "a", flags: []) => true
        // File.fnmatch("\\a", "\\a", flags: .noescape) => true
    }

    func testExtglobFlag() throws {
        // TODO: Implement
        // File.fnmatch("c{at,ub}s", "cats", flags: []) => false
        // File.fnmatch("c{at,ub}s", "cats", flags: .extglob) => true
        // File.fnmatch("c{at,ub}s", "cubs", flags: .extglob) => true
    }

    // MARK: - Complex Pattern Tests

    func testComplexGlobPatterns() throws {
        // TODO: Implement
        // File.fnmatch("**/foo", "a/b/c/foo", flags: .pathname) => true
        // File.fnmatch("**/foo", "/a/b/c/foo", flags: .pathname) => true
        // File.fnmatch("**/foo", "a/.b/c/foo", flags: .pathname) => false
        // File.fnmatch("**/foo", "a/.b/c/foo", flags: [.pathname, .dotmatch]) => true
    }

    func testHiddenFileMatching() throws {
        // TODO: Implement
        // File.fnmatch("*", "dave/.profile", flags: []) => true
        // File.fnmatch("**/.*", "a/.hidden", flags: .pathname) => true
    }
}
