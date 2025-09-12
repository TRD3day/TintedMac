//
//  ThemeManager.swift
//  TintedMac
//
//  Theme management and Base16/24 scheme loading
//

import Foundation
import AppKit
import TintedThemingSwift
import TintedMacConfig

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var availableSchemes: [String] = []
    @Published var availableBase24Schemes: [String] = []
    @Published var categories: [String] = ["All", "Base16", "Base24"]
    @Published var selectedCategory = "All"
    @Published var searchText = ""
    @Published var currentConfig: TintedMacConfig
    @Published var isLoading = false

    private let configManager = ConfigManager.shared
    private let themeLoader = TintedThemesLoader.shared



    private init() {
        self.currentConfig = configManager.loadConfig()
        loadAvailableSchemes()

        // Configuration loaded - let dylib handle theme application
    }

    func initializeAutoThemeApplication() {
        // Set up appearance change notifications for configuration updates
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Save configuration on appearance changes - let dylib handle theme application
            self?.saveConfiguration()
        }

        // Configuration initialized - let dylib handle theme application
    }

    func loadAvailableSchemes() {
        isLoading = true

        Task {
            do {
                // First try to use cached themes for immediate response
                let cachedThemes = themeLoader.getCachedThemes()
                if !cachedThemes.isEmpty {
                    await MainActor.run {
                        self.availableSchemes = cachedThemes.map { $0.name }
                    }
                }
                
                // Load both Base16 and Base24 themes from TintedThemesLoader API
                async let b16Themes = themeLoader.loadAllBase16Themes()
                async let b24Themes = themeLoader.loadAllBase24Themes()
                
                let (base16Themes, base24Themes) = try await (b16Themes, b24Themes)

                await MainActor.run {
                    self.availableSchemes = base16Themes.map { $0.name }
                    self.availableBase24Schemes = base24Themes.map { $0.name }
                    self.isLoading = false
                }
            } catch {
                print("Error loading themes from API: \(error)")
                await MainActor.run {
                    // Fallback to cached themes or default theme names
                    if self.availableSchemes.isEmpty {
                        self.availableSchemes = self.getDefaultThemeNames()
                    }
                    // For Base24, use empty array as fallback since we don't have default Base24 themes
                    if self.availableBase24Schemes.isEmpty {
                        self.availableBase24Schemes = []
                    }
                    self.isLoading = false
                }
            }
        }
    }

    private func getDefaultThemeNames() -> [String] {
        // First try to get cached themes from TintedThemesLoader
        let cachedThemes = themeLoader.getCachedThemes()
        if !cachedThemes.isEmpty {
            return cachedThemes.map { $0.name }
        }
        
        // If no cached themes available, return essential fallback themes
        // These are the most commonly used themes that should always be available
        return [
            "Default Dark", "Default Light", "Monokai", "Solarized Dark", "Solarized Light",
            "Dracula", "Nord", "Gruvbox Dark Medium", "Gruvbox Light Medium", "Tomorrow Night",
            "Tomorrow", "One Light", "Onedark", "Material", "Github"
        ]
    }


     func applyScheme(_ schemeName: String, for mode: TintedMacConfig.AppearanceMode) {
         Task {
             do {
                 // Check if it's a Base24 theme
                 if availableBase24Schemes.contains(schemeName) {
                     let base24Themes = try await themeLoader.loadAllBase24Themes()
                     guard let theme = base24Themes.first(where: { $0.name == schemeName }) else {
                         print("Base24 theme not found: \(schemeName)")
                         return
                     }

                     await MainActor.run {
                         let themeColors = createThemeColors(from: theme)
                         applyThemeColors(themeColors, schemeName: schemeName, themeType: .base24, for: mode)
                     }
                 } else {
                     // Load as Base16 theme
                     let base16Themes = try await themeLoader.loadAllBase16Themes()
                     guard let theme = base16Themes.first(where: { $0.name == schemeName }) else {
                         print("Base16 theme not found: \(schemeName)")
                         return
                     }

                     await MainActor.run {
                         let themeColors = createThemeColors(from: theme)
                         applyThemeColors(themeColors, schemeName: schemeName, themeType: ThemeType.base16, for: mode)
                     }
                 }
             } catch {
                 print("Error loading theme: \(error)")
                 // Fallback to cached themes or default
                 await MainActor.run {
                     let defaultColors = createDefaultThemeColors()
                     applyThemeColors(defaultColors, schemeName: "Default", themeType: ThemeType.base16, for: mode)
                 }
             }
         }
     }

     func createThemeColors(from theme: Base16Theme) -> ThemeColors {
        return ThemeColors(
            base00: ensureHashtagPrefix(theme.base00), base01: ensureHashtagPrefix(theme.base01),
            base02: ensureHashtagPrefix(theme.base02), base03: ensureHashtagPrefix(theme.base03),
            base04: ensureHashtagPrefix(theme.base04), base05: ensureHashtagPrefix(theme.base05),
            base06: ensureHashtagPrefix(theme.base06), base07: ensureHashtagPrefix(theme.base07),
            base08: ensureHashtagPrefix(theme.base08), base09: ensureHashtagPrefix(theme.base09),
            base0A: ensureHashtagPrefix(theme.base0A), base0B: ensureHashtagPrefix(theme.base0B),
            base0C: ensureHashtagPrefix(theme.base0C), base0D: ensureHashtagPrefix(theme.base0D),
            base0E: ensureHashtagPrefix(theme.base0E), base0F: ensureHashtagPrefix(theme.base0F)
        )
    }

     func createThemeColors(from theme: Base24Theme) -> ThemeColors {
         return ThemeColors(
             base00: ensureHashtagPrefix(theme.base00), base01: ensureHashtagPrefix(theme.base01),
             base02: ensureHashtagPrefix(theme.base02), base03: ensureHashtagPrefix(theme.base03),
             base04: ensureHashtagPrefix(theme.base04), base05: ensureHashtagPrefix(theme.base05),
             base06: ensureHashtagPrefix(theme.base06), base07: ensureHashtagPrefix(theme.base07),
             base08: ensureHashtagPrefix(theme.base08), base09: ensureHashtagPrefix(theme.base09),
             base0A: ensureHashtagPrefix(theme.base0A), base0B: ensureHashtagPrefix(theme.base0B),
             base0C: ensureHashtagPrefix(theme.base0C), base0D: ensureHashtagPrefix(theme.base0D),
             base0E: ensureHashtagPrefix(theme.base0E), base0F: ensureHashtagPrefix(theme.base0F),
             base10: ensureHashtagPrefix(theme.base10), base11: ensureHashtagPrefix(theme.base11),
             base12: ensureHashtagPrefix(theme.base12), base13: ensureHashtagPrefix(theme.base13),
             base14: ensureHashtagPrefix(theme.base14), base15: ensureHashtagPrefix(theme.base15),
             base16: ensureHashtagPrefix(theme.base16), base17: ensureHashtagPrefix(theme.base17)
         )
     }

     private func applyThemeColors(_ colors: ThemeColors, schemeName: String, themeType: ThemeType, for mode: TintedMacConfig.AppearanceMode) {
         let themeConfig = ThemeConfig(
             name: schemeName,
             type: themeType,
             colors: colors
         )

         switch mode {
         case .light:
             // Update only the light theme variant in config
             self.currentConfig.lightTheme = themeConfig
         case .dark:
             // Update only the dark theme variant in config
             self.currentConfig.darkTheme = themeConfig
         }

         // Save the configuration
         configManager.saveConfig(currentConfig)

         // Apply the current theme to the UI
         applyCurrentTheme()
     }

    private func createDefaultThemeColors() -> ThemeColors {
        return ThemeColors(
            base00: "#1d1f21", base01: "#282a2e", base02: "#373b41", base03: "#969896",
            base04: "#b4b7b4", base05: "#c5c8c6", base06: "#e0e0e0", base07: "#ffffff",
            base08: "#cc6666", base09: "#de935f", base0A: "#f0c674", base0B: "#b5bd68",
            base0C: "#8abeb7", base0D: "#81a2be", base0E: "#b294bb", base0F: "#a3685a"
            // Base24 support removed temporarily
            // base10: nil, base11: nil, base12: nil, base13: nil,
            // base14: nil, base15: nil, base16: nil, base17: nil
        )
    }

    func setAppearanceMode(_ mode: TintedMacConfig.AppearanceMode) {
        currentConfig.currentMode = mode
        saveAndApplyConfig()
    }

    /// Save current configuration
    func saveConfiguration() {
        configManager.saveConfig(currentConfig)
    }

    /// Update theme colors for a specific appearance mode
    func updateThemeColors(_ colors: ThemeColors, for mode: TintedMacConfig.AppearanceMode) {
        switch mode {
        case .light:
            currentConfig.lightTheme.colors = colors
        case .dark:
            currentConfig.darkTheme.colors = colors
        // .auto case removed - no longer supported
        }

        saveAndApplyConfig()
    }

    /// Reload configuration from disk
    func reloadConfiguration() {
        currentConfig = configManager.loadConfig()
        loadAvailableSchemes()
        objectWillChange.send()
    }

    /// Clear any cached data
    func clearCache() {
        // Clear scheme cache if needed
        availableSchemes.removeAll()
        loadAvailableSchemes()
    }

    private func saveAndApplyConfig() {
        configManager.saveConfig(currentConfig)
        applyCurrentTheme()
    }

    func applyCurrentTheme() {
        // Detect current system appearance
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Determine effective theme based on current system appearance
        let effectiveTheme: ThemeConfig

        switch currentConfig.currentMode {
        case .light:
            effectiveTheme = currentConfig.lightTheme
        case .dark:
            effectiveTheme = currentConfig.darkTheme
        }

        // Only save configuration - do not apply theming to GUI
        // The dylib injection will handle theme application for other apps
        print("Current theme configuration: \(effectiveTheme.name) (\(effectiveTheme.type.rawValue)) for \(isDarkMode ? "dark" : "light") mode")

        // Save the current configuration
        saveCurrentConfiguration()
    }

    /// Apply a specific theme
    func applyTheme(_ theme: ThemeConfig) {
        // Validate that the theme has valid colors before applying
        guard isValidTheme(theme) else {
            print("Theme \(theme.name) has invalid or empty colors - skipping theme application")
            return
        }

        // Only save configuration - do not apply system-wide theming to GUI
        // The dylib injection will handle theme application for other apps
        print("Configuring theme: \(theme.name) (\(theme.type.rawValue)) - saved to config only")

        // Save the applied theme to configuration
        saveCurrentConfiguration()

        // Notify observers
        objectWillChange.send()
    }

    func saveCurrentConfiguration() {
        configManager.saveConfig(currentConfig)
    }

    /// Determine if a theme is a light or dark variant based on background color brightness
    func getThemeVariant(_ theme: ThemeConfig) -> TintedMacConfig.AppearanceMode {
        guard let bgColor = NSColor(hex: theme.colors.base00) else {
            return .dark // Default to dark if color parsing fails
        }

        let brightness = bgColor.brightnessComponent
        return brightness > 0.5 ? .light : .dark
    }

    /// Get theme variant by scheme name
    func getThemeVariant(for scheme: String) async -> TintedMacConfig.AppearanceMode {
        do {
            // Base24 support removed temporarily
            
            // For Base16 themes, load and check variant
            let base16Themes = try await themeLoader.loadAllBase16Themes()
            if let theme = base16Themes.first(where: { $0.name == scheme }) {
                let themeColors = createThemeColors(from: theme)
                let tempThemeConfig = ThemeConfig(name: scheme, type: .base16, colors: themeColors)
                return getThemeVariant(tempThemeConfig)
            }
        } catch {
            print("Error loading theme for variant detection: \(error)")
        }

        return .dark // Default fallback
    }

    /// Validate that a theme has valid, non-empty colors
    private func isValidTheme(_ theme: ThemeConfig) -> Bool {
        let colors = theme.colors

        // Check that essential base16 colors are not empty and are valid hex colors
        let essentialColors = [
            colors.base00, colors.base01, colors.base02, colors.base03,
            colors.base04, colors.base05, colors.base06, colors.base07,
            colors.base08, colors.base09, colors.base0A, colors.base0B,
            colors.base0C, colors.base0D, colors.base0E, colors.base0F
        ]

        for color in essentialColors {
            // Check if color is empty or not a valid hex color
            if color.isEmpty || !isValidHexColor(color) {
                return false
            }
        }

        return true
    }

    /// Validate that a string is a valid hex color
    private func isValidHexColor(_ hex: String) -> Bool {
        let hexPattern = "^#?[0-9A-Fa-f]{6}$"
        let regex = try? NSRegularExpression(pattern: hexPattern)
        let range = NSRange(location: 0, length: hex.count)
        return regex?.firstMatch(in: hex, options: [], range: range) != nil
    }

    /// Remove hashtag prefix from a hex color string
    private func ensureHashtagPrefix(_ hex: String) -> String {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            return trimmed
        } else {
            return "#" + trimmed
        }
    }

    func exportConfiguration(to url: URL) throws {
        configManager.saveConfig(currentConfig, to: url)
    }

    func importConfiguration(from url: URL) throws {
        let importedConfig = configManager.loadConfig(from: url)
        currentConfig = importedConfig
        saveCurrentConfiguration()

        // Reload schemes and apply current theme
        loadAvailableSchemes()
        // Apply current theme after reloading
        applyCurrentTheme()

        objectWillChange.send()
    }

    /// Remove current theme and restore system defaults
    func removeCurrentTheme() {
        print("Removed current theme, restored system defaults")
    }

    /// Revert to default system appearance
    func revertToDefault() {
        // Remove any applied theming first

        // Create default theme configs
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
        currentConfig.lightTheme = ThemeConfig(name: "Default Light", type: .base16, colors: lightColors)
        currentConfig.darkTheme = ThemeConfig(name: "Default Dark", type: .base16, colors: darkColors)
        currentConfig.currentMode = .dark

        // Save the reset configuration
        saveCurrentConfiguration()

        print("Reverted to default system appearance - no theming applied")
        objectWillChange.send()
    }

    /// Toggle theme application on/off
    func toggleThemeApplication() {
        // Toggle between applying and removing current theme
        removeCurrentTheme()
        applyCurrentTheme()
    }


    func searchSchemes(query: String) -> [String] {
        guard !query.isEmpty else { return availableSchemes }

Task {
            let themes = await themeLoader.loadBase16Themes(named: [])
            let filteredThemes = themes.filter { theme in
                theme.name.localizedCaseInsensitiveContains(query) ||
                theme.author.localizedCaseInsensitiveContains(query)
            }

            await MainActor.run {
                self.availableSchemes = filteredThemes.map { $0.name }
            }
        }

        return availableSchemes.filter { schemeName in
            schemeName.localizedCaseInsensitiveContains(query)
        }
    }

    func getSchemesByCategory() -> [String: [String]] {
        // Return a synchronous result based on available schemes
        var categories: [String: [String]] = [:]

        // For now, categorize based on available scheme names
        for schemeName in availableSchemes {
            let category = "base16" // Default category
            if categories[category] == nil {
                categories[category] = []
            }
            categories[category]?.append(schemeName)
        }

        return categories
    }

    func getSchemesByCategoryAsync() async -> [String: [String]] {
        var categories: [String: [String]] = [:]

do {
            let themes = try await themeLoader.loadAllBase16Themes()

            for theme in themes {
                let category = theme.variant.isEmpty ? "base16" : theme.variant
                if categories[category] == nil {
                    categories[category] = []
                }
                categories[category]?.append(theme.name)
            }
        } catch {
            print("Error getting schemes by category: \(error)")
        }

        return categories
    }

    func refreshThemes() {
        Task {
            do {
                // Use refreshThemes() to force refresh from network, ignoring cache
                try await themeLoader.refreshThemes()
                
                // Load both Base16 and Base24 themes
                async let b16Themes = themeLoader.loadAllBase16Themes()
                async let b24Themes = themeLoader.loadAllBase24Themes()
                
                let (base16Themes, base24Themes) = try await (b16Themes, b24Themes)
                
                await MainActor.run {
                    self.availableSchemes = base16Themes.map { $0.name }
                    self.availableBase24Schemes = base24Themes.map { $0.name }
                }
            } catch {
                print("Error refreshing themes from API: \(error)")
                // Fallback to cached themes if refresh fails
                await MainActor.run {
                    let cachedThemes = self.themeLoader.getCachedThemes()
                    if !cachedThemes.isEmpty {
                        self.availableSchemes = cachedThemes.map { $0.name }
                    } else {
                        self.availableSchemes = self.getDefaultThemeNames()
                    }
                    // For Base24, use empty array as fallback
                    if self.availableBase24Schemes.isEmpty {
                        self.availableBase24Schemes = []
                    }
                }
            }
        }
    }



}

// MARK: - Extensions

extension NSColor {
    var brightness: Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Calculate perceived brightness using the luminance formula
        return Double(0.299 * red + 0.587 * green + 0.114 * blue)
    }
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}
