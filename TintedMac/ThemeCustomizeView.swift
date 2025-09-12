import SwiftUI
import TOMLKit
import TintedThemingSwift

struct ThemeCustomizeView: View {
    @Binding var theme: Base16Theme?
    @Environment(\.dismiss) private var dismiss
    
    @State private var customTheme: Base16Theme
    @State private var showingExportSheet = false
    @State private var exportedTOML = ""
    
    private let colorKeys = [
        "base00", "base01", "base02", "base03",
        "base04", "base05", "base06", "base07",
        "base08", "base09", "base0A", "base0B",
        "base0C", "base0D", "base0E", "base0F"
    ]
    
    private let colorLabels = [
        "base00": "Background",
        "base01": "Lighter Background",
        "base02": "Selection Background",
        "base03": "Comments",
        "base04": "Dark Foreground",
        "base05": "Default Foreground",
        "base06": "Light Foreground",
        "base07": "Light Background",
        "base08": "Red",
        "base09": "Orange",
        "base0A": "Yellow",
        "base0B": "Green",
        "base0C": "Cyan",
        "base0D": "Blue",
        "base0E": "Purple",
        "base0F": "Brown"
    ]
    
    init(theme: Binding<Base16Theme?>) {
        self._theme = theme
        self._customTheme = State(initialValue: theme.wrappedValue ?? Base16Theme(
            name: "Custom Theme",
            author: "User",
            variant: "dark",
            base00: "000000", base01: "111111", base02: "222222", base03: "333333",
            base04: "444444", base05: "555555", base06: "666666", base07: "777777",
            base08: "888888", base09: "999999", base0A: "aaaaaa", base0B: "bbbbbb",
            base0C: "cccccc", base0D: "dddddd", base0E: "eeeeee", base0F: "ffffff"
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customize Theme")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Editing: \(customTheme.name)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Color editor list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(colorKeys, id: \.self) { key in
                            ColorEditRow(key: key, label: colorLabels[key] ?? key, color: Binding(
                                get: { getColorValue(for: key) },
                                set: { setColorValue(for: key, value: $0) }
                            ))
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button("Apply to Light Theme") {
                            applyToLightTheme()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Apply to Dark Theme") {
                            applyToDarkTheme()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Reset to Original") {
                            if let originalTheme = theme {
                                customTheme = originalTheme
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Export as TOML") {
                            exportToTOML()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .padding()
        }
        .frame(width: 700, height: 800)
        .onAppear {
            if let themeValue = theme {
                customTheme = themeValue
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            TOMLExportView(tomlContent: exportedTOML)
        }
    }
    
    private func getColorValue(for key: String) -> String {
        switch key {
        case "base00": return customTheme.base00
        case "base01": return customTheme.base01
        case "base02": return customTheme.base02
        case "base03": return customTheme.base03
        case "base04": return customTheme.base04
        case "base05": return customTheme.base05
        case "base06": return customTheme.base06
        case "base07": return customTheme.base07
        case "base08": return customTheme.base08
        case "base09": return customTheme.base09
        case "base0A": return customTheme.base0A
        case "base0B": return customTheme.base0B
        case "base0C": return customTheme.base0C
        case "base0D": return customTheme.base0D
        case "base0E": return customTheme.base0E
        case "base0F": return customTheme.base0F
        default: return "000000"
        }
    }
    
    private func setColorValue(for key: String, value: String) {
        let newTheme = Base16Theme(
            name: customTheme.name,
            author: customTheme.author,
            variant: customTheme.variant,
            base00: key == "base00" ? value : customTheme.base00,
            base01: key == "base01" ? value : customTheme.base01,
            base02: key == "base02" ? value : customTheme.base02,
            base03: key == "base03" ? value : customTheme.base03,
            base04: key == "base04" ? value : customTheme.base04,
            base05: key == "base05" ? value : customTheme.base05,
            base06: key == "base06" ? value : customTheme.base06,
            base07: key == "base07" ? value : customTheme.base07,
            base08: key == "base08" ? value : customTheme.base08,
            base09: key == "base09" ? value : customTheme.base09,
            base0A: key == "base0A" ? value : customTheme.base0A,
            base0B: key == "base0B" ? value : customTheme.base0B,
            base0C: key == "base0C" ? value : customTheme.base0C,
            base0D: key == "base0D" ? value : customTheme.base0D,
            base0E: key == "base0E" ? value : customTheme.base0E,
            base0F: key == "base0F" ? value : customTheme.base0F
        )
        customTheme = newTheme
        theme = newTheme
    }
    
    private func exportToTOML() {
        struct TOMLTheme: Codable {
            let name: String
            let author: String
            let variant: String
            let base00: String
            let base01: String
            let base02: String
            let base03: String
            let base04: String
            let base05: String
            let base06: String
            let base07: String
            let base08: String
            let base09: String
            let base0A: String
            let base0B: String
            let base0C: String
            let base0D: String
            let base0E: String
            let base0F: String
        }
        
        struct TOMLRoot: Codable {
            let theme: TOMLTheme
        }
        
        let tomlTheme = TOMLTheme(
            name: "\(customTheme.name)-custom",
            author: customTheme.author,
            variant: customTheme.variant,
            base00: customTheme.base00,
            base01: customTheme.base01,
            base02: customTheme.base02,
            base03: customTheme.base03,
            base04: customTheme.base04,
            base05: customTheme.base05,
            base06: customTheme.base06,
            base07: customTheme.base07,
            base08: customTheme.base08,
            base09: customTheme.base09,
            base0A: customTheme.base0A,
            base0B: customTheme.base0B,
            base0C: customTheme.base0C,
            base0D: customTheme.base0D,
            base0E: customTheme.base0E,
            base0F: customTheme.base0F
        )
        
        let tomlRoot = TOMLRoot(theme: tomlTheme)
        
        // Convert to TOML string
        do {
            exportedTOML = try TOMLEncoder().encode(tomlRoot)
            showingExportSheet = true
        } catch {
            print("Failed to encode TOML: \(error)")
        }
    }
    
    private func applyToLightTheme() {
        let themeManager = ThemeManager.shared
        let colors = themeManager.createThemeColors(from: customTheme)
        themeManager.updateThemeColors(colors, for: .light)
        dismiss()
    }
    
    private func applyToDarkTheme() {
        let themeManager = ThemeManager.shared
        let colors = themeManager.createThemeColors(from: customTheme)
        themeManager.updateThemeColors(colors, for: .dark)
        dismiss()
    }
}

struct ColorEditRow: View {
    let key: String
    let label: String
    @Binding var color: String
    @State private var showingColorPicker = false
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.headline)
                    .fontWeight(.medium)
                Text(key.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Color preview circle
                Circle()
                    .fill(Color(hex: color) ?? .gray)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isHovering ? 0.8 : 0), lineWidth: 3)
                    )
                    .scaleEffect(isHovering ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
                    .onHover { hovering in
                        isHovering = hovering
                    }
                    .onTapGesture {
                        showingColorPicker = true
                    }
                    .help("Click to open color picker")
                
                // Hex input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hex Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("#RRGGBB", text: $color)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: color) { newValue in
                            // Ensure hex format
                            if !newValue.hasPrefix("#") && !newValue.isEmpty {
                                color = "#" + newValue
                            }
                        }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .sheet(isPresented: $showingColorPicker) {
            VStack(spacing: 20) {
                Text("Select Color for \(label)")
                    .font(.headline)
                
                ColorPicker("Color", selection: Binding(
                    get: { Color(hex: color) ?? .gray },
                    set: { newColor in
                        color = newColor.toHex()
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                
                HStack {
                    Button("Cancel") {
                        showingColorPicker = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Done") {
                        showingColorPicker = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(30)
            .frame(width: 300, height: 200)
        }
    }
}

struct TOMLExportView: View {
    let tomlContent: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Exported Theme Configuration")
                    .font(.headline)
                
                ScrollView {
                    Text(tomlContent)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                
                HStack {
                    Button("Copy to Clipboard") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(tomlContent, forType: .string)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Save to File") {
                        saveToFile()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Export Theme")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func saveToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: "toml")!]
        savePanel.nameFieldStringValue = "custom-theme.toml"
        
        if savePanel.runModal() == .OK {
            guard let url = savePanel.url else { return }
            
            do {
                try tomlContent.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to save file: \(error)")
            }
        }
    }
}

// Extension to convert Color to hex
extension Color {
    func toHex() -> String {
        let nsColor = NSColor(self)
        guard let ciColor = CIColor(color: nsColor) else {
            return "#000000"
        }
        let red = Int(ciColor.red * 255)
        let green = Int(ciColor.green * 255)
        let blue = Int(ciColor.blue * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var sampleTheme: Base16Theme? = Base16Theme(
            name: "Sample Theme",
            author: "Preview",
            variant: "dark",
            base00: "2d3748", base01: "4a5568", base02: "718096", base03: "a0aec0",
            base04: "cbd5e0", base05: "e2e8f0", base06: "edf2f7", base07: "f7fafc",
            base08: "f56565", base09: "ed8936", base0A: "ecc94b", base0B: "48bb78",
            base0C: "38b2ac", base0D: "4299e1", base0E: "9f7aea", base0F: "a0522d"
        )
        
        var body: some View {
            ThemeCustomizeView(theme: $sampleTheme)
        }
    }
    
    return PreviewWrapper()
}