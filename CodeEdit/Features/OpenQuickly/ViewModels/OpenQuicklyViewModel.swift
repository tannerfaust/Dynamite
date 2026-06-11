//
//  OpenQuicklyViewModel.swift
//  CodeEditModules/QuickOpen
//
//  Created by Marco Carnevali on 05/04/22.
//

import Combine
import Foundation
import CollectionConcurrencyKit

final class OpenQuicklyViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var searchResults: [SearchResult] = []

    let fileURL: URL
    var runningTask: Task<Void, Never>?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// This is used to populate the ``OpenQuicklyListItemView`` view which shows the search results to the user.
    ///
    /// ``OpenQuicklyPreviewView`` also uses this to load the `fileUrl` for preview.
    struct SearchResult: Identifiable, Hashable {
        var id: String { fileURL.id }
        let fileURL: URL
        let matchedCharacters: [NSRange]
        /// The artifact `kind:` string, set when the file is a product `.md` document.
        let artifactKind: String?
        /// The artifact `status:` string, set when the file is a product `.md` document.
        let artifactStatus: String?

        init(
            fileURL: URL,
            matchedCharacters: [NSRange],
            artifactKind: String? = nil,
            artifactStatus: String? = nil
        ) {
            self.fileURL = fileURL
            self.matchedCharacters = matchedCharacters
            self.artifactKind = artifactKind
            self.artifactStatus = artifactStatus
        }

        // This custom Hashable implementation prevents the highlighted
        // selection from flickering when searching in 'Open Quickly'.
        //
        // See https://github.com/CodeEditApp/CodeEdit/pull/1790#issuecomment-2206832901
        // for flickering visuals.
        //
        // Before commit 0e28b382f59184b7ebe5a7c3295afa3655b7d4e7, only the fileURL
        // was retrieved from the search results and it worked as expected.
        //
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.fileURL == rhs.fileURL }
        func hash(into hasher: inout Hasher) { hasher.combine(fileURL) }
    }

    // MARK: - Graph-aware filter parsing

    /// Parsed tokens from a query that contains `kind:` and/or `status:` prefix filters.
    struct SearchFilters {
        let kinds: [String]
        let statuses: [String]
        /// The query string with `kind:` and `status:` tokens stripped out.
        let rawQuery: String

        var hasFilters: Bool { !kinds.isEmpty || !statuses.isEmpty }

        static func parse(from query: String) -> SearchFilters {
            var kinds: [String] = []
            var statuses: [String] = []
            var remaining: [String] = []
            for token in query.components(separatedBy: .whitespaces) where !token.isEmpty {
                if token.lowercased().hasPrefix("kind:") && token.count > 5 {
                    kinds.append(String(token.dropFirst(5)).lowercased())
                } else if token.lowercased().hasPrefix("status:") && token.count > 7 {
                    statuses.append(String(token.dropFirst(7)).lowercased())
                } else {
                    remaining.append(token)
                }
            }
            return SearchFilters(kinds: kinds, statuses: statuses, rawQuery: remaining.joined(separator: " "))
        }

        func matches(result: SearchResult) -> Bool {
            guard hasFilters else { return true }
            let resultKind = result.artifactKind?.lowercased() ?? ""
            let resultStatus = result.artifactStatus?.lowercased() ?? ""
            let kindMatch = kinds.isEmpty || kinds.contains(where: { resultKind.contains($0) })
            let statusMatch = statuses.isEmpty || statuses.contains(where: { resultStatus.contains($0) })
            return kindMatch && statusMatch
        }
    }

    // MARK: - Front-matter extraction

    /// Reads up to 512 bytes of a product `.md` file and returns kind + status strings, or nils.
    private static func productMeta(for url: URL) -> (kind: String?, status: String?) {
        guard url.pathExtension == "md", url.path.contains("/product/"),
              let handle = try? FileHandle(forReadingFrom: url) else { return (nil, nil) }
        let chunk = handle.readData(ofLength: 512)
        handle.closeFile()
        guard let header = String(data: chunk, encoding: .utf8) else { return (nil, nil) }
        return quickMeta(from: header)
    }

    /// Scans a front-matter header string for `kind:` and `status:` fields.
    private static func quickMeta(from header: String) -> (kind: String?, status: String?) {
        guard header.hasPrefix("---") else { return (nil, nil) }
        var kind: String?
        var status: String?
        for line in header.components(separatedBy: .newlines).dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            if trimmed.hasPrefix("kind:") && kind == nil {
                kind = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("status:") && status == nil {
                status = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }
            if kind != nil && status != nil { break }
        }
        return (kind, status)
    }

    // MARK: - Search

    func fetchResults() {
        let startTime = Date()
        guard query != "" else {
            searchResults = []
            return
        }

        let filters = SearchFilters.parse(from: query)
        // Use the stripped query for fuzzy search; fall back to full query when no filters present
        let fuzzyQuery = filters.hasFilters && !filters.rawQuery.isEmpty
            ? filters.rawQuery
            : (filters.hasFilters ? "" : query)

        runningTask?.cancel()
        runningTask = Task.detached(priority: .userInitiated) {
            let enumerator = FileManager.default.enumerator(
                at: self.fileURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsPackageDescendants]
            )
            guard let filePaths = enumerator?.allObjects as? [URL] else { return }
            guard !Task.isCancelled else { return }

            let regularFiles = filePaths.filter { url in
                (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }

            let matched: [SearchResult]
            if fuzzyQuery.isEmpty {
                // Filters only — no fuzzy search needed; score all product .md files
                matched = regularFiles.compactMap { url -> SearchResult? in
                    let meta = OpenQuicklyViewModel.productMeta(for: url)
                    guard meta.kind != nil || meta.status != nil else { return nil }
                    let result = SearchResult(
                        fileURL: url, matchedCharacters: [],
                        artifactKind: meta.kind, artifactStatus: meta.status
                    )
                    return filters.matches(result: result) ? result : nil
                }
            } else {
                let fuzzy = await regularFiles.fuzzySearch(
                    query: fuzzyQuery.trimmingCharacters(in: .whitespaces)
                )
                matched = await fuzzy.concurrentMap { match -> SearchResult in
                    let meta = OpenQuicklyViewModel.productMeta(for: match.item)
                    return SearchResult(
                        fileURL: match.item,
                        matchedCharacters: match.result.matchedParts,
                        artifactKind: meta.kind,
                        artifactStatus: meta.status
                    )
                }.filter { filters.matches(result: $0) }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.searchResults = matched
                print("Duration: \(Date().timeIntervalSince(startTime))")
            }
        }
    }
}
