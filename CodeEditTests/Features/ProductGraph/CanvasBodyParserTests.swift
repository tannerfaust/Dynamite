import XCTest
@testable import CodeEdit

final class CanvasBodyParserTests: XCTestCase {

    func testParseSectionsAndCards() {
        let body = """
        # My VPC

        ## Customer Jobs
        *Jobs guidance*
        - Build faster
          - { rel: relates-to, to: prb-abc, label: "Core problem" }

        ## Pains
        - Manual context prep
        """

        let doc = CanvasBodyParser.parse(body)
        XCTAssertEqual(doc.title, "My VPC")
        XCTAssertEqual(doc.sections.count, 2)
        XCTAssertEqual(doc.sections[0].heading, "Customer Jobs")
        XCTAssertEqual(doc.sections[0].guidance, "Jobs guidance")
        XCTAssertEqual(doc.sections[0].cards.count, 1)
        XCTAssertEqual(doc.sections[0].cards[0].text, "Build faster")
        XCTAssertEqual(doc.sections[0].cards[0].links.count, 1)
        XCTAssertEqual(doc.sections[0].cards[0].links[0].to, "prb-abc")
    }

    func testRoundTripPreservesStructure() {
        let body = """
        # Journey

        ## Discovery
        *Learn about the product*
        - Tweet mention

        ## Onboarding
        - Drag folder in
        """

        let serialized = CanvasBodyParser.serialize(CanvasBodyParser.parse(body))
        let reparsed = CanvasBodyParser.parse(serialized)
        XCTAssertEqual(reparsed.title, "Journey")
        XCTAssertEqual(reparsed.sections.count, 2)
        XCTAssertEqual(reparsed.sections[0].cards.first?.text, "Tweet mention")
    }

    func testParseStoryMapSubsections() {
        let body = """
        # Story Map

        ## Manage Context

        ### Initialize Graph
        - As a builder, I can open a workspace
        """

        let doc = CanvasBodyParser.parse(body)
        XCTAssertEqual(doc.sections.count, 1)
        XCTAssertEqual(doc.sections[0].subsections.count, 1)
        XCTAssertEqual(doc.sections[0].subsections[0].heading, "Initialize Graph")
        XCTAssertEqual(
            doc.sections[0].subsections[0].cards.first?.text,
            "As a builder, I can open a workspace"
        )
    }

    func testParseTreeNestedOST() {
        let body = """
        # OST

        ## Opportunity Solution Tree
        - Outcome: Reduce errors
          - Opportunity: Stale docs
            - Solution: Auto-compile
              - Experiment: Pilot on 5 repos
        """

        let nodes = CanvasBodyParser.parseTree(body)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].text, "Outcome: Reduce errors")
        XCTAssertEqual(nodes[0].children.count, 1)
        XCTAssertEqual(nodes[0].children[0].children.count, 1)
        XCTAssertEqual(nodes[0].children[0].children[0].children.count, 1)
    }

    func testSerializeTreeRoundTrip() {
        let nodes = [
            CanvasTreeNode(
                text: "Outcome",
                children: [CanvasTreeNode(text: "Opportunity", children: [CanvasTreeNode(text: "Solution")])]
            )
        ]
        let body = CanvasBodyParser.serializeTree(nodes, title: "OST Title")
        let reparsed = CanvasBodyParser.parseTree(body)
        XCTAssertEqual(reparsed.count, 1)
        XCTAssertEqual(reparsed[0].children.count, 1)
    }

    func testNormalizedCanvasHasAllVPCBlocks() {
        let doc = CanvasBodyParser.parse("# T\n\n## Customer Jobs\n- One")
        let normalized = ArtifactKind.vpc.normalizedCanvasDocument(from: doc)
        XCTAssertEqual(normalized.sections.count, 6)
        XCTAssertEqual(normalized.sections[0].heading, "Customer Jobs")
        XCTAssertEqual(normalized.sections[0].cards.count, 1)
        XCTAssertEqual(normalized.sections[1].cards.count, 0)
    }
}
