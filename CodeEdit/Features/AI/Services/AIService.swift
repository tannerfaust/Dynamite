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

        if provider != "Mock Test Drive" && provider != "Ollama" {
            guard !apiKey.isEmpty else {
                throw NSError(domain: "AIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key is missing. Please set your API Key in Settings -> AI Assistant."])
            }
        }

        // Format the prompt with file context if available
        var formattedPrompt = ""
        if let content = activeFileContent, let path = activeFilePath {
            formattedPrompt += "Context from file '\(path)':\n```\n\(content)\n```\n\n"
        }
        formattedPrompt += prompt

        switch provider {
        case "Mock Test Drive":
            return try await callMockAPI(prompt: prompt, activeFileContent: activeFileContent, activeFilePath: activeFilePath)
        case "Ollama":
            return try await callOllamaAPI(model: model, prompt: formattedPrompt)
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

    // MARK: - Mock Test Drive API
    private func callMockAPI(prompt: String, activeFileContent: String?, activeFilePath: String?) async throws -> String {
        // Sleep briefly to simulate loading state
        try await Task.sleep(nanoseconds: 600_000_000)

        let lowerPrompt = prompt.lowercased()

        if let path = activeFilePath {
            if lowerPrompt.contains("explain") || lowerPrompt.contains("what does") || lowerPrompt.contains("read") {
                var fileSummary = "I've analyzed the active file: `\(path)`.\n\n"
                if let content = activeFileContent {
                    let lines = content.components(separatedBy: .newlines)
                    fileSummary += "It contains \(lines.count) lines of code. "
                    
                    // Identify classes/structs/functions
                    let structs = lines.filter { $0.contains("struct ") }.compactMap { $0.components(separatedBy: "struct ").last?.components(separatedBy: " ").first?.components(separatedBy: ":").first }
                    let classes = lines.filter { $0.contains("class ") }.compactMap { $0.components(separatedBy: "class ").last?.components(separatedBy: " ").first?.components(separatedBy: ":").first }
                    let funcs = lines.filter { $0.contains("func ") }.compactMap { $0.components(separatedBy: "func ").last?.components(separatedBy: " ").first?.components(separatedBy: "(").first }
                    
                    if !classes.isEmpty {
                        fileSummary += "I found classes like: `\(classes.joined(separator: "`, `"))`.\n"
                    }
                    if !structs.isEmpty {
                        fileSummary += "I found structs like: `\(structs.joined(separator: "`, `"))`.\n"
                    }
                    if !funcs.isEmpty {
                        let sampleFuncs = Array(funcs.prefix(5))
                        fileSummary += "Key methods/functions defined include:\n"
                        for fn in sampleFuncs {
                            fileSummary += "- `\(fn.trimmingCharacters(in: .whitespacesAndNewlines))`\n"
                        }
                    }
                }
                fileSummary += "\nWhat specific parts would you like me to explain or refactor?"
                return fileSummary
            }
        }

        if lowerPrompt.contains("hello") || lowerPrompt.contains("hi") || lowerPrompt.contains("hey") {
            return "Hello! I am your Dynamite AI assistant. I am currently running in **Mock Test Drive Mode**, which responds offline without needing any API keys. \n\nYou can ask me to explain code, suggest changes, or write mock structures. To use a real model, switch your provider to Google Gemini, Anthropic Claude, or OpenAI in settings."
        }
        
        if lowerPrompt.contains("write") || lowerPrompt.contains("create") || lowerPrompt.contains("code") || lowerPrompt.contains("swift") {
            return """
Here is a Swift code example based on your request:

```swift
import SwiftUI

struct ExampleComponent: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(.purple)
            Text("Hello from Dynamite!")
                .font(.headline)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
```

Let me know if you want me to customize this component or explain how it works!
"""
        }

        return """
Thanks for asking! I'm running in **Mock Test Drive** mode. Here is a developer suggestion for your prompt:

- To test with real AI responses, get a free key from Google AI Studio and configure Gemini.
- Alternatively, run `ollama` locally and select the Ollama provider.

Your query: *"\(prompt)"*

\(activeFilePath != nil ? "Currently viewing: `\(activeFilePath!)`" : "No active file opened.")
"""
    }

    // MARK: - Ollama API
    private func callOllamaAPI(model: String, prompt: String) async throws -> String {
        let url = URL(string: "http://localhost:11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response from local Ollama"])
        }

        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ollama Error: \(errorMsg)"])
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["response"] as? String {
            return text
        }

        throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Ollama response JSON"])
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
