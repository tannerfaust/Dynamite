//
//  AnthropicProvider.swift
//  CodeEdit
//
//  ADR-0007 §2 — Anthropic (Claude) streaming provider via URLSession SSE.
//  No SDK dependency: raw HTTP to api.anthropic.com/v1/messages.
//

import Foundation

final class AnthropicProvider: AIProvider {
    let id: AIProviderID = .anthropic
    let displayName = "Anthropic (Claude)"

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
                    guard let apiKey = AIKeychainStore.load(for: .anthropic), !apiKey.isEmpty else {
                        throw AIAssistError.noAPIKey(provider: .anthropic)
                    }

                    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    // NOTE: No `tools` key — ADR-0007 §5 no-agent rule.
                    let body: [String: Any] = [
                        "model": modelID,
                        "max_tokens": maxOutputTokens,
                        "stream": true,
                        "system": systemPrompt,
                        "messages": [["role": "user", "content": userMessage]]
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

                        let type = obj["type"] as? String ?? ""

                        if type == "content_block_delta",
                           let delta = obj["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            continuation.yield(.token(text))
                        } else if type == "message_delta",
                                  let usage = obj["usage"] as? [String: Any] {
                            outputTokens = usage["output_tokens"] as? Int ?? outputTokens
                        } else if type == "message_start",
                                  let message = obj["message"] as? [String: Any],
                                  let usage = message["usage"] as? [String: Any] {
                            inputTokens = usage["input_tokens"] as? Int ?? 0
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
        ModelPriceTable.anthropic(modelID: modelID)
    }
}
