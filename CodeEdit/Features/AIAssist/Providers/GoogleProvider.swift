//
//  GoogleProvider.swift
//  CodeEdit
//
//  ADR-0007 §2 — Google (Gemini) streaming provider via URLSession SSE.
//  No SDK dependency: raw HTTP to generativelanguage.googleapis.com.
//

import Foundation

final class GoogleProvider: AIProvider {
    let id: AIProviderID = .google
    let displayName = "Google (Gemini)"

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
                    guard let apiKey = AIKeychainStore.load(for: .google), !apiKey.isEmpty else {
                        throw AIAssistError.noAPIKey(provider: .google)
                    }

                    let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):streamGenerateContent?alt=sse&key=\(apiKey)"
                    guard let url = URL(string: urlString) else {
                        throw AIAssistError.providerError(message: "Invalid URL")
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    // NOTE: No `tools` key — ADR-0007 §5 no-agent rule.
                    let body: [String: Any] = [
                        "system_instruction": ["parts": [["text": systemPrompt]]],
                        "contents": [["role": "user", "parts": [["text": userMessage]]]],
                        "generationConfig": ["maxOutputTokens": maxOutputTokens]
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

                        guard
                            let data = json.data(using: .utf8),
                            let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        if let candidates = obj["candidates"] as? [[String: Any]],
                           let content    = candidates.first?["content"] as? [String: Any],
                           let parts      = content["parts"] as? [[String: Any]],
                           let text       = parts.first?["text"] as? String {
                            continuation.yield(.token(text))
                        }
                        if let meta = obj["usageMetadata"] as? [String: Any] {
                            inputTokens  = meta["promptTokenCount"]     as? Int ?? inputTokens
                            outputTokens = meta["candidatesTokenCount"] as? Int ?? outputTokens
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
        ModelPriceTable.google(modelID: modelID)
    }
}
