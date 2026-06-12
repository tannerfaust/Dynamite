// swiftlint:disable identifier_name
import XCTest
@testable import CodeEdit

final class LinkIndexTests: XCTestCase {
    var workspaceURL: URL!
    var productURL: URL!
    var manager: LinkIndexManager!

    override func setUp() async throws {
        workspaceURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)

        productURL = workspaceURL.appendingPathComponent("product")
        try FileManager.default.createDirectory(at: productURL, withIntermediateDirectories: true)

        manager = try LinkIndexManager(workspaceURL: workspaceURL, watchesFileSystem: false)
    }

    override func tearDown() async throws {
        manager.close()
        manager = nil
        try? FileManager.default.removeItem(at: workspaceURL)
    }

    func testRebuildIdempotence() async throws {
        let fileURL = productURL.appendingPathComponent("test1.md")
        let content = """
        ---
        id: test-123
        kind: spec
        status: active
        links:
          - { rel: relates-to, to: test-456, label: "Test" }
        ---
        # Test 1
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        try await manager.rebuildIndex()
        let count1 = try await manager.database.dbWriter.read { db in
            try LinkIndexNode.fetchCount(db)
        }

        try await manager.rebuildIndex()
        let count2 = try await manager.database.dbWriter.read { db in
            try LinkIndexNode.fetchCount(db)
        }

        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count1, count2)
    }

    func testRenameSurvival() async throws {
        let fileURL = productURL.appendingPathComponent("test1.md")
        let content = """
        ---
        id: test-123
        kind: spec
        status: active
        ---
        # Test 1
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        try await manager.rebuildIndex()

        let node1 = try await manager.database.dbWriter.read { db in
            try LinkIndexNode.fetchOne(db, key: "test-123")
        }
        XCTAssertEqual(node1?.path, "product/test1.md")

        // Rename
        let newURL = productURL.appendingPathComponent("test2.md")
        try FileManager.default.moveItem(at: fileURL, to: newURL)

        try await manager.rebuildIndex()

        let node2 = try await manager.database.dbWriter.read { db in
            try LinkIndexNode.fetchOne(db, key: "test-123")
        }
        XCTAssertEqual(node2?.path, "product/test2.md")
        XCTAssertEqual(node1?.contentSHA, node2?.contentSHA)
    }

    func testBrokenLinkDetection() async throws {
        let fileURL = productURL.appendingPathComponent("test1.md")
        let content = """
        ---
        id: test-123
        kind: spec
        status: active
        links:
          - { rel: relates-to, to: broken-999, label: "Broken" }
        ---
        # Test 1
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        try await manager.rebuildIndex()

        let broken = try await manager.database.dbWriter.read { db in
            try LinkIndexEdge.fetchAll(db).filter { !$0.resolved }
        }

        XCTAssertEqual(broken.count, 1)
        XCTAssertEqual(broken.first?.dstId, "broken-999")
        XCTAssertEqual(manager.brokenLinks.count, 1)
    }
}
