//
//  AIService.swift
//  CodeEdit
//
//  Created by Antigravity on 03/06/2026.
//

import Foundation

class AIService {
    static let shared = AIService()

    private init() {}

    /// Executes a request to the configured AI API.
    /// - Parameters:
    ///   - prompt: The user query.
    ///   - activeFileContent: Code text of the current active document.
    ///   - activeFilePath: Relative or absolute path of the current active document.
    /// - Returns: The response string from the AI model.
    func sendMessage(prompt: String, activeFileContent: String? = nil, activeFilePath: String? = nil) async throws -> String {
        let prefs = Settings.shared.preferences.ai
        let provider = prefs.provider
        let apiKey = prefs.apiKey
        let model = prefs.model

        guard !apiKey.isEmpty else {
            throw NSError(domain: "AIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key is missing. Please set your API Key in Settings -> AI Assistant."])
        }

        // Format the prompt with file context if available
        var formattedPrompt = ""
        if let content = activeFileContent, let path = activeFilePath {
            formattedPrompt += "Context from file '\(path)':\n```\n\(content)\n```\n\n"
        }
        formattedPrompt += prompt

        switch provider {
        case "Claude":
            return try await callClaudeAPI(apiKey: apiKey, model: model, prompt: formattedPrompt)
        case "Gemini":
            return try await callGeminiAPI(apiKey: apiKey, model: model, prompt: formattedPrompt)
        case "OpenAI":
            return try await callOpenAIAPI(apiKey: apiKey, model: model, prompt: formattedPrompt)
        default:
            throw NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unknown API Provider: \(provider)"])
        }
    }

    // MARK: - Claude API
    private func callClaudeAPI(apiKey: String, model: String, prompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }

        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Anthropic Error: \(errorMsg)"])
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let contentArray = json["content"] as? [[String: Any]],
           let firstContent = contentArray.first,
           let text = firstContent["text"] as? String {
            return text
        }

        throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Anthropic response JSON"])
    }

    // MARK: - Gemini API
    private func callGeminiAPI(apiKey: String, model: String, prompt: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL generated for Gemini"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }

        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini Error: \(errorMsg)"])
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            return text
        }

        throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response JSON"])
    }

    // MARK: - OpenAI API
    private func callOpenAIAPI(apiKey: String, model: String, prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }

        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI Error: \(errorMsg)"])
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let text = message["content"] as? String {
            return text
        }

        throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI response JSON"])
    }
}
