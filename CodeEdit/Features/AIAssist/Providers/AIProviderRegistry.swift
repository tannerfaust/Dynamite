//
//  AIProviderRegistry.swift
//  CodeEdit
//
//  ADR-0007 §2 — resolves the active provider from settings.
//

import Foundation

/// Returns the active `AIProvider` implementation based on `AIAssistSettings`.
enum AIProviderRegistry {

    static func provider(for settings: AIAssistSettings) throws -> AIProvider {
        guard let providerID = settings.activeProvider else {
            throw AIAssistError.noProviderConfigured
        }
        guard AIKeychainStore.hasKey(for: providerID) else {
            throw AIAssistError.noAPIKey(provider: providerID)
        }
        return makeProvider(for: providerID)
    }

    static func makeProvider(for id: AIProviderID) -> AIProvider {
        switch id {
        case .anthropic: return AnthropicProvider()
        case .openAI:    return OpenAIProvider()
        case .google:    return GoogleProvider()
        }
    }
}
