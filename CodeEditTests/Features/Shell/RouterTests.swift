import SwiftUI
import XCTest
@testable import CodeEdit

final class RouterTests: XCTestCase {

    // MARK: - parse: valid inputs

    func testParseNodeRoute() {
        let url = URL(string: "dynamite://node/spec-9k3fa")!
        let route = Router.parse(url: url)
        XCTAssertEqual(route, .node(id: "spec-9k3fa"))
    }

    func testParseSurfaceRoute() {
        let url = URL(string: "dynamite://surface/studio")!
        let route = Router.parse(url: url)
        XCTAssertEqual(route, .surface(id: "studio"))
    }

    func testParseCodeRoutePathOnly() {
        let encoded = "Sources/App.swift".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "dynamite://code?path=\(encoded)")!
        let route = Router.parse(url: url)
        XCTAssertEqual(route, .code(path: "Sources/App.swift", line: nil, symbol: nil))
    }

    func testParseCodeRouteWithLine() {
        let encoded = "Sources/App.swift".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "dynamite://code?path=\(encoded)&line=42")!
        let route = Router.parse(url: url)
        XCTAssertEqual(route, .code(path: "Sources/App.swift", line: 42, symbol: nil))
    }

    func testParseCodeRouteWithSymbol() {
        let pathEncoded = "Sources/App.swift".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let symEncoded = "MyClass.init".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "dynamite://code?path=\(pathEncoded)&line=10&symbol=\(symEncoded)")!
        let route = Router.parse(url: url)
        XCTAssertEqual(route, .code(path: "Sources/App.swift", line: 10, symbol: "MyClass.init"))
    }

    func testParseContextRoute() {
        let encoded = "Sources/Foo.swift".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "dynamite://context?path=\(encoded)")!
        let route = Router.parse(url: url)
        XCTAssertEqual(route, .context(path: "Sources/Foo.swift"))
    }

    func testParseModeRouteCockpit() {
        let url = URL(string: "dynamite://mode/cockpit")!
        let route = Router.parse(url: url)
        XCTAssertEqual(route, .mode(.cockpit))
    }

    func testParseModeRouteIDE() {
        let url = URL(string: "dynamite://mode/ide")!
        let route = Router.parse(url: url)
        XCTAssertEqual(route, .mode(.ide))
    }

    // MARK: - parse: invalid inputs

    func testParseWrongSchemeReturnsNil() {
        let url = URL(string: "https://example.com/node/abc")!
        XCTAssertNil(Router.parse(url: url))
    }

    func testParseUnknownHostReturnsNil() {
        let url = URL(string: "dynamite://unknown/something")!
        XCTAssertNil(Router.parse(url: url))
    }

    func testParseNodeEmptyIDReturnsNil() {
        let url = URL(string: "dynamite://node/")!
        XCTAssertNil(Router.parse(url: url))
    }

    func testParseSurfaceEmptyIDReturnsNil() {
        let url = URL(string: "dynamite://surface/")!
        XCTAssertNil(Router.parse(url: url))
    }

    func testParseCodeMissingPathReturnsNil() {
        let url = URL(string: "dynamite://code?line=5")!
        XCTAssertNil(Router.parse(url: url))
    }

    func testParseContextMissingPathReturnsNil() {
        let url = URL(string: "dynamite://context?")!
        XCTAssertNil(Router.parse(url: url))
    }

    func testParseModeInvalidValueReturnsNil() {
        let url = URL(string: "dynamite://mode/unknown")!
        XCTAssertNil(Router.parse(url: url))
    }

    // MARK: - url(for:): round-trip

    func testURLRoundTripNode() {
        let route = DynamiteRoute.node(id: "spec-abc123")
        let url = Router.url(for: route)
        XCTAssertEqual(Router.parse(url: url), route)
    }

    func testURLRoundTripSurface() {
        let route = DynamiteRoute.surface(id: "map")
        let url = Router.url(for: route)
        XCTAssertEqual(Router.parse(url: url), route)
    }

    func testURLRoundTripCodePathOnly() {
        let route = DynamiteRoute.code(path: "Sources/main.swift", line: nil, symbol: nil)
        let url = Router.url(for: route)
        XCTAssertEqual(Router.parse(url: url), route)
    }

    func testURLRoundTripCodeWithLine() {
        let route = DynamiteRoute.code(path: "Sources/main.swift", line: 99, symbol: nil)
        let url = Router.url(for: route)
        XCTAssertEqual(Router.parse(url: url), route)
    }

    func testURLRoundTripCodeWithSymbol() {
        let route = DynamiteRoute.code(path: "Sources/main.swift", line: 1, symbol: "App.init")
        let url = Router.url(for: route)
        XCTAssertEqual(Router.parse(url: url), route)
    }

    func testURLRoundTripContext() {
        let route = DynamiteRoute.context(path: "Sources/Baz.swift")
        let url = Router.url(for: route)
        XCTAssertEqual(Router.parse(url: url), route)
    }

    func testURLRoundTripModeCockpit() {
        let route = DynamiteRoute.mode(.cockpit)
        let url = Router.url(for: route)
        XCTAssertEqual(Router.parse(url: url), route)
    }

    func testURLRoundTripModeIDE() {
        let route = DynamiteRoute.mode(.ide)
        let url = Router.url(for: route)
        XCTAssertEqual(Router.parse(url: url), route)
    }

    // MARK: - url(for:): URL scheme and structure

    func testURLSchemeIsDynamite() {
        let url = Router.url(for: .node(id: "x"))
        XCTAssertEqual(url.scheme, "dynamite")
    }

    func testCodeURLContainsPathQueryItem() {
        let url = Router.url(for: .code(path: "dir/file.swift", line: nil, symbol: nil))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.queryItems?.first(where: { $0.name == "path" })?.value
        XCTAssertEqual(path, "dir/file.swift")
    }

    func testCodeURLLineQueryItemAbsentWhenNil() {
        let url = Router.url(for: .code(path: "a.swift", line: nil, symbol: nil))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let hasLine = components?.queryItems?.contains(where: { $0.name == "line" }) ?? false
        XCTAssertFalse(hasLine)
    }

    // MARK: - ViewMode

    func testViewModeRawValues() {
        XCTAssertEqual(ViewMode.cockpit.rawValue, "cockpit")
        XCTAssertEqual(ViewMode.ide.rawValue, "ide")
    }

    func testViewModeRoundTripFromRawValue() {
        XCTAssertEqual(ViewMode(rawValue: "cockpit"), .cockpit)
        XCTAssertEqual(ViewMode(rawValue: "ide"), .ide)
        XCTAssertNil(ViewMode(rawValue: "unknown"))
    }

    // MARK: - CockpitSurfaceRegistry

    func testRegistryRegisterAndUnregister() {
        let registry = CockpitSurfaceRegistry()
        XCTAssertTrue(registry.surfaces.isEmpty)

        let stub = StubSurface(id: "test-surface", title: "Test", systemImage: "circle")
        registry.register(stub)
        XCTAssertEqual(registry.surfaces.count, 1)
        XCTAssertEqual(registry.surfaces.first?.id, "test-surface")

        registry.unregister(id: "test-surface")
        XCTAssertTrue(registry.surfaces.isEmpty)
    }

    func testRegistryNoDuplicates() {
        let registry = CockpitSurfaceRegistry()
        let stub = StubSurface(id: "dup", title: "Dup", systemImage: "circle")
        registry.register(stub)
        registry.register(stub)
        XCTAssertEqual(registry.surfaces.count, 1)
    }

    func testRegistryUnregisterUnknownIDIsNoop() {
        let registry = CockpitSurfaceRegistry()
        registry.unregister(id: "nonexistent") // must not crash
        XCTAssertTrue(registry.surfaces.isEmpty)
    }
}

// MARK: - Test helpers

private struct StubSurface: CockpitSurface {
    let id: String
    let title: String
    let systemImage: String
    var body: AnyView { AnyView(EmptyView()) }
}
