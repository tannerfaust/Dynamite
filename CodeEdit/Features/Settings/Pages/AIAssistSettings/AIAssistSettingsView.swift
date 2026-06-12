// swiftlint:disable identifier_name line_length
//
//  AIAssistSettingsView.swift
//  CodeEdit
//
//  ADR-0007 §2, §4 — Settings pane for AIAssist provider, keys, budgets, and spend.
//

import SwiftUI

struct AIAssistSettingsView: View {

    @ObservedObject private var settings: Settings = .shared

    @State private var keyInputs: [AIProviderID: String] = [:]
    @State private var savedKeys: [AIProviderID: Bool]  = [:]
    @State private var saveError: String?

    var body: some View {
        Form {
            Section("Provider") {
                providerPicker
            }

            Section("API Keys") {
                ForEach(AIProviderID.allCases, id: \.self) { provider in
                    apiKeyRow(provider: provider)
                }
            }

            Section("Cost Guardrails") {
                budgetSection
            }

            Section("Spend") {
                spendSection
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshKeyStatus() }
    }

    // MARK: - Provider Picker

    private var providerPicker: some View {
        Picker("Active provider", selection: $settings.preferences.aiAssist.activeProvider) {
            Text("None (disabled)").tag(Optional<AIProviderID>.none)
            ForEach(AIProviderID.allCases, id: \.self) { p in
                Text(p.displayName).tag(Optional(p))
            }
        }
    }

    // MARK: - API Key Rows

    private func apiKeyRow(provider: AIProviderID) -> some View {
        HStack {
            Text(provider.displayName)
                .frame(width: 160, alignment: .leading)

            SecureField("Paste API key…", text: Binding(
                get: { keyInputs[provider] ?? "" },
                set: { keyInputs[provider] = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            if savedKeys[provider] == true && (keyInputs[provider]?.isEmpty ?? true) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .help("Key saved in Keychain")
            }

            Button("Save") {
                saveKey(for: provider)
            }
            .disabled(keyInputs[provider]?.isEmpty ?? true)

            if savedKeys[provider] == true {
                Button("Remove", role: .destructive) {
                    removeKey(for: provider)
                }
            }
        }
    }

    // MARK: - Budget Section

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly spend cap (USD)")
            HStack {
                Slider(
                    value: $settings.preferences.aiAssist.monthlyCapUSD,
                    in: 1...100,
                    step: 1
                )
                Text(String(format: "$%.0f", settings.preferences.aiAssist.monthlyCapUSD))
                    .monospacedDigit()
                    .frame(width: 40)
            }

            ForEach(AssistOperation.allCases, id: \.self) { operation in
                operationBudgetRow(operation)
            }
        }
    }

    private func operationBudgetRow(_ operation: AssistOperation) -> some View {
        let defaultBudget = TokenBudget.default(for: operation)
        let inputCap  = settings.preferences.aiAssist.inputTokenCaps[operation.rawValue]  ?? defaultBudget.maxInputTokens
        let outputCap = settings.preferences.aiAssist.outputTokenCaps[operation.rawValue] ?? defaultBudget.maxOutputTokens
        return HStack {
            Text(operation.rawValue.capitalized)
                .frame(width: 100, alignment: .leading)
            Text("In: \(inputCap / 1000)k  Out: \(outputCap / 1000)k")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Spend Section

    @ViewBuilder private var spendSection: some View {
        // Spend data access requires a workspace context; show a placeholder here.
        Text("Spend details are available per-project in the workspace status bar.")
            .foregroundStyle(.secondary)
            .font(.callout)
    }

    // MARK: - Key Management

    private func refreshKeyStatus() {
        for provider in AIProviderID.allCases {
            savedKeys[provider] = AIKeychainStore.hasKey(for: provider)
        }
    }

    private func saveKey(for provider: AIProviderID) {
        guard let key = keyInputs[provider], !key.isEmpty else { return }
        do {
            try AIKeychainStore.save(key: key, for: provider)
            keyInputs[provider] = ""
            savedKeys[provider] = true
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func removeKey(for provider: AIProviderID) {
        try? AIKeychainStore.delete(for: provider)
        savedKeys[provider] = false
    }
}
