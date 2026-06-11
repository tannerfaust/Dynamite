//
//  OpenAIProvider.swift
//  CodeEdit
//
//  ADR-0007 §2 — OpenAI (GPT) streaming provider via URLSession SSE.
//  No SDK dependency: raw HTTP to api.openai.com/v1/chat/completions.
//

import Foundation

final class OpenAIProvider: AIProvider {
    let id: AIProviderID = .openAI
    let displayName = "OpenAI (GPT)"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func stream(
        systemPrompt: String,
        userMessage: String,
        modelID: String,
        maxOutputTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = AIKeychainStore.load(for: .openAI), !apiKey.isEmpty else {
                        throw AIAssistError.noAPIKey(provider: .openAI)
                    }

                    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    // NOTE: No `tools` / `functions` key — ADR-0007 §5.
                    let body: [String: Any] = [
                        "model": modelID,
                        "max_completion_tokens": maxOutputTokens,
                        "stream": true,
                        "stream_options": ["include_usage": true],
                        "messages": [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user",   "content": userMessage]
                        ]
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIAssistError.providerError(message: "Non-HTTP response")
                    }
                    guard http.statusCode == 200 else {
                        throw AIAssistError.providerError(message: "HTTP \(http.statusCode)")
                    }

                    var inputTokens = 0
                    var outputTokens = 0

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        if json == "[DONE]" { break }

                        guard
                            let data = json.data(using: .utf8),
                            let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        if let choices = obj["choices"] as? [[String: Any]],
                           let delta   = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            continuation.yield(.token(content))
                        }
                        if let usage = obj["usage"] as? [String: Any] {
                            inputTokens  = usage["prompt_tokens"]     as? Int ?? inputTokens
                            outputTokens = usage["completion_tokens"] as? Int ?? outputTokens
                        }
                    }

                    continuation.yield(.usage(inputTokens: inputTokens, outputTokens: outputTokens, modelID: modelID))
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func costPer1kTokens(modelID: String) -> (input: Double, output: Double) {
        ModelPriceTable.openAI(modelID: modelID)
    }
}
