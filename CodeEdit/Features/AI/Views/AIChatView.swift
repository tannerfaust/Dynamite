//
//  AIChatView.swift
//  CodeEdit
//
//  Created by Antigravity on 03/06/2026.
//

import SwiftUI

struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()

    enum MessageRole {
        case user
        case assistant
        case systemError
    }
}

struct AIChatView: View {
    @EnvironmentObject var workspace: WorkspaceDocument

    @State private var messages: [AIChatMessage] = []
    @State private var inputPrompt: String = ""
    @State private var isLoading: Bool = false
    @State private var includeContext: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header: Active File Context Info
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                if let activeTab = workspace.editorManager?.activeEditor.selectedTab {
                    Text(activeTab.file.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                } else {
                    Text("No file open")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Toggle(isOn: $includeContext) {
                    Text("Use Context")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)
                .disabled(workspace.editorManager?.activeEditor.selectedTab == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            
            Divider()

            // Chat Message List
            if messages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundColor(.purple)
                        .padding(.top, 40)
                    Text("AI Chat Assistant")
                        .font(.headline)
                    Text("Ask questions about your code, explain complex logic, or request refactoring examples. The AI has access to your active file content.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                    
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { msg in
                                chatMessageBubble(msg)
                                    .id(msg.id)
                            }
                            
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Generating response...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages) { _ in
                        if let lastMsg = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMsg.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()

            // Input panel
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask anything...", text: $inputPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onSubmit {
                        if !inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sendMessage()
                        }
                    }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        }
        .background(
            EffectView(.hudWindow, blendingMode: .withinWindow)
                .opacity(0.3)
        )
    }

    // Message Row Bubble
    @ViewBuilder
    private func chatMessageBubble(_ message: AIChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : (message.role == .systemError ? "Error" : "Assistant"))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .textSelection(.enabled)
                    .font(.system(.body, design: message.role == .user ? .default : .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleBackgroundColor(message.role))
                    .foregroundColor(bubbleForegroundColor(message.role))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(bubbleBorderColor(message.role), lineWidth: 1)
                    )
            }
            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role != .user {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
    }

    // Colors helpers matching glassmorphic theme
    private func bubbleBackgroundColor(_ role: AIChatMessage.MessageRole) -> Color {
        switch role {
        case .user:
            return Color.blue.opacity(0.2)
        case .assistant:
            return Color(NSColor.controlBackgroundColor).opacity(0.6)
        case .systemError:
            return Color.red.opacity(0.15)
        }
    }

    private func bubbleForegroundColor(_ role: AIChatMessage.MessageRole) -> Color {
        switch role {
        case .systemError:
            return .red
        default:
            return .primary
        }
    }

    private func bubbleBorderColor(_ role: AIChatMessage.MessageRole) -> Color {
        switch role {
        case .user:
            return Color.blue.opacity(0.3)
        case .assistant:
            return Color.secondary.opacity(0.1)
        case .systemError:
            return Color.red.opacity(0.3)
        }
    }

    // Send Message Logic
    private func sendMessage() {
        let trimmedPrompt = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        // Append user message
        let userMsg = AIChatMessage(role: .user, content: trimmedPrompt)
        messages.append(userMsg)
        inputPrompt = ""
        isLoading = true

        // Capture current file context if applicable
        var fileContent: String? = nil
        var filePath: String? = nil
        
        if includeContext, let activeTab = workspace.editorManager?.activeEditor.selectedTab {
            fileContent = activeTab.file.fileDocument?.content?.string
            filePath = activeTab.file.url.lastPathComponent
        }

        Task {
            do {
                let response = try await AIService.shared.sendMessage(
                    prompt: trimmedPrompt,
                    activeFileContent: fileContent,
                    activeFilePath: filePath
                )
                
                await MainActor.run {
                    messages.append(AIChatMessage(role: .assistant, content: response))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(AIChatMessage(role: .systemError, content: error.localizedDescription))
                    isLoading = false
                }
            }
        }
    }
}
