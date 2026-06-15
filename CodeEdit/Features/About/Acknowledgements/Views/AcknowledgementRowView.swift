//
//  AcknowledgementsRowView.swift
//  CodeEdit
//
//  Created by Austin Condiff on 1/19/23.
//

import SwiftUI

struct AcknowledgementRowView: View {
    @Environment(\.openURL)
    private var openURL

    let acknowledgement: AcknowledgementDependency

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(acknowledgement.name)
                    .font(.body)

                if !detailText.isEmpty {
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let licenseURL = acknowledgement.licenseURL {
                Button {
                    openURL(licenseURL)
                } label: {
                    Text("License")
                }
                .buttonStyle(.link)
            }

            Button {
                openURL(acknowledgement.repositoryURL)
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private var detailText: String {
        [
            acknowledgement.version == "-" ? nil : acknowledgement.version,
            acknowledgement.licenseName
        ]
            .compactMap { $0 }
            .joined(separator: " | ")
    }
}

struct AcknowledgementsRowView_Previews: PreviewProvider {
    static var previews: some View {
        AcknowledgementRowView(acknowledgement: AcknowledgementDependency(
            name: "Test",
            repositoryLink: "https://www.test.com/",
            version: "-"
        ))
    }
}
