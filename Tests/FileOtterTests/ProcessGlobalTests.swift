//
//  ProcessGlobalTests.swift
//  FileOtterTests
//
//  Parent suite for tests that mutate process-global state (cwd, umask).
//  `.serialized` ensures these tests never run in parallel — neither with each
//  other within a nested suite, nor across the nested suites.
//
//  Add new global-state-touching suites as nested types via extension:
//
//    extension ProcessGlobalTests {
//        @Suite struct MyTests { ... }
//    }
//

import Testing

@Suite(.serialized) struct ProcessGlobalTests {}
