//
//  AISettingsView.swift
//  CodeEdit
//
//  Created by Antigravity on 03/06/2026.
//

import SwiftUI

struct AISettingsView: View {
    @AppSettings(\.ai)
    var settings

    var body: some View {
        SettingsForm {
            Section {
                Picker("API Provider", selection: $settings.provider) {
                    Text("Free Test Drive (Mock AI)").tag("Mock Test Drive")
                    Text("Ollama (Local)").tag("Ollama")
                    Text("Google Gemini (Free/Paid Tier)").tag("Gemini")
                    Text("Anthropic Claude").tag("Claude")
                    Text("OpenAI").tag("OpenAI")
                }
                .onChange(of: settings.provider) { _, newValue in
                    switch newValue {
                    case "Mock Test Drive":
                        settings.model = "mock-assistant"
                        settings.apiKey = "free-test-drive"
                    case "Ollama":
                        settings.model = "llama3"
                        settings.apiKey = "local-no-key"
                    case "Claude":
                        settings.model = "claude-3-5-sonnet-20241022"
                        settings.apiKey = ""
                    case "Gemini":
                        settings.model = "gemini-2.5-flash"
                        settings.apiKey = ""
                    case "OpenAI":
                        settings.model = "gpt-4o"
                        settings.apiKey = ""
                    default:
                        break
                    }
                }

                TextField("Model Name", text: $settings.model)

                SecureField("API Key", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your API configuration is saved locally in your Dynamite settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if settings.provider == "Mock Test Drive" {
                        Text("Mock mode responds instantly offline and does not require an API key.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if settings.provider == "Ollama" {
                        Link("Download Ollama locally (requires server running on port 11434)", 
                             destination: URL(string: "https://ollama.com/")!)
                            .font(.caption)
                    } else if settings.provider == "Gemini" {
                        Link("Get a 100% FREE Gemini API Key from Google AI Studio", 
                             destination: URL(string: "https://aistudio.google.com/")!)
                            .font(.caption)
                            .fontWeight(.semibold)
                    } else if settings.provider == "Claude" {
                        Link("Get a Claude API Key from Anthropic Console", 
                             destination: URL(string: "https://console.anthropic.com/")!)
                            .font(.caption)
                    } else if settings.provider == "OpenAI" {
                        Link("Get an OpenAI API Key from OpenAI Platform", 
                             destination: URL(string: "https://platform.openai.com/")!)
                            .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
