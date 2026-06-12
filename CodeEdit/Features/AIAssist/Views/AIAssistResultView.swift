// swiftlint:disable identifier_name
//
//  AIAssistResultView.swift
//  CodeEdit
//
//  ADR-0007 §6 — result sheet shown after an AI Assist call.
//

import SwiftUI

/// Full result sheet for all three AIAssist operations.
///
/// - **Draft / Refine**: scrollable streamed text + accept/replace per section controls.
/// - **Cross-check**: discrepancy list.
/// - All: grounding source chips at the bottom. Ungrounded outputs are visually labelled.
struct AIAssistResultView: View {

    @ObservedObject var viewModel: AIAssistViewModel
    let artifact: ProductArtifact
    var onAccept: ((String) -> Void)?
    var onNavigateToNode: ((String) -> Void)?

    @State private var dismissedDiscrepancies: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.isStreaming {
                        streamingIndicator
                    }

                    operationContent

                    groundingSection
                }
                .padding(24)
            }
            .navigationTitle(operationTitle)
            .toolbar { toolbarItems }
        }
        .frame(minWidth: 520, minHeight: 400)
    }

    // MARK: - Operation Content

    @ViewBuilder private var operationContent: some View {
        if viewModel.activeOperation == .crossCheck {
            crossCheckContent
        } else {
            draftRefineContent
        }
    }

    // MARK: - Draft / Refine Content

    private var draftRefineContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.streamedText.isEmpty {
                Text(viewModel.streamedText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let result = viewModel.result, !viewModel.isStreaming {
                acceptControls(text: result.text)
            }
        }
    }

    // MARK: - Cross-check Content

    @ViewBuilder private var crossCheckContent: some View {
        if let result = viewModel.result, let discrepancies = result.discrepancies {
            if discrepancies.isEmpty {
                Label("No discrepancies found", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                let visible = discrepancies.filter { !dismissedDiscrepancies.contains($0.id) }
                VStack(spacing: 10) {
                    ForEach(visible) { discrepancy in
                        DiscrepancyRowView(
                            discrepancy: discrepancy,
                            onNavigateToEvidence: { ref in
                                onNavigateToNode?(ref.id)
                            },
                            onDismiss: { d in
                                dismissedDiscrepancies.insert(d.id)
                            },
                            onFlag: { _ in
                                // TODO: Phase 2 — create a flagged link edge
                            }
                        )
                    }
                }
            }
        } else if viewModel.isStreaming {
            // Still streaming the JSON response.
            Text("Analysing…")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Grounding Section

    @ViewBuilder private var groundingSection: some View {
        if let result = viewModel.result {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if result.groundingRefs.isEmpty {
                    Label("Ungrounded — no linked nodes were included", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Grounded on")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(result.groundingRefs, id: \.id) { ref in
                                GroundingChipView(ref: ref) { r in
                                    onNavigateToNode?(r.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Accept Controls

    private func acceptControls(text: String) -> some View {
        HStack {
            Button("Accept") {
                onAccept?(text)
                viewModel.showingResult = false
            }
            .buttonStyle(.borderedProminent)

            Button("Discard") {
                viewModel.showingResult = false
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
                viewModel.cancel()
                viewModel.showingResult = false
            }
        }
        if viewModel.isStreaming {
            ToolbarItem(placement: .confirmationAction) {
                Button("Stop") { viewModel.cancel() }
            }
        }
    }

    // MARK: - Streaming Indicator

    private var streamingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Generating…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var operationTitle: String {
        switch viewModel.activeOperation {
        case .draft:      return "AI Draft"
        case .refine:     return "AI Refine"
        case .crossCheck: return "Cross-check"
        default:          return "AI Assist"
        }
    }
}
