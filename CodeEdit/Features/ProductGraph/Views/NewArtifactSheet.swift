//
//  NewArtifactSheet.swift
//  CodeEdit
//

import SwiftUI

/// Kind-picker sheet for creating a new product artifact.
///
/// Shows all 23 kinds grouped by category in a scrollable grid.
/// User picks a kind, optionally enters a title, then presses Create.
struct NewArtifactSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    var onCreate: (ArtifactKind, String) -> Void

    @State private var selectedKind: ArtifactKind?
    @State private var title = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            kindGrid
            Divider()
            sheetFooter
        }
        .frame(width: 600, height: 480)
        .background(.windowBackground)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New Artifact")
                .font(.title2.weight(.semibold))
            Text("Choose a kind — Dynamite creates the file in the right folder.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 12)
    }

    // MARK: - Kind grid

    private var kindGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(ArtifactCategory.allCases) { category in
                    categorySection(category)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func categorySection(_ category: ArtifactCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(category.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 148, maximum: 200), spacing: 8)],
                spacing: 8
            ) {
                ForEach(ArtifactKind.allCases.filter { $0.category == category }) { kind in
                    kindCell(kind)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func kindCell(_ kind: ArtifactKind) -> some View {
        let selected = selectedKind == kind
        let accent = Color(nsColor: kind.categoryColor)
        return Button {
            selectedKind = kind
            titleFocused = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 14))
                    .frame(width: 20)
                    .foregroundStyle(selected ? .white : accent)
                Text(kind.displayName)
                    .font(.system(size: 11.5))
                    .lineLimit(2)
                    .foregroundStyle(selected ? .white : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? accent : Color(nsColor: .quaternaryLabelColor).opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack(spacing: 12) {
            TextField("Title (can be renamed later)", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
                .onSubmit { submitIfReady() }
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Create") { submitIfReady() }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedKind == nil)
        }
        .padding(16)
    }

    private func submitIfReady() {
        guard let kind = selectedKind else { return }
        onCreate(kind, title)
        dismiss()
    }
}
