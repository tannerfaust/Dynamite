//
//  FrontMatterHeaderView.swift
//  CodeEdit
//

import SwiftUI

/// Editable header form displaying front-matter fields above the markdown body.
///
/// Shows kind badge (read-only), title, status picker, tags, created date, and
/// a collapsible links section — rendering front-matter as a first-class form
/// rather than raw YAML.
struct FrontMatterHeaderView: View {
    @Binding var artifact: ProductArtifact
    var onSave: () -> Void

    @State private var linksExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
            metaRow
            if linksExpanded || !artifact.links.isEmpty {
                linksSection
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Title

    private var titleRow: some View {
        TextField("Untitled", text: $artifact.title)
            .font(.system(size: 22, weight: .semibold))
            .textFieldStyle(.plain)
            .onSubmit { onSave() }
    }

    // MARK: - Meta row

    private var metaRow: some View {
        HStack(spacing: 10) {
            KindBadge(kind: artifact.kind, kindString: artifact.kindString, size: .regular)
            statusPicker
            Divider().frame(height: 14)
            Text(artifact.created)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            tagsField
            linkToggle
        }
        .padding(.top, 8)
    }

    private var statusPicker: some View {
        let statuses = artifact.kind?.statuses ?? ["draft", "active", "superseded", "archived"]
        return Picker("", selection: $artifact.status) {
            ForEach(statuses, id: \.self) { status in Text(status).tag(status) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .font(.caption)
        .frame(maxWidth: 120)
        .onChange(of: artifact.status) { _, _ in onSave() }
    }

    private var tagsField: some View {
        let binding = Binding<String>(
            get: { artifact.tags.joined(separator: ", ") },
            set: { raw in
                artifact.tags = raw
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
        return TextField("tags", text: binding)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textFieldStyle(.plain)
            .frame(maxWidth: 140)
            .onSubmit { onSave() }
    }

    private var linkToggle: some View {
        let count = artifact.links.count
        let label = count == 0 ? "Links" : "\(count) link\(count == 1 ? "" : "s")"
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { linksExpanded.toggle() }
        } label: {
            Label(label, systemImage: linksExpanded ? "chevron.up" : "link")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Links section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().padding(.top, 6)
            ForEach($artifact.links) { $link in
                linkRow(link: $link)
            }
            addLinkButton
        }
        .padding(.bottom, 6)
    }

    private func linkRow(link: Binding<ProductArtifact.ArtifactLink>) -> some View {
        HStack(spacing: 6) {
            Picker("", selection: link.rel) {
                ForEach(["implements", "validates", "contradicts",
                         "supersedes", "derived-from", "relates-to"], id: \.self) { rel in
                    Text(rel).tag(rel)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 120)
            .font(.caption)

            TextField("node-id", text: link.to)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 130)

            TextField("label (optional)", text: Binding(
                get: { link.wrappedValue.label ?? "" },
                set: { link.wrappedValue.label = $0.isEmpty ? nil : $0 }
            ))
            .font(.caption)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 180)
            .onSubmit { onSave() }

            Button {
                artifact.links.removeAll { $0.id == link.wrappedValue.id }
                onSave()
            } label: {
                Image(systemName: "minus.circle").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private var addLinkButton: some View {
        Button {
            artifact.links.append(.init(rel: "relates-to", to: "", label: nil))
            linksExpanded = true
        } label: {
            Label("Add Link", systemImage: "plus")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}
