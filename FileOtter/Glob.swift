//
//  Glob.swift
//  FileOtter
//
//  Created by Sami Samhuri on 2025-08-17.
//

import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// Expand a glob pattern supporting ** (recursive), *, ?, and [].
/// Examples:
///   "src/**/*.swift"
///   "/var/log/**/app*.log"
func globstar(_ pattern: String, base: URL? = nil) -> [URL] {
    // Normalize and split into path components
    let comps = pattern.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

    var results: [String] = []
    var seenDirs = Set<String>() // canonical paths to avoid cycles if symlinks appear
    
    // Cache frequently used objects
    let fm = FileManager.default
    let globMetaChars = CharacterSet(charactersIn: "*?[")

    func isDir(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return false
    }

    func listDir(_ path: String) -> [String] {
        (try? fm.contentsOfDirectory(atPath: path)) ?? []
    }

    // fnmatch against a single path segment (no '/')
    @inline(__always)
    func matchSegment(_ name: String, pat: String) -> Bool {
        name.withCString { nPtr in
            pat.withCString { pPtr in
                // FNM_PERIOD -> leading '.' must be matched explicitly (shell-like)
                // FNM_NOESCAPE -> backslashes are treated literally
                fnmatch(pPtr, nPtr, FNM_PERIOD | FNM_NOESCAPE) == 0
            }
        }
    }

    func real(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    func walk(_ base: String, _ idx: Int) {
        if idx == comps.count {
            // Only return existing paths
            if FileManager.default.fileExists(atPath: base) {
                results.append(real(base))
            }
            return
        }

        let part = comps[idx]

        if part == "**" {
            // Option 1: ** matches zero segments
            walk(base, idx + 1)

            // Option 2: ** matches one or more directory segments
            // Recurse into subdirs breadth-first
            let dirPath = base.isEmpty ? "/" : base
            let key = real(dirPath)
            if seenDirs.contains(key) { return }
            seenDirs.insert(key)

            if isDir(dirPath) {
                let dirPathNS = dirPath as NSString  // Cache the NSString conversion
                for entry in listDir(dirPath) {
                    let child = dirPathNS.appendingPathComponent(entry)
                    if isDir(child) {
                        // Keep idx the same to allow ** to consume multiple levels
                        walk(child, idx)
                    }
                }
            }
            return
        }

        // Non-** component. If it has no glob metachar, fast-path.
        let hasMeta = part.rangeOfCharacter(from: globMetaChars) != nil
        if !hasMeta {
            let next = (base as NSString).appendingPathComponent(part)
            walk(next, idx + 1)
            return
        }

        // Segment glob (*, ?, []) matches names in this directory level only
        let dirPath = base.isEmpty ? "/" : base
        if !isDir(dirPath) { return }
        let dirPathNS = dirPath as NSString  // Cache the NSString conversion
        for entry in listDir(dirPath) {
            if matchSegment(entry, pat: part) {
                let next = dirPathNS.appendingPathComponent(entry)
                walk(next, idx + 1)
            }
        }
    }

    // Kick off
    let isAbs = pattern.hasPrefix("/")
    let cwd = (base ?? URL.currentDirectory()).path
    walk(isAbs ? "/" : cwd, 0)

    // De-dup and sort for stability
    return Array(Set(results)).sorted()
}
