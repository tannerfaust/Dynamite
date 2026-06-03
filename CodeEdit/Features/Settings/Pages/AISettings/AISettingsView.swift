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
                    Text("Anthropic Claude").tag("Claude")
                    Text("Google Gemini").tag("Gemini")
                    Text("OpenAI").tag("OpenAI")
                }
                .onChange(of: settings.provider) { _, newValue in
                    // Automatically update default model for chosen provider
                    switch newValue {
                    case "Claude":
                        settings.model = "claude-3-5-sonnet-20241022"
                    case "Gemini":
                        settings.model = "gemini-1.5-pro"
                    case "OpenAI":
                        settings.model = "gpt-4o"
                    default:
                        break
                    }
                }

                TextField("Model Name", text: $settings.model)

                SecureField("API Key", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your API key is stored locally in your Dynamite settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if settings.provider == "Claude" {
                        Link("Get a Claude API Key from Anthropic Console", 
                             destination: URL(string: "https://console.anthropic.com/")!)
                            .font(.caption)
                    } else if settings.provider == "Gemini" {
                        Link("Get a Gemini API Key from Google AI Studio", 
                             destination: URL(string: "https://aistudio.google.com/")!)
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
