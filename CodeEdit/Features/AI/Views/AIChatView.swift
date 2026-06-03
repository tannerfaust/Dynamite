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
    @State private var glowAnimating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Refined Header: Active File Context Info
            HStack(spacing: 8) {
                if let activeTab = workspace.editorManager?.activeEditor.selectedTab {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 3)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(activeTab.file.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Active Editor Context")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "square.dashed")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("No file open")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Toggle Button for Context with premium look
                Toggle(isOn: $includeContext) {
                    Text("Context")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(includeContext ? .primary : .secondary)
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .disabled(workspace.editorManager?.activeEditor.selectedTab == nil)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Color(NSColor.windowBackgroundColor)
                    .opacity(0.4)
                    .blur(radius: 0.5)
            )
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1),
                alignment: .bottom
            )

            // Chat Message List
            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty {
                        VStack(spacing: 16) {
                            Spacer(minLength: 40)
                            
                            // Beautiful sparkles icon with glowing gradient
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.15), .blue.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .blur(radius: 5)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .blue, .indigo],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            Text("Dynamite AI Assistant")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Ask questions about code, request explanations, or generate clean Swift architectures. Runs with zero key configuration using Mock Test Drive.")
                                .font(.system(size: 11))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                                .padding(.horizontal, 32)
                            
                            Spacer()
                        }
                    } else {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(messages) { msg in
                                chatMessageRow(msg)
                                    .id(msg.id)
                            }
                            
                            if isLoading {
                                HStack(spacing: 8) {
                                    GlowingLoader()
                                        .padding(.leading, 8)
                                    Text("Thinking...")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .id("loading_indicator")
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }
                .onChange(of: messages) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: isLoading) { _, loading in
                    if loading {
                        withAnimation {
                            proxy.scrollTo("loading_indicator", anchor: .bottom)
                        }
                    }
                }
            }

            // Divider separating input
            Divider()

            // Floating premium Input panel
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask Dynamite...", text: $inputPrompt, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .lineLimit(1...5)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .onSubmit {
                            if !inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                sendMessage()
                            }
                        }

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                LinearGradient(
                                    colors: inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [.gray.opacity(0.3)] : [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(8)
                            .shadow(color: inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .clear : .purple.opacity(0.3), radius: 5)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding(12)
                .background(
                    Color(NSColor.windowBackgroundColor)
                        .opacity(0.5)
                )
            }
        }
        .background(
            EffectView(.hudWindow, blendingMode: .withinWindow)
                .opacity(0.4)
                .background(Color.black.opacity(0.05))
        )
    }

    // Scroll to bottom helper
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMsg = messages.last {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                proxy.scrollTo(lastMsg.id, anchor: .bottom)
            }
        }
    }

    // Message Row design with avatar icons
    @ViewBuilder
    private func chatMessageRow(_ message: AIChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role != .user {
                // Assistant Avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(
                        LinearGradient(
                            colors: [.purple, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .purple.opacity(0.3), radius: 3)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 3) {
                // User Avatar and Bubble
                HStack {
                    if message.role == .user {
                        Spacer()
                    }
                    Text(message.role == .user ? "You" : (message.role == .systemError ? "Error" : "Dynamite Assistant"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    if message.role != .user {
                        Spacer()
                    }
                }
                
                HStack {
                    if message.role == .user {
                        Spacer()
                    }
                    
                    Text(message.content)
                        .textSelection(.enabled)
                        .font(.system(size: 12, design: message.role == .user ? .default : .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(bubbleForegroundColor(message.role))
                        .background(
                            Group {
                                if message.role == .user {
                                    // Gorgeous purple-blue gradient bubble
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    // Frosted glass bubble
                                    Color(NSColor.controlBackgroundColor)
                                        .opacity(0.65)
                                }
                            }
                        )
                        .cornerRadius(12)
                        .shadow(color: message.role == .user ? .blue.opacity(0.15) : .black.opacity(0.03), radius: 4, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(bubbleBorderColor(message.role), lineWidth: 1)
                        )
                    
                    if message.role != .user {
                        Spacer()
                    }
                }
            }
            
            if message.role == .user {
                // User Avatar
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 12)
    }

    // Styling Helpers
    private func bubbleForegroundColor(_ role: AIChatMessage.MessageRole) -> Color {
        switch role {
        case .user:
            return .white
        case .systemError:
            return .red
        case .assistant:
            return .primary
        }
    }

    private func bubbleBorderColor(_ role: AIChatMessage.MessageRole) -> Color {
        switch role {
        case .user:
            return Color.blue.opacity(0.1)
        case .assistant:
            return Color.primary.opacity(0.06)
        case .systemError:
            return Color.red.opacity(0.2)
        }
    }

    // Send Message Logic
    private func sendMessage() {
        let trimmedPrompt = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        let userMsg = AIChatMessage(role: .user, content: trimmedPrompt)
        messages.append(userMsg)
        inputPrompt = ""
        isLoading = true

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

// Glowing loader view replacing simple progress view
struct GlowingLoader: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.purple)
                .frame(width: 6, height: 6)
                .scaleEffect(isAnimating ? 1.4 : 0.8)
                .opacity(isAnimating ? 0.3 : 1.0)
            Circle()
                .fill(Color.indigo)
                .frame(width: 6, height: 6)
                .scaleEffect(isAnimating ? 1.4 : 0.8)
                .opacity(isAnimating ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2), value: isAnimating)
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .scaleEffect(isAnimating ? 1.4 : 0.8)
                .opacity(isAnimating ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.4), value: isAnimating)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(), {
                isAnimating = true
            })
        }
    }
}
