//
//  SettingsView.swift
//  TintedMac
//
//  Settings and preferences interface
//

import SwiftUI
import Foundation
import TintedThemingSwift

struct SettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @AppStorage("followSystemAppearance") private var followSystemAppearance = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var showingResetAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // General Settings
                SettingsSection(title: "General", icon: "gear") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsToggle(
                            title: "Follow system appearance",
                            subtitle: "Switch between light and dark themes based on system settings",
                            isOn: $followSystemAppearance
                        )
                    }
                }

                // Application Settings
                SettingsSection(title: "Application", icon: "app.badge") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsToggle(
                            title: "Launch at login",
                            subtitle: "Start TintedMac automatically when you log in",
                            isOn: $launchAtLogin
                        )
                    }
                }

                                // Configuration Settings
                SettingsSection(title: "Configuration", icon: "doc.text") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Configuration File")
                                .font(.headline)

                            Text("Configuration is stored at ~/.config/tinted-mac/config.toml")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Button("Open Config Folder") {
                                openConfigFolder()
                            }
                            .buttonStyle(.bordered)

                            Button("Reload Configuration") {
                                reloadConfiguration()
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button("Reset to Defaults") {
                                showingResetAlert = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                }

                // Theme Management
                SettingsSection(title: "Theme Management", icon: "paintbrush") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current Light Theme")
                                    .font(.headline)
                                Text(themeManager.currentConfig.lightTheme.name)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Customize") {
                                customizeLightTheme()
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current Dark Theme")
                                    .font(.headline)
                                Text(themeManager.currentConfig.darkTheme.name)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Customize") {
                                customizeDarkTheme()
                            }
                            .buttonStyle(.bordered)
                        }

                        Divider()

                        HStack {
                            Button("Export Current Configuration") {
                                let panel = NSSavePanel()
                                panel.allowedContentTypes = [.toml]
                                panel.nameFieldStringValue = "tinted-mac-config.toml"

                                panel.begin { response in
                                    if response == .OK, let url = panel.url {
                                        do {
                                            try themeManager.exportConfiguration(to: url)
                                        } catch {
                                            print("Failed to export config: \(error)")
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Import Configuration") {
                                let panel = NSOpenPanel()
                                panel.allowedContentTypes = [.toml]
                                panel.allowsMultipleSelection = false

                                panel.begin { response in
                                    if response == .OK, let url = panel.urls.first {
                                        do {
                                            try themeManager.importConfiguration(from: url)
                                        } catch {
                                            print("Failed to import config: \(error)")
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                // Advanced Settings
                SettingsSection(title: "Advanced", icon: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Debug Information")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 4) {
                            InfoRow(label: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            InfoRow(label: "Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                            InfoRow(label: "System Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                            InfoRow(label: "Available Schemes", value: "\(themeManager.availableSchemes.count)")
                        }

                        Divider()

                        HStack {
                            Button("View Logs") {
                                openLogs()
                            }
                            .buttonStyle(.bordered)

                            Button("Clear Cache") {
                                clearCache()
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button("Reset All Settings") {
                                showingResetAlert = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding()
        }

        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
        .onChange(of: followSystemAppearance) { newValue in
            // Update theme manager's appearance mode based on setting
            let newMode: TintedMacConfig.AppearanceMode = newValue ? (NSApp.effectiveAppearance.name == .darkAqua ? .dark : .light) : themeManager.currentConfig.currentMode
            if newMode != themeManager.currentConfig.currentMode {
                themeManager.setAppearanceMode(newMode)
            }
        }

        .onChange(of: launchAtLogin) { newValue in
            // This could control launch at login behavior
            print("Launch at login changed to: \(newValue)")
        }
    }

    // MARK: - Actions

    private func openConfigFolder() {
        let configURL = URL(fileURLWithPath: NSString(string: "~/.config/tinted-mac/config.toml").expandingTildeInPath).deletingLastPathComponent()
        NSWorkspace.shared.open(configURL)
    }

    private func reloadConfiguration() {
        themeManager.reloadConfiguration()

        // Save configuration - let dylib handle theme application
        themeManager.saveConfiguration()
    }

    private func resetAllSettings() {
        // Reset UserDefaults settings
        followSystemAppearance = true
        launchAtLogin = false

        // Reset to default theme configuration
        let lightColors = ThemeColors(
            base00: "#ffffff", base01: "#f5f5f5", base02: "#e5e5e5", base03: "#d0d0d0",
            base04: "#a0a0a0", base05: "#707070", base06: "#505050", base07: "#303030",
            base08: "#c82829", base09: "#f5871f", base0A: "#eab700", base0B: "#718c00",
            base0C: "#3e999f", base0D: "#4271ae", base0E: "#8959a8", base0F: "#a3685a"
        )
        
        let darkColors = ThemeColors(
            base00: "#1d1f21", base01: "#282a2e", base02: "#373b41", base03: "#969896",
            base04: "#b4b7b4", base05: "#c5c8c6", base06: "#e0e0e0", base07: "#ffffff",
            base08: "#cc6666", base09: "#de935f", base0A: "#f0c674", base0B: "#b5bd68",
            base0C: "#8abeb7", base0D: "#81a2be", base0E: "#b294bb", base0F: "#a3685a"
        )

        let defaultConfig = TintedMacConfig(
            lightTheme: ThemeConfig(name: "Default Light", type: .base16, colors: lightColors),
            darkTheme: ThemeConfig(name: "Default Dark", type: .base16, colors: darkColors),
            currentMode: .dark
        )

        themeManager.currentConfig = defaultConfig
        themeManager.saveCurrentConfiguration()

        // Reload schemes and save configuration - let dylib handle theme application
        themeManager.loadAvailableSchemes()
        themeManager.saveConfiguration()
    }

    private func openLogs() {
        let logsURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("TintedMac")

        NSWorkspace.shared.open(logsURL)
    }

    private func clearCache() {
        // Clear any cached theme data
        themeManager.clearCache()
    }

    private func customizeLightTheme() {
        // Open customize view for light theme
        if let windowController = NSApplication.shared.windows.first?.windowController {
            @State var lightTheme: Base16Theme? = nil
            let customizeView = ThemeCustomizeView(theme: $lightTheme)
            let hostingController = NSHostingController(rootView: customizeView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Customize Light Theme"
            window.setContentSize(NSSize(width: 700, height: 800))
            window.center()
            window.makeKeyAndOrderFront(window)
        }
    }

    private func customizeDarkTheme() {
        // Open customize view for dark theme
        if let windowController = NSApplication.shared.windows.first?.windowController {
            @State var darkTheme: Base16Theme? = nil
            let customizeView = ThemeCustomizeView(theme: $darkTheme)
            let hostingController = NSHostingController(rootView: customizeView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Customize Dark Theme"
            window.setContentSize(NSSize(width: 700, height: 800))
            window.center()
            window.makeKeyAndOrderFront(window)
        }
    }

}

// MARK: - Supporting Views

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            content
                .padding(.leading, 28)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}



// MARK: - UTType Extensions

import UniformTypeIdentifiers

extension UTType {
    static let toml = UTType(filenameExtension: "toml") ?? UTType.plainText
}
