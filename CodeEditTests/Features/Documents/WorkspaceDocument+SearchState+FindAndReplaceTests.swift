//
//  WorkspaceDocument+SearchState+FindAndReplaceTests.swift
//  CodeEditTests
//
//  Created by Tommy Ludwig on 26.01.24.
//

import XCTest
@testable import CodeEdit

@MainActor
final class FindAndReplaceTests: XCTestCase {
    private var directory: URL!
    private var files: [CEWorkspaceFile] = []
    private var mockWorkspace: WorkspaceDocument!
    private var searchState: WorkspaceDocument.SearchState!

    private var folder1File: CEWorkspaceFile?
    private var folder2File: CEWorkspaceFile?

    // MARK: - Setup
    /// A mock WorkspaceDocument is created
    /// 3 mock files are added to the index
    /// which will be removed in the teardown function
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "WorkspaceClientTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Add a few files
        let folder1 = directory.appending(path: "Folder 2")
        folder1File = CEWorkspaceFile(url: folder1)
        let folder2 = directory.appending(path: "Longer Folder With Some 💯 Special Chars ⁉️")
        folder2File = CEWorkspaceFile(url: folder2)
        try FileManager.default.createDirectory(at: folder1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder2, withIntermediateDirectories: true)

        let fileURLs = [
            directory.appending(path: "File 1.txt"),
            folder1.appending(path: "Documentation.docc"),
            folder2.appending(path: "Makefile")
        ]

        for index in 0..<fileURLs.count {
            if index % 2 == 0 {
                try String("Loren Ipsum").write(to: fileURLs[index], atomically: true, encoding: .utf8)
            } else {
                try String("Aperiam asperiores").write(to: fileURLs[index], atomically: true, encoding: .utf8)
            }
        }

        files = fileURLs.map { CEWorkspaceFile(url: $0) }

        files[1].parent = folder1File
        files[2].parent = folder2File

        mockWorkspace = try WorkspaceDocument(for: directory, withContentsOf: directory, ofType: "")
        searchState = mockWorkspace.searchState

        // NOTE: This is a temporary solution. In the future, a file watcher should track file updates
        // and trigger an index update.
        let startTime = Date()
        let timeoutInSeconds = 2.0
        while searchState.indexStatus != .done {
            // Check every 0.1 seconds for index completion
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            if Date().timeIntervalSince(startTime) > timeoutInSeconds {
                XCTFail("TIMEOUT: Indexing took to long or did not complete.")
                return
            }
        }

        // Retrieve indexed documents from the indexer
        guard let documentsInIndex = searchState.indexer?.documents() else {
            XCTFail("No documents are in the index")
            return
        }

        // Verify that the setup function added the expected number of mock files to the index
        XCTAssertEqual(documentsInIndex.count, 3)
    }

    // MARK: - Tear down
    /// The mock directory along with the mock files will be removed
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func waitForSearchResultCount(
        _ expectedCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await waitForExpectation(timeout: .seconds(5)) {
            searchState.findNavigatorStatus == .found && searchState.searchResult.count == expectedCount
        } onTimeout: {
            XCTFail(
                "Expected \(expectedCount) search results, got \(searchState.searchResult.count).",
                file: file,
                line: line
            )
        }
    }

    private func replace(
        _ query: String,
        with replacingTerm: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await searchState.findAndReplace(query: query, replacingTerm: replacingTerm)
        } catch {
            XCTFail("Find and replace failed: \(error.localizedDescription)", file: file, line: line)
        }
    }

    private func searchAndWait(
        _ query: String,
        expectedCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await searchState.search(query)
        await waitForSearchResultCount(expectedCount, file: file, line: line)
    }

    func reIndexWorkspace() async {
        // IMPORTANT:
        // This is only a temporary solution, in the feature a file watcher would track the file update
        // and trigger a index update.
        searchState.addProjectToIndex()
        let startTime = Date()
        while searchState.indexStatus != .done {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Date().timeIntervalSince(startTime) > 2.0 {
                XCTFail("TIMEOUT: Indexing took to long or did not complete.")
                return
            }
        }
    }

    func testFindAndReplace() async {
        await replace("Ipsum", with: "muspi")
        await reIndexWorkspace()
        await searchAndWait("muspi", expectedCount: 2)

        // Expecting a result count of 2 because "Ipsum" is replaced in two documents.
        XCTAssertEqual(searchState.searchResult.count, 2)
    }

    func testFindAndReplaceWithOptionContaining() async {
        await replace("psu", with: "OOO")
        await reIndexWorkspace()
        await searchAndWait("IOOOm", expectedCount: 2)

        XCTAssertEqual(searchState.searchResult.count, 2)
    }

    func testFindAndReplaceWithOptionMatchingWord() async {
        searchState.selectedMode[2] = .MatchingWord

        // This replacement should fail due to the .MatchingWord option.
        await replace("psu", with: "OOO")
        await reIndexWorkspace()
        await searchAndWait("IOOOm", expectedCount: 0)

        // Expecting a result count of 0 due to the intentional use of a incomplete word, while using .MatchingWord
        XCTAssertEqual(searchState.searchResult.count, 0)

        // This should replace Ipsum correctly, because Ipsum is a whole word in 2 of the mock-documents.
        await replace("Ipsum", with: "OOO")
        await reIndexWorkspace()
        await searchAndWait("OOO", expectedCount: 2)

        // 'Ipsum' got replaced by '000' so we expecting 2 results(000 appears in two documents)
        XCTAssertEqual(searchState.searchResult.count, 2)
    }

    func testFindAndReplaceWithOptionStartingWith() async {
        searchState.selectedMode[2] = .StartingWith

        // This replacement should fail due to the .StartingWith option.
        await replace("psum", with: "OOO")
        await reIndexWorkspace()
        await searchAndWait("OOO", expectedCount: 0)

        // Expecting a result count of 0 due to the intentional use of a incomplete word, while using .MatchingWord
        XCTAssertEqual(searchState.searchResult.count, 0)

        // This should replace 'Ipsu' with '000' and result in '000m'.
        await replace("Ipsu", with: "OOO")
        await reIndexWorkspace()
        await searchAndWait("OOOm", expectedCount: 2)

        XCTAssertEqual(searchState.searchResult.count, 2)
    }

    func testFindAndReplaceWithOptionEndingWith() async {
        searchState.selectedMode[2] = .EndingWith

        // This replacement should fail due to the .EndingWith option.
        await replace("Ipsu", with: "OOO")
        await reIndexWorkspace()
        await searchAndWait("OOO", expectedCount: 0)

        // Expecting a result count of 0 due to the intentional use of a incomplete word, while using .MatchingWord
        XCTAssertEqual(searchState.searchResult.count, 0)

        // This should replace 'sum' with '000' and result in 'Ip000'.
        await replace("sum", with: "OOO")
        await reIndexWorkspace()
        await searchAndWait("IpOOO", expectedCount: 2)

        XCTAssertEqual(searchState.searchResult.count, 2)
    }

    // Not implemented
    func testFindAndReplaceWithOptionRegularExpression() async { }
}
