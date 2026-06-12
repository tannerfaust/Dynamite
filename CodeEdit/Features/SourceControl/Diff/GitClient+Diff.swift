// swiftlint:disable function_body_length
//
//  GitClient+Diff.swift
//  CodeEdit
//
//  Created for Dynamite — T0.4 Doc Review Parity
//

import Foundation

extension GitClient {
    // MARK: - Public API

    /// Fetches the working-tree diff for a single file.
    /// - Parameters:
    ///   - filePath: Absolute path of the file.
    ///   - staged: When true uses `--cached` (staged vs HEAD); otherwise compares working tree to HEAD.
    func getFileDiff(filePath: String, staged: Bool) async throws -> [DiffHunk] {
        let quoted = "'\(filePath)'"
        let raw: String
        if staged {
            raw = try await run("diff --unified=3 --cached -- \(quoted)")
        } else {
            // Untracked files produce no output from `diff HEAD`; fall back to /dev/null comparison.
            let headDiff = (try? await run("diff --unified=3 HEAD -- \(quoted)")) ?? ""
            if headDiff.isEmpty {
                raw = (try? await run("diff --unified=3 --no-index /dev/null \(quoted)")) ?? ""
            } else {
                raw = headDiff
            }
        }
        return parseDiff(raw)
    }

    /// Fetches the diff for a single file in a specific commit.
    func getCommitFileDiff(commitHash: String, filePath: String) async throws -> [DiffHunk] {
        let quoted = "'\(filePath)'"
        // `^1` is the first parent; for initial commits use `--root` via empty-tree fallback.
        let raw: String
        do {
            raw = try await run("diff --unified=3 \(commitHash)^1 \(commitHash) -- \(quoted)")
        } catch {
            // Initial commit has no parent — diff against the empty tree.
            raw = try await run(
                "diff --unified=3 4b825dc642cb6eb9a060e54bf8d69288fbee4904 \(commitHash) -- \(quoted)"
            )
        }
        return parseDiff(raw)
    }

    // MARK: - Parser

    func parseDiff(_ raw: String) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var linesBuffer: [DiffLine] = []
        var currentHeader = ""
        var currentOldStart = 0
        var currentNewStart = 0
        var inHunk = false
        var oldLineNum = 0
        var newLineNum = 0

        for line in raw.components(separatedBy: "\n") {
            // Skip file-header lines
            if line.hasPrefix("diff ")
                || line.hasPrefix("index ")
                || line.hasPrefix("--- ")
                || line.hasPrefix("+++ ")
                || line.hasPrefix("\\ ") {
                continue
            }

            if line.hasPrefix("@@ ") {
                if inHunk {
                    hunks.append(DiffHunk(
                        header: currentHeader,
                        oldStart: currentOldStart,
                        newStart: currentNewStart,
                        lines: linesBuffer
                    ))
                }
                guard let parsed = parseHunkHeader(line) else { continue }
                currentHeader = line
                currentOldStart = parsed.oldStart
                currentNewStart = parsed.newStart
                oldLineNum = parsed.oldStart
                newLineNum = parsed.newStart
                linesBuffer = []
                inHunk = true
                continue
            }

            guard inHunk else { continue }

            if line.hasPrefix("-") {
                linesBuffer.append(DiffLine(
                    kind: .removed,
                    content: String(line.dropFirst()),
                    oldNumber: oldLineNum,
                    newNumber: nil
                ))
                oldLineNum += 1
            } else if line.hasPrefix("+") {
                linesBuffer.append(DiffLine(
                    kind: .added,
                    content: String(line.dropFirst()),
                    oldNumber: nil,
                    newNumber: newLineNum
                ))
                newLineNum += 1
            } else if line.hasPrefix(" ") {
                linesBuffer.append(DiffLine(
                    kind: .context,
                    content: String(line.dropFirst()),
                    oldNumber: oldLineNum,
                    newNumber: newLineNum
                ))
                oldLineNum += 1
                newLineNum += 1
            }
        }

        if inHunk {
            hunks.append(DiffHunk(
                header: currentHeader,
                oldStart: currentOldStart,
                newStart: currentNewStart,
                lines: linesBuffer
            ))
        }

        return hunks
    }

    // MARK: - Private helpers

    private func parseHunkHeader(_ line: String) -> (oldStart: Int, newStart: Int)? {
        let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let oldRange = Range(match.range(at: 1), in: line),
            let newRange = Range(match.range(at: 2), in: line),
            let oldStart = Int(line[oldRange]),
            let newStart = Int(line[newRange])
        else { return nil }
        return (oldStart, newStart)
    }
}
