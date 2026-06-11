//
//  ModelPriceTable.swift
//  CodeEdit
//
//  ADR-0007 §4 — bundled, updatable price table (USD per 1 000 tokens).
//  Update this file when providers change pricing; no network fetch needed.
//

import Foundation

enum ModelPriceTable {

    // MARK: - Anthropic

    static func anthropic(modelID: String) -> (input: Double, output: Double) {
        switch modelID {
        case "claude-opus-4-5":    return (input: 15.00, output: 75.00)
        case "claude-sonnet-4-5":  return (input:  3.00, output: 15.00)
        case "claude-haiku-4-5":   return (input:  0.25, output:  1.25)
        case "claude-opus-4":      return (input: 15.00, output: 75.00)
        case "claude-sonnet-4":    return (input:  3.00, output: 15.00)
        case "claude-haiku-4":     return (input:  0.25, output:  1.25)
        default:                   return (input:  3.00, output: 15.00) // conservative fallback
        }
    }

    // MARK: - OpenAI

    static func openAI(modelID: String) -> (input: Double, output: Double) {
        switch modelID {
        case "gpt-4o":             return (input:  2.50, output: 10.00)
        case "gpt-4o-mini":        return (input:  0.15, output:  0.60)
        case "o3":                 return (input: 10.00, output: 40.00)
        case "o4-mini":            return (input:  1.10, output:  4.40)
        default:                   return (input:  2.50, output: 10.00)
        }
    }

    // MARK: - Google

    static func google(modelID: String) -> (input: Double, output: Double) {
        switch modelID {
        case "gemini-2.5-pro":     return (input:  1.25, output: 10.00)
        case "gemini-2.5-flash":   return (input:  0.075, output: 0.30)
        case "gemini-2.0-flash":   return (input:  0.10, output:  0.40)
        default:                   return (input:  1.25, output: 10.00)
        }
    }

    // MARK: - Cost computation

    /// Compute USD cost for a given usage and model.
    static func cost(usage: TokenUsage, provider: AIProviderID) -> Double {
        let rates: (input: Double, output: Double)
        switch provider {
        case .anthropic: rates = anthropic(modelID: usage.modelID)
        case .openAI:    rates = openAI(modelID: usage.modelID)
        case .google:    rates = google(modelID: usage.modelID)
        }
        let inputCost  = Double(usage.inputTokens)  / 1_000.0 * rates.input
        let outputCost = Double(usage.outputTokens) / 1_000.0 * rates.output
        return inputCost + outputCost
    }
}
