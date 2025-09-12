//
//  ColorEditorView.swift
//  TintedMac
//
//  Color editor interface for manual theme customization
//

import SwiftUI
import Foundation

struct ColorEditorView: View {
    @ObservedObject var themeManager: ThemeManager
    @Binding var showingColorPicker: Bool
    @Binding var selectedColorKey: String
    @Binding var selectedColor: Color
    @State private var editingMode: EditingMode = .dark
    @State private var searchText = ""

    enum EditingMode: String, CaseIterable {
        case light = "Light Theme"
        case dark = "Dark Theme"
    }

    private var currentTheme: ThemeConfig {
        switch editingMode {
        case .light:
            return themeManager.currentConfig.lightTheme
        case .dark:
            return themeManager.currentConfig.darkTheme
        }
    }

    private var colorEntries: [(key: String, value: String, description: String)] {
        let colors = currentTheme.colors
        let allColors = [
            ("base00", colors.base00, "Default Background"),
            ("base01", colors.base01, "Lighter Background (Status bars, line numbers)"),
            ("base02", colors.base02, "Selection Background"),
            ("base03", colors.base03, "Comments, Invisibles, Line Highlighting"),
            ("base04", colors.base04, "Dark Foreground (Status bars)"),
            ("base05", colors.base05, "Default Foreground, Caret, Delimiters"),
            ("base06", colors.base06, "Light Foreground"),
            ("base07", colors.base07, "Light Background"),
            ("base08", colors.base08, "Variables, XML Tags, Markup Links"),
            ("base09", colors.base09, "Integers, Boolean, Constants"),
            ("base0A", colors.base0A, "Classes, Markup Bold, Search Background"),
            ("base0B", colors.base0B, "Strings, Inherited Class, Markup Code"),
            ("base0C", colors.base0C, "Support, Regex, Escape Characters"),
            ("base0D", colors.base0D, "Functions, Methods, Attribute IDs"),
            ("base0E", colors.base0E, "Keywords, Storage, Selector"),
            ("base0F", colors.base0F, "Legacy compatibility")
        ]

        // Base24 colors removed temporarily
        var extendedColors = allColors

        if searchText.isEmpty {
            return extendedColors
        } else {
            return extendedColors.filter { entry in
                entry.0.localizedCaseInsensitiveContains(searchText) ||
                entry.2.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header controls
            HStack {
                // Mode selector
                Picker("Editing Mode", selection: $editingMode) {
                    ForEach(EditingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 250)

                Spacer()

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search colors...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .frame(width: 200)

                // Reset button
                Button("Reset to Default") {
                    resetToDefault()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Theme info
            HStack {
                VStack(alignment: .leading) {
                    Text(currentTheme.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(currentTheme.type.rawValue.uppercased()) Theme")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Preview area
                ThemePreviewCard(theme: currentTheme)
            }
            .padding()

            Divider()

            // Color list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(colorEntries, id: \.key) { entry in
                        ColorRowView(
                            colorKey: entry.key,
                            colorValue: entry.value,
                            description: entry.description,
                            onColorTap: { key, color in
                                selectedColorKey = key
                                selectedColor = Color(hex: color) ?? .black
                                showingColorPicker = true
                            }
                        )
                    }
                }
            }

            Divider()

            // Action buttons
            HStack {
                Button("Export Theme") {
                    exportTheme()
                }
                .buttonStyle(.bordered)

                Button("Import Theme") {
                    importTheme()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save Configuration") {
                    saveConfiguration()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func resetToDefault() {
        let defaultConfig = ConfigManager.shared.loadConfig()

        switch editingMode {
        case .light:
            themeManager.currentConfig.lightTheme = defaultConfig.lightTheme
        case .dark:
            themeManager.currentConfig.darkTheme = defaultConfig.darkTheme
        }

        themeManager.objectWillChange.send()
    }

    private func saveConfiguration() {
        themeManager.saveConfiguration()
    }

    private func exportTheme() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(currentTheme.name).json"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(currentTheme)
                    try data.write(to: url)
                } catch {
                    print("Export error: \(error)")
                }
            }
        }
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let importedTheme = try decoder.decode(ThemeConfig.self, from: data)

                    switch editingMode {
                    case .light:
                        themeManager.currentConfig.lightTheme = importedTheme
                    case .dark:
                        themeManager.currentConfig.darkTheme = importedTheme
                    }

                    themeManager.objectWillChange.send()
                } catch {
                    print("Import error: \(error)")
                }
            }
        }
    }
}

struct ColorRowView: View {
    let colorKey: String
    let colorValue: String
    let description: String
    let onColorTap: (String, String) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Color preview
            Button(action: {
                onColorTap(colorKey, colorValue)
            }) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: colorValue) ?? .gray)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "eyedropper")
                            .foregroundColor(.white)
                            .opacity(isHovered ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: isHovered)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHovered = hovering
            }

            // Color info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(colorKey)
                        .font(.headline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(colorValue)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 1 : 0))
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct ThemePreviewCard: View {
    let theme: ThemeConfig

    var body: some View {
        VStack(spacing: 8) {
            // Background preview
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: theme.colors.base00) ?? .black)
                .frame(width: 200, height: 120)
                .overlay(
                    VStack(alignment: .leading, spacing: 4) {
                        // Simulated text
                        HStack {
                            Rectangle()
                                .fill(Color(hex: theme.colors.base05) ?? .white)
                                .frame(width: 60, height: 8)
                            Rectangle()
                                .fill(Color(hex: theme.colors.base0D) ?? .blue)
                                .frame(width: 40, height: 8)
                        }

                        Rectangle()
                            .fill(Color(hex: theme.colors.base03) ?? .gray)
                            .frame(width: 80, height: 6)

                        HStack {
                            Rectangle()
                                .fill(Color(hex: theme.colors.base08) ?? .red)
                                .frame(width: 30, height: 8)
                            Rectangle()
                                .fill(Color(hex: theme.colors.base0B) ?? .green)
                                .frame(width: 50, height: 8)
                        }

                        Rectangle()
                            .fill(Color(hex: theme.colors.base02) ?? .gray)
                            .frame(width: 100, height: 12)
                    }
                    .padding()
                )

            // Color dots
            HStack(spacing: 4) {
                ForEach([theme.colors.base08, theme.colors.base09, theme.colors.base0A, theme.colors.base0B], id: \.self) { color in
                    Circle()
                        .fill(Color(hex: color) ?? .gray)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    let colorKey: String
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit \(colorKey)")
                .font(.title2)
                .fontWeight(.semibold)

            ColorPicker("Select Color", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(2.0)
                .frame(height: 100)

            Text(selectedColor.toHex())
                .font(.system(.title3, design: .monospaced))
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

            HStack(spacing: 16) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)

                Button("Apply") {
                    applyColor()
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300, height: 250)
    }

    private func applyColor() {
        let hexColor = selectedColor.toHex()

        // Update the appropriate theme colors
        let currentMode: TintedMacConfig.AppearanceMode = themeManager.currentConfig.currentMode
        var updatedColors = currentMode == .light ? themeManager.currentConfig.lightTheme.colors : themeManager.currentConfig.darkTheme.colors

        // Update the specific color based on the key
        switch colorKey {
        case "base00": updatedColors.base00 = hexColor
        case "base01": updatedColors.base01 = hexColor
        case "base02": updatedColors.base02 = hexColor
        case "base03": updatedColors.base03 = hexColor
        case "base04": updatedColors.base04 = hexColor
        case "base05": updatedColors.base05 = hexColor
        case "base06": updatedColors.base06 = hexColor
        case "base07": updatedColors.base07 = hexColor
        case "base08": updatedColors.base08 = hexColor
        case "base09": updatedColors.base09 = hexColor
        case "base0A": updatedColors.base0A = hexColor
        case "base0B": updatedColors.base0B = hexColor
        case "base0C": updatedColors.base0C = hexColor
        case "base0D": updatedColors.base0D = hexColor
        case "base0E": updatedColors.base0E = hexColor
        case "base0F": updatedColors.base0F = hexColor
        // Base24 colors removed temporarily
        default: break
        }

        themeManager.updateThemeColors(updatedColors, for: currentMode)
    }
}

// MARK: - Color Extensions

extension Color {
    init?(hex: String) {
        // Remove only whitespace and preserve the hashtag
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexString = cleanHex.hasPrefix("#") ? String(cleanHex.dropFirst()) : cleanHex

        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexString.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }


}
