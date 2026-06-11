//
//  AIAssistViewModel.swift
//  CodeEdit
//
//  ADR-0007 §6 — wires the AIAssist toolbar → service → result sheet.
//

import SwiftUI
import Combine

/// View model for the AIAssist toolbar + result panel attached to an artifact editor.
///
/// Lifecycle: one instance per open artifact editor. Injected as `@StateObject` in
/// `ArtifactEditorView`. Owns no conversation state — each call is independent.
@MainActor
final class AIAssistViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isStreaming: Bool = false
    @Published var streamedText: String = ""
    @Published var result: AssistResult?
    @Published var error: AIAssistError?
    @Published var showingResult: Bool = false
    @Published var activeOperation: AssistOperation?
    @Published var userPrompt: String = ""
    @Published var costEstimate: CostEstimate?

    // MARK: - Dependencies

    private let service: AIAssistService
    private let bundleBuilder: ContextBundleBuilder
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    init(service: AIAssistService, bundleBuilder: ContextBundleBuilder) {
        self.service       = service
        self.bundleBuilder = bundleBuilder
    }

    // MARK: - Operations

    /// Trigger Draft: generate content for an empty/partial artifact.
    func draft(artifact: ProductArtifact, prompt: String) {
        run(artifact: artifact, operation: .draft, prompt: prompt, selection: nil)
    }

    /// Trigger Refine: improve a text selection per user instruction.
    func refine(artifact: ProductArtifact, prompt: String, selection: String) {
        run(artifact: artifact, operation: .refine, prompt: prompt, selection: selection)
    }

    /// Trigger Cross-check: compare artifact against linked evidence.
    func crossCheck(artifact: ProductArtifact) {
        run(artifact: artifact, operation: .crossCheck, prompt: "", selection: nil)
    }

    /// Cancel a running stream.
    func cancel() {
        streamTask?.cancel()
        isStreaming = false
    }

    // MARK: - Cost Estimate

    func updateEstimate(artifact: ProductArtifact, operation: AssistOperation) {
        Task {
            let settings = Settings.shared.preferences.aiAssist
            let budget = settings.tokenBudget(for: operation)
            let bundle = await bundleBuilder.build(focus: artifact, operation: operation, budget: budget)
            let request = AssistRequest(operation: operation, prompt: "", bundle: bundle, budget: budget)
            costEstimate = service.estimate(request)
        }
    }

    // MARK: - Private

    private func run(artifact: ProductArtifact, operation: AssistOperation, prompt: String, selection: String?) {
        streamTask?.cancel()
        isStreaming   = true
        streamedText  = ""
        result        = nil
        error         = nil
        activeOperation = operation
        showingResult = true

        streamTask = Task {
            let settings = Settings.shared.preferences.aiAssist
            let budget   = settings.tokenBudget(for: operation)
            let bundle   = await bundleBuilder.build(focus: artifact, operation: operation, budget: budget)
            let request  = AssistRequest(operation: operation, prompt: prompt, bundle: bundle, budget: budget, selection: selection)

            do {
                for try await event in service.run(request) {
                    switch event {
                    case .delta(let text):
                        streamedText += text
                    case .usage:
                        break  // handled inside LiveAIAssistService
                    case .done(let r):
                        result     = r
                        isStreaming = false
                    }
                }
            } catch let err as AIAssistError {
                error       = err
                isStreaming = false
            } catch {
                self.error  = .providerError(message: error.localizedDescription)
                isStreaming  = false
            }
        }
    }
}
