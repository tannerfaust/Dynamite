//
//  AISettings.swift
//  CodeEdit
//
//  Created by Antigravity on 03/06/2026.
//

import Foundation

extension SettingsData {
    struct AISettings: Codable, Hashable, SearchableSettingsPage {

        /// The search keys
        var searchKeys: [String] {
            [
                "AI Assistant",
                "API Provider",
                "API Key",
                "Model"
            ]
            .map { NSLocalizedString($0, comment: "") }
        }

        /// Selected API provider ("Mock Test Drive", "Ollama", "Claude", "Gemini", "OpenAI")
        var provider: String = "Mock Test Drive"

        /// Selected model name
        var model: String = "mock-assistant"

        /// Secure API Key
        var apiKey: String = "free-test-drive"

        /// Default initializer
        init() {}

        /// Explicit decoder init for setting default values when key is not present in `JSON`
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.provider = try container.decodeIfPresent(
                String.self,
                forKey: .provider
            ) ?? "Mock Test Drive"

            self.model = try container.decodeIfPresent(
                String.self,
                forKey: .model
            ) ?? "mock-assistant"

            self.apiKey = try container.decodeIfPresent(
                String.self,
                forKey: .apiKey
            ) ?? "free-test-drive"
        }
    }
}
