//
//  FontPicker.swift
//  CodeEdit
//

import SwiftUI

struct FontPicker: View {
    var title: String
    @Binding var selectedFontName: String
    @State private var recentFonts: [String]
    @State private var fontFamilyNames: [String] = []

    init(title: String, selectedFontName: Binding<String>) {
        self.title = title
        self._selectedFontName = selectedFontName
        self.recentFonts = UserDefaults.standard.stringArray(forKey: "recentProportionalFonts") ?? []
    }

    var body: some View {
        Picker(selection: $selectedFontName, label: Text(title)) {
            Text("System Font")
                .font(Font(NSFont.systemFont(ofSize: 13.5)))
                .tag("System")

            if !recentFonts.isEmpty {
                Divider()
                ForEach(recentFonts, id: \.self) { fontFamilyName in
                    Text(fontFamilyName)
                        .font(.custom(fontFamilyName, size: 13.5))
                        .tag(fontFamilyName)
                }
            }

            if !fontFamilyNames.isEmpty {
                Divider()
                ForEach(fontFamilyNames, id: \.self) { fontFamilyName in
                    Text(fontFamilyName)
                        .font(.custom(fontFamilyName, size: 13.5))
                        .tag(fontFamilyName)
                }
            }
        }
        .onChange(of: selectedFontName) { _, _ in
            if selectedFontName != "System" {
                pushIntoRecentFonts(selectedFontName)
                fontFamilyNames.removeAll { $0 == selectedFontName }
            }
        }
        .task {
            await MainActor.run {
                fontFamilyNames = availableFontFamilies()
            }
        }
    }
}

extension FontPicker {
    private func pushIntoRecentFonts(_ newItem: String) {
        recentFonts.removeAll(where: { $0 == newItem })
        recentFonts.insert(newItem, at: 0)
        if recentFonts.count > 3 {
            recentFonts.removeLast()
        }
        UserDefaults.standard.set(recentFonts, forKey: "recentProportionalFonts")
    }

    private func availableFontFamilies() -> [String] {
        NSFontManager.shared.availableFontFamilies.filter { fontFamilyName in
            if recentFonts.contains(fontFamilyName) || fontFamilyName == "System" {
                return false
            }

            guard let font = NSFont(name: fontFamilyName, size: 14) else {
                return false
            }
            return !font.isFixedPitch && font.numberOfGlyphs > 26
        }
    }
}
