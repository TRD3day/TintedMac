//
//  TintedMacConfig.swift
//  TintedMacConfig
//
//  Configuration module for TintedMac
//

import Foundation
import TOMLKit

public struct ThemeColors: Codable, Equatable {
    public var base00: String
    public var base01: String
    public var base02: String
    public var base03: String
    public var base04: String
    public var base05: String
    public var base06: String
    public var base07: String
    public var base08: String
    public var base09: String
    public var base0A: String
    public var base0B: String
    public var base0C: String
    public var base0D: String
    public var base0E: String
    public var base0F: String
    
    // Base24 additional colors
    public var base10: String?
    public var base11: String?
    public var base12: String?
    public var base13: String?
    public var base14: String?
    public var base15: String?
    public var base16: String?
    public var base17: String?
    
    public init(
        base00: String, base01: String, base02: String, base03: String,
        base04: String, base05: String, base06: String, base07: String,
        base08: String, base09: String, base0A: String, base0B: String,
        base0C: String, base0D: String, base0E: String, base0F: String,
        base10: String? = nil, base11: String? = nil, base12: String? = nil, base13: String? = nil,
        base14: String? = nil, base15: String? = nil, base16: String? = nil, base17: String? = nil
    ) {
        self.base00 = base00
        self.base01 = base01
        self.base02 = base02
        self.base03 = base03
        self.base04 = base04
        self.base05 = base05
        self.base06 = base06
        self.base07 = base07
        self.base08 = base08
        self.base09 = base09
        self.base0A = base0A
        self.base0B = base0B
        self.base0C = base0C
        self.base0D = base0D
        self.base0E = base0E
        self.base0F = base0F
        self.base10 = base10
        self.base11 = base11
        self.base12 = base12
        self.base13 = base13
        self.base14 = base14
        self.base15 = base15
        self.base16 = base16
        self.base17 = base17
    }
}

public enum ThemeType: String, Codable {
    case base16
    case base24
}

public struct ThemeConfig: Codable, Equatable {
    public var name: String
    public var type: ThemeType
    public var colors: ThemeColors
    
    public init(name: String, type: ThemeType, colors: ThemeColors) {
        self.name = name
        self.type = type
        self.colors = colors
    }
}

public struct TintedMacConfig: Codable, Equatable {
    public enum AppearanceMode: String, Codable {
        case light
        case dark
    }
    
    public var lightTheme: ThemeConfig
    public var darkTheme: ThemeConfig
    public var currentMode: AppearanceMode
    
    public init(lightTheme: ThemeConfig, darkTheme: ThemeConfig, currentMode: AppearanceMode) {
        self.lightTheme = lightTheme
        self.darkTheme = darkTheme
        self.currentMode = currentMode
    }
}

public class ConfigManager {
    public static let shared = ConfigManager()
    
    private let fileManager = FileManager.default
    private let configDirectory: URL
    private let configFile: URL
    
    private init() {
        let homeDir = fileManager.homeDirectoryForCurrentUser
        configDirectory = homeDir.appendingPathComponent(".config/tinted-mac")
        configFile = configDirectory.appendingPathComponent("config.toml")
    }
    
    public func loadConfig() -> TintedMacConfig {
        return loadConfig(from: configFile)
    }
    
    public func loadConfig(from url: URL) -> TintedMacConfig {
        do {
            // Create config directory if it doesn't exist
            if !fileManager.fileExists(atPath: configDirectory.path) {
                try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            }
            
            // Check if config file exists
            if !fileManager.fileExists(atPath: url.path) {
                // Create default config
                print("Config file does not exist at \(url.path), creating default config")
                let defaultConfig = createDefaultConfig()
                saveConfig(defaultConfig, to: url)
                return defaultConfig
            }
            
            print("Loading config from existing file at \(url.path)")
            
            // Read and parse TOML file using TOMLKit
            let tomlData = try Data(contentsOf: url)
            let tomlString = String(data: tomlData, encoding: .utf8) ?? ""
            
            let toml = try TOMLTable(string: tomlString)
            
            // First try the new format with flat structure (light/dark sections)
            if let lightTable = toml["light"] as? TOMLTable,
               let darkTable = toml["dark"] as? TOMLTable {
                
                // Use parseThemeConfigFlat for light theme
                let lightTheme = parseThemeConfigFlat(from: lightTable, name: "Light Theme")
                
                // Use parseThemeConfigFlat for dark theme
                let darkTheme = parseThemeConfigFlat(from: darkTable, name: "Dark Theme")
                
                // Parse mode from config section if it exists
                var currentMode = TintedMacConfig.AppearanceMode.dark
                if let configTable = toml["config"] as? TOMLTable,
                   let modeString = configTable["mode"] as? String,
                   let mode = TintedMacConfig.AppearanceMode(rawValue: modeString) {
                    currentMode = mode
                }
                
                print("Successfully loaded config with light theme: \(lightTheme.name), dark theme: \(darkTheme.name)")
                
                return TintedMacConfig(
                    lightTheme: lightTheme,
                    darkTheme: darkTheme,
                    currentMode: currentMode
                )
            }
            
            // Fall back to old format if new format not found
            guard let lightThemeTable = toml["light_theme"] as? TOMLTable,
                  let darkThemeTable = toml["dark_theme"] as? TOMLTable else {
                throw NSError(domain: "TintedMacConfig", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing theme configurations"])
            }
            
            // Parse light theme
            let lightTheme = try parseThemeConfig(from: lightThemeTable, name: "Light Theme")
            
            // Parse dark theme
            let darkTheme = try parseThemeConfig(from: darkThemeTable, name: "Dark Theme")
            
            // Parse current mode
            let modeString = toml["current_mode"] as? String ?? "dark"
            let currentMode = TintedMacConfig.AppearanceMode(rawValue: modeString) ?? .dark
            
            return TintedMacConfig(
                lightTheme: lightTheme,
                darkTheme: darkTheme,
                currentMode: currentMode
            )
            
        } catch {
            print("Error loading config: \(error)")
            let defaultConfig = createDefaultConfig()
            saveConfig(defaultConfig, to: url)
            return defaultConfig
        }
    }
    
    private func parseThemeConfig(from table: TOMLTable, name: String) throws -> ThemeConfig {
        // Get theme name and type
        let themeName = table["name"] as? String ?? name
        let themeTypeString = table["type"] as? String ?? "base16"
        let themeType = ThemeType(rawValue: themeTypeString) ?? .base16
        
        // Get colors table
        guard let colorsTable = table["colors"] as? TOMLTable else {
            throw NSError(domain: "TintedMacConfig", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing colors in theme configuration"])
        }
        
        // Parse colors
        let colors = ThemeColors(
            base00: colorsTable["base00"] as? String ?? "#000000",
            base01: colorsTable["base01"] as? String ?? "#111111",
            base02: colorsTable["base02"] as? String ?? "#222222",
            base03: colorsTable["base03"] as? String ?? "#333333",
            base04: colorsTable["base04"] as? String ?? "#444444",
            base05: colorsTable["base05"] as? String ?? "#555555",
            base06: colorsTable["base06"] as? String ?? "#666666",
            base07: colorsTable["base07"] as? String ?? "#777777",
            base08: colorsTable["base08"] as? String ?? "#888888",
            base09: colorsTable["base09"] as? String ?? "#999999",
            base0A: colorsTable["base0A"] as? String ?? "#aaaaaa",
            base0B: colorsTable["base0B"] as? String ?? "#bbbbbb",
            base0C: colorsTable["base0C"] as? String ?? "#cccccc",
            base0D: colorsTable["base0D"] as? String ?? "#dddddd",
            base0E: colorsTable["base0E"] as? String ?? "#eeeeee",
            base0F: colorsTable["base0F"] as? String ?? "#ffffff",
            base10: colorsTable["base10"] as? String,
            base11: colorsTable["base11"] as? String,
            base12: colorsTable["base12"] as? String,
            base13: colorsTable["base13"] as? String,
            base14: colorsTable["base14"] as? String,
            base15: colorsTable["base15"] as? String,
            base16: colorsTable["base16"] as? String,
            base17: colorsTable["base17"] as? String
        )
        
        return ThemeConfig(name: themeName, type: themeType, colors: colors)
    }
    
    private func parseThemeConfigFlat(from table: TOMLTable, name: String) -> ThemeConfig {
        // Get theme name and type
        let themeName = table["name"] as? String ?? name
        let themeTypeString = table["type"] as? String ?? "base16"
        let themeType = ThemeType(rawValue: themeTypeString) ?? .base16
        
        // Parse colors directly from the table (flat structure)
        let colors = ThemeColors(
            base00: table["base00"] as? String ?? "#000000",
            base01: table["base01"] as? String ?? "#111111",
            base02: table["base02"] as? String ?? "#222222",
            base03: table["base03"] as? String ?? "#333333",
            base04: table["base04"] as? String ?? "#444444",
            base05: table["base05"] as? String ?? "#555555",
            base06: table["base06"] as? String ?? "#666666",
            base07: table["base07"] as? String ?? "#777777",
            base08: table["base08"] as? String ?? "#888888",
            base09: table["base09"] as? String ?? "#999999",
            base0A: table["base0A"] as? String ?? "#aaaaaa",
            base0B: table["base0B"] as? String ?? "#bbbbbb",
            base0C: table["base0C"] as? String ?? "#cccccc",
            base0D: table["base0D"] as? String ?? "#dddddd",
            base0E: table["base0E"] as? String ?? "#eeeeee",
            base0F: table["base0F"] as? String ?? "#ffffff",
            base10: table["base10"] as? String,
            base11: table["base11"] as? String,
            base12: table["base12"] as? String,
            base13: table["base13"] as? String,
            base14: table["base14"] as? String,
            base15: table["base15"] as? String,
            base16: table["base16"] as? String,
            base17: table["base17"] as? String
        )
        
        return ThemeConfig(name: themeName, type: themeType, colors: colors)
    }
    
    public func saveConfig(_ config: TintedMacConfig) {
        saveConfig(config, to: configFile)
    }
    
    public func saveConfig(_ config: TintedMacConfig, to url: URL) {
        do {
            // Create config directory if it doesn't exist
            if !fileManager.fileExists(atPath: configDirectory.path) {
                try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            }
            
            // Create TOML table structure
            let rootTable = TOMLTable()
            
            // Light theme - use flat structure
            let lightTable = TOMLTable()
            lightTable["name"] = config.lightTheme.name
            lightTable["type"] = config.lightTheme.type.rawValue
            
            // Add color values directly to light table
            lightTable["base00"] = config.lightTheme.colors.base00
            lightTable["base01"] = config.lightTheme.colors.base01
            lightTable["base02"] = config.lightTheme.colors.base02
            lightTable["base03"] = config.lightTheme.colors.base03
            lightTable["base04"] = config.lightTheme.colors.base04
            lightTable["base05"] = config.lightTheme.colors.base05
            lightTable["base06"] = config.lightTheme.colors.base06
            lightTable["base07"] = config.lightTheme.colors.base07
            lightTable["base08"] = config.lightTheme.colors.base08
            lightTable["base09"] = config.lightTheme.colors.base09
            lightTable["base0A"] = config.lightTheme.colors.base0A
            lightTable["base0B"] = config.lightTheme.colors.base0B
            lightTable["base0C"] = config.lightTheme.colors.base0C
            lightTable["base0D"] = config.lightTheme.colors.base0D
            lightTable["base0E"] = config.lightTheme.colors.base0E
            lightTable["base0F"] = config.lightTheme.colors.base0F
            
            rootTable["light"] = lightTable
            
            // Dark theme - use flat structure
            let darkTable = TOMLTable()
            darkTable["name"] = config.darkTheme.name
            darkTable["type"] = config.darkTheme.type.rawValue
            
            // Add color values directly to dark table
            darkTable["base00"] = config.darkTheme.colors.base00
            darkTable["base01"] = config.darkTheme.colors.base01
            darkTable["base02"] = config.darkTheme.colors.base02
            darkTable["base03"] = config.darkTheme.colors.base03
            darkTable["base04"] = config.darkTheme.colors.base04
            darkTable["base05"] = config.darkTheme.colors.base05
            darkTable["base06"] = config.darkTheme.colors.base06
            darkTable["base07"] = config.darkTheme.colors.base07
            darkTable["base08"] = config.darkTheme.colors.base08
            darkTable["base09"] = config.darkTheme.colors.base09
            darkTable["base0A"] = config.darkTheme.colors.base0A
            darkTable["base0B"] = config.darkTheme.colors.base0B
            darkTable["base0C"] = config.darkTheme.colors.base0C
            darkTable["base0D"] = config.darkTheme.colors.base0D
            darkTable["base0E"] = config.darkTheme.colors.base0E
            darkTable["base0F"] = config.darkTheme.colors.base0F
            
            rootTable["dark"] = darkTable
            
            // Config section for mode
            let configTable = TOMLTable()
            configTable["mode"] = config.currentMode.rawValue
            rootTable["config"] = configTable
            
            // Convert to TOML string and write to file
            let tomlString = try TOMLEncoder().encode(rootTable)
            try tomlString.write(to: url, atomically: true, encoding: .utf8)
            
        } catch {
            print("Error saving config: \(error)")
        }
    }
    
    private func createDefaultConfig() -> TintedMacConfig {
        // Create default theme colors for both light and dark modes
        // Using placeholder values that will be replaced when themes are downloaded
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
        
        // Log that we're creating a default config with basic themes
        print("Creating default config with basic themes - can be customized later")
        
        return TintedMacConfig(
            lightTheme: ThemeConfig(name: "Default Light", type: .base16, colors: lightColors),
            darkTheme: ThemeConfig(name: "Default Dark", type: .base16, colors: darkColors),
            currentMode: .dark
        )
    }
}