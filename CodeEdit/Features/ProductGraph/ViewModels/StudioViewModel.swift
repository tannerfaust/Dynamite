//
//  StudioViewModel.swift
//  CodeEdit
//

import SwiftUI
import Combine

/// State for the Product Studio Cockpit surface.
///
/// Owns the `ArtifactStore` for this workspace session and drives the Studio UI.
/// Top-level Studio display mode.
enum StudioDisplayMode: String, CaseIterable, Identifiable {
    case artifacts
    case roadmap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .artifacts: return "Artifacts"
        case .roadmap:   return "Roadmap"
        }
    }

    var systemImage: String {
        switch self {
        case .artifacts: return "doc.richtext"
        case .roadmap:   return "flag.2.crossed"
        }
    }
}

@MainActor
final class StudioViewModel: ObservableObject {
    let store: ArtifactStore
    weak var linkIndexManager: LinkIndexManager?

    @Published var selectedArtifactID: String?
    @Published var categoryFilter: ArtifactCategory?
    @Published var displayMode: StudioDisplayMode = .artifacts
    @Published var showingNewArtifactSheet = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    /// Node id awaiting selection until the store finishes its initial async load.
    private var pendingNodeID: String?

    private let workspaceURL: URL

    init(workspaceURL: URL, linkIndexManager: LinkIndexManager? = nil) {
        self.workspaceURL = workspaceURL
        self.store = ArtifactStore(workspaceURL: workspaceURL)
        self.linkIndexManager = linkIndexManager

        // dynamite://node/<id> routes (Backlinks panel, Product Map taps) land here.
        // Events carry the originating workspace URL; ignore other projects' windows.
        NotificationCenter.default.publisher(for: .cockpitFocusNode)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self, let id = note.userInfo?["id"] as? String else { return }
                if let origin = note.userInfo?["workspaceURL"] as? URL,
                   origin.standardizedFileURL.path != workspaceURL.standardizedFileURL.path {
                    return
                }
                self.navigateToNode(id)
            }
            .store(in: &cancellables)

        // Resolve a navigation that raced the store's initial load.
        store.$artifacts
            .receive(on: RunLoop.main)
            .sink { [weak self] artifacts in
                guard let self, let pending = self.pendingNodeID,
                      artifacts.contains(where: { $0.id == pending }) else { return }
                self.pendingNodeID = nil
                self.navigateToNode(pending)
            }
            .store(in: &cancellables)
    }

    var filteredArtifacts: [ProductArtifact] {
        guard let filter = categoryFilter else { return store.artifacts }
        return store.artifacts.filter { $0.kind?.category == filter }
    }

    var selectedArtifact: ProductArtifact? {
        guard let id = selectedArtifactID else { return nil }
        return store.artifacts.first { $0.id == id }
    }

    func createArtifact(kind: ArtifactKind, title: String, extraFields: [String: String] = [:]) {
        Task {
            do {
                var artifact = try await store.newArtifact(kind: kind, title: title)
                if !extraFields.isEmpty {
                    artifact.extraFields.merge(extraFields) { _, new in new }
                    try store.save(artifact)
                }
                selectedArtifactID = artifact.id
                showingNewArtifactSheet = false
                if displayMode == .roadmap, kind == .roadmapItem {
                    displayMode = .roadmap
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func navigateToNode(_ nodeID: String) {
        if let match = store.artifacts.first(where: { $0.id == nodeID }) {
            displayMode = .artifacts
            selectedArtifactID = match.id
        } else {
            // Store may still be loading; retried when $artifacts publishes.
            pendingNodeID = nodeID
        }
    }

    func save(_ artifact: ProductArtifact) {
        do {
            try store.save(artifact)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - AIAssist Factory

    /// Creates a fully-wired `AIAssistViewModel` for an artifact editor.
    /// Called once per editor instantiation from `ArtifactEditorView.init`.
    func makeAssistViewModel() -> AIAssistViewModel {
        let settings = Settings.shared.preferences.aiAssist
        let spendLedger = SpendLedger(workspaceURL: store.workspaceURL)
        let service = LiveAIAssistService(settings: settings, spendLedger: spendLedger)
        // ContextBundleBuilder requires LinkIndexManager; if unavailable, the bundle
        // will always return just the focus artifact (graceful degradation).
        let bundleBuilder = ContextBundleBuilder(
            linkIndex: linkIndexManager,
            workspaceURL: store.workspaceURL
        )
        return AIAssistViewModel(service: service, bundleBuilder: bundleBuilder)
    }
}
