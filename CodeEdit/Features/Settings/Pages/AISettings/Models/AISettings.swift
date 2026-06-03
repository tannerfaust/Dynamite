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

        /// Selected API provider ("Claude", "Gemini", "OpenAI")
        var provider: String = "Claude"

        /// Selected model name
        var model: String = "claude-3-5-sonnet-20241022"

        /// Secure API Key
        var apiKey: String = ""

        /// Default initializer
        init() {}

        /// Explicit decoder init for setting default values when key is not present in `JSON`
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.provider = try container.decodeIfPresent(
                String.self,
                forKey: .provider
            ) ?? "Claude"

            self.model = try container.decodeIfPresent(
                String.self,
                forKey: .model
            ) ?? "claude-3-5-sonnet-20241022"

            self.apiKey = try container.decodeIfPresent(
                String.self,
                forKey: .apiKey
            ) ?? ""
        }
    }
}
