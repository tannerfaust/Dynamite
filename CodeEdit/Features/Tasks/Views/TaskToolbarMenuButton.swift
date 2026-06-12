//
//  TaskToolbarMenuButton.swift
//  CodeEdit
//

import SwiftUI

/// Compact `>>` toolbar control that always exposes Run and Stop in its menu.
struct TaskToolbarMenuButton: View {
    @Environment(\.controlActiveState)
    private var activeState

    @ObservedObject var taskManager: TaskManager
    @EnvironmentObject var workspace: WorkspaceDocument

    private var utilityAreaCollapsed: Bool {
        workspace.utilityAreaModel?.isCollapsed ?? true
    }

    private var isRunning: Bool {
        guard let selectedID = taskManager.selectedTaskID else { return false }
        return taskManager.activeTasks[selectedID]?.status == .running
    }

    var body: some View {
        Menu {
            Button {
                startTask()
            } label: {
                Label("Run", systemImage: "play.fill")
            }

            Button {
                taskManager.terminateActiveTask()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(!isRunning)
        } label: {
            Image(systemName: "chevron.compact.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .scaleEffect(x: 1.3, y: 1.0)
                .frame(width: 28, height: 22)
                .opacity(activeState == .inactive ? 0.5 : 1.0)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Run or stop the selected task")
        .accessibilityLabel("Task Controls")
        .accessibilityIdentifier("TaskToolbarMenu")
    }

    private func startTask() {
        taskManager.executeActiveTask()
        if utilityAreaCollapsed {
            CommandManager.shared.executeCommand("open.drawer")
        }
        workspace.utilityAreaModel?.selectedTab = .debugConsole
        taskManager.taskShowingOutput = taskManager.selectedTaskID
    }
}
