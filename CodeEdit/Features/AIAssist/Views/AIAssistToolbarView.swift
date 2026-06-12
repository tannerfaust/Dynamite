//
//  AIAssistToolbarView.swift
//  CodeEdit
//
//  ADR-0007 §6 — compact toolbar with Draft, Refine, Cross-check buttons.
//

import SwiftUI

/// The AIAssist toolbar strip placed at the top of `ArtifactEditorView`.
///
/// Shows three buttons: Draft · Refine · Cross-check.
/// When no API key is configured the buttons are disabled with an explanatory hint.
/// A pre-flight cost estimate badge updates when the focused operation changes.
struct AIAssistToolbarView: View {

    @ObservedObject var viewModel: AIAssistViewModel
    let artifact: ProductArtifact
    /// Callback to pull the current text selection from the editor (for Refine).
    var currentSelection: () -> String

    // MARK: - State

    @State private var showDraftPrompt: Bool = false
    @State private var showRefinePrompt: Bool = false
    @State private var draftPromptText: String = ""
    @State private var refinePromptText: String = ""

    private var isEnabled: Bool {
        Settings.shared.preferences.aiAssist.activeProvider != nil
    }

    private var disabledHint: String {
        "Configure an AI provider in Settings → AI Assist to enable."
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("AI Assist")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Divider().frame(height: 14)

            // Draft
            Button {
                showDraftPrompt = true
            } label: {
                Label("Draft", systemImage: "wand.and.stars")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(!isEnabled)
            .help(isEnabled ? "Draft content for this artifact" : disabledHint)
            .popover(isPresented: $showDraftPrompt) {
                promptPopover(title: "Draft prompt", binding: $draftPromptText) {
                    viewModel.draft(artifact: artifact, prompt: draftPromptText)
                    draftPromptText = ""
                }
            }

            // Refine
            Button {
                showRefinePrompt = true
            } label: {
                Label("Refine", systemImage: "pencil.and.sparkles")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(!isEnabled)
            .help(isEnabled ? "Refine the current selection" : disabledHint)
            .popover(isPresented: $showRefinePrompt) {
                promptPopover(title: "Refinement instruction", binding: $refinePromptText) {
                    viewModel.refine(artifact: artifact, prompt: refinePromptText, selection: currentSelection())
                    refinePromptText = ""
                }
            }

            // Cross-check
            Button {
                viewModel.crossCheck(artifact: artifact)
            } label: {
                Label("Cross-check", systemImage: "checkmark.seal")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(!isEnabled)
            .help(isEnabled ? "Compare claims against linked evidence" : disabledHint)

            // Cost badge
            if let estimate = viewModel.costEstimate {
                costBadge(estimate)
            }

            Spacer()

            // Streaming cancel
            if viewModel.isStreaming {
                Button("Stop") { viewModel.cancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Prompt Popover

    private func promptPopover(title: String, binding: Binding<String>, onSubmit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            TextEditor(text: binding)
                .font(.body)
                .frame(width: 300, height: 80)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
            HStack {
                Spacer()
                Button("Cancel") {}
                    .buttonStyle(.bordered)
                Button("Send") { onSubmit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(binding.wrappedValue.isEmpty)
            }
        }
        .padding(16)
    }

    // MARK: - Cost Badge

    private func costBadge(_ estimate: CostEstimate) -> some View {
        Text(estimate.displayString)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .help("Pre-flight cost estimate for the last operation")
    }
}
