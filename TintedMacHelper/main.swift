//
//  main.swift
//  TintedMacHelper
//
//  Created by TintedMac on 2025-08-25.
//

import Foundation
import Cocoa
import TintedMacConfig
import os.log

// Import shared protocol definitions
import class Foundation.NSXPCConnection
import class Foundation.NSXPCInterface
import class Foundation.NSXPCListener

// Import shared protocol file
import TintedMacProtocol

// Define logger for Console.app visibility
let log = OSLog(subsystem: "com.aspauldingcode.TintedMac.helper", category: "Helper")

// Helper function to log messages with appropriate log level
func logMessage(_ message: String, type: OSLogType = .default) {
    os_log("%{public}@", log: log, type: type, message)
    // Keep NSLog for backward compatibility
    NSLog("TintedMacHelper: %@", message)
}

class TintedMacHelper: NSObject, TintedMacHelperProtocol, NSXPCListenerDelegate {
    private var configPath: String
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var xpcListener: NSXPCListener?

    override init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        self.configPath = "\(homeDir)/.config/tinted-mac/config.toml"
        super.init()
    }

    func start() {
        logMessage("Starting helper process")

        // Setup NSXPCListener for XPC communication
        setupXPCListener()

        // Read and broadcast initial configuration
        broadcastConfiguration()

        // Setup file monitoring for config changes
        setupFileMonitoring()

        // Setup periodic broadcasting for new processes
        setupPeriodicBroadcast()

        // Keep the helper running
        RunLoop.main.run()
    }

    private func setupXPCListener() {
        // Create NSXPCListener for XPC communication
        xpcListener = NSXPCListener(machServiceName: TintedMacConnection.machServiceName)
        xpcListener?.delegate = self
        
        // Start the listener
        xpcListener?.resume()
        logMessage("NSXPCListener started with mach service name: \(TintedMacConnection.machServiceName)")
    }
    
    // MARK: - NSXPCListenerDelegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logMessage("Received new XPC connection")
        
        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: TintedMacHelperProtocol.self)
        newConnection.exportedObject = self
        
        // Set up error handling
        newConnection.invalidationHandler = {
            logMessage("XPC connection invalidated", type: .error)
        }
        
        newConnection.interruptionHandler = {
            logMessage("XPC connection interrupted", type: .error)
        }
        
        // Activate the connection
        newConnection.resume()
        logMessage("XPC connection established and activated")
        
        return true
    }

    private func setupPeriodicBroadcast() {
        // Broadcast configuration every 5 seconds to catch new processes
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            logMessage("Periodic broadcast triggered", type: .info)
            // Don't reload from disk, just use the last broadcast config if available
            if let _ = self?.lastBroadcastConfig {
                logMessage("Using cached config instead of reloading from disk")
            } else {
                self?.broadcastConfiguration()
            }
        }
    }


    // Store the last broadcast configuration to avoid sending duplicates
    private var lastBroadcastConfig: String? = nil
    
    private func broadcastConfiguration() {
        guard let configData = readConfiguration() else {
            logMessage("No configuration to broadcast", type: .error)
            return
        }
        
        // Check if this is a duplicate of the last broadcast
        if let lastConfig = lastBroadcastConfig, lastConfig == configData {
            logMessage("Skipping broadcast - configuration unchanged", type: .info)
            return
        }
        
        // Store this config as the last broadcast
        lastBroadcastConfig = configData
        
        // Log the current configuration for debugging
        logMessage("Current configuration before broadcast: \(configData)")

        logMessage("Broadcasting configuration update")
        
        // Check for black colors in the JSON before broadcasting and replace them
        var modifiedConfigData = configData
        
        // Replace all instances of black colors with appropriate values
        if configData.contains("\"base00\" : \"#000000\"") {
            logMessage("WARNING - Found #000000 colors, replacing with appropriate values", type: .error)
            
            // Simple string replacement for light theme
            modifiedConfigData = modifiedConfigData.replacingOccurrences(
                of: "\"base00\" : \"#000000\"",
                with: "\"base00\" : \"#f8f8f8\""
            )
            
            // Make sure dark theme uses dark gray instead of black
            if modifiedConfigData.contains("\"darkTheme\"")
               && modifiedConfigData.contains("\"base00\" : \"#000000\"") {
                modifiedConfigData = modifiedConfigData.replacingOccurrences(
                    of: "\"base00\" : \"#000000\"",
                    with: "\"base00\" : \"#181818\""
                )
            }
            
            logMessage("Replaced black colors in configuration")
        }

        // Use NSDistributedNotificationCenter to broadcast config
        let notification = Notification.Name("TintedMacConfigUpdate")
        DistributedNotificationCenter.default().post(
            name: notification,
            object: "TintedMacHelper",
            userInfo: ["configData": modifiedConfigData]
        )
    }

    private func readConfiguration() -> String? {
        // Use ConfigManager to parse the TOML and return JSON
        do {
            let configManager = ConfigManager.shared
            
            // Check if config file exists, if not create one with proper colors
            let fileManager = FileManager.default
            let homeDir = fileManager.homeDirectoryForCurrentUser.path
            let configPath = "\(homeDir)/.config/tinted-mac/config.toml"
            
            if !fileManager.fileExists(atPath: configPath) {
                logMessage("Config file not found, creating one with default themes", type: .info)
                // Create a config with default themes
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
                
                let config = TintedMacConfig(
                    lightTheme: ThemeConfig(name: "Default Light", type: .base16, colors: lightColors),
                    darkTheme: ThemeConfig(name: "Default Dark", type: .base16, colors: darkColors),
                    currentMode: .dark
                )
                
                configManager.saveConfig(config)
            }
            
            // Load the config and ensure it doesn't have black colors
            var config = configManager.loadConfig()
            
            // Replace any #000000 colors with dark gray
            if config.lightTheme.colors.base00 == "#000000" {
                logMessage("WARNING - Light theme has black base00, replacing with #f8f8f8", type: .error)
                config.lightTheme.colors.base00 = "#f8f8f8"
                configManager.saveConfig(config)
            }
            
            if config.darkTheme.colors.base00 == "#000000" {
                logMessage("WARNING - Dark theme has black base00, replacing with #181818", type: .error)
                config.darkTheme.colors.base00 = "#181818"
                configManager.saveConfig(config)
            }
            
            // Log the theme names for debugging
            logMessage("Current theme names - Light: \(config.lightTheme.name), Dark: \(config.darkTheme.name)")
            
            logMessage("Loaded config with light theme: \(config.lightTheme.name), dark theme: \(config.darkTheme.name)")
            logMessage("Light theme colors sample - base00: \(config.lightTheme.colors.base00), base01: \(config.lightTheme.colors.base01)")
            logMessage("Dark theme colors sample - base00: \(config.darkTheme.colors.base00), base01: \(config.darkTheme.colors.base01)")
            
            // Final check for black colors
            if config.lightTheme.colors.base00 == "#000000" || config.darkTheme.colors.base00 == "#000000" {
                logMessage("WARNING - Default black colors detected, this may cause UI issues", type: .error)
            }
    
            // Serialize to JSON for sending to TintedMacInject
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
            let jsonData = try encoder.encode(config)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                logMessage("Failed to convert JSON data to string", type: .error)
                return nil
            }
    
            // Double-check the JSON string doesn't contain all black colors
            if jsonString.contains("\"base00\" : \"#000000\"") {
                logMessage("WARNING - JSON contains #000000 colors which may cause UI issues", type: .error)
            }
    
            // Log a sample of the JSON for debugging
            let sampleLength = min(100, jsonString.count)
            let sample = jsonString.prefix(sampleLength)
            logMessage("Successfully parsed config and converted to JSON (length: \(jsonString.count))")
            logMessage("JSON sample: \(sample)...", type: .info)
            
            return jsonString
        } catch {
            logMessage("Failed to read/parse config: \(error.localizedDescription)", type: .error)
            return nil
        }
    }

    // MARK: - TintedMacHelperProtocol Implementation
    @objc func getCurrentConfiguration(withReply completion: @escaping (String?) -> Void) {
        logMessage("getCurrentConfiguration() called via XPC")
        completion(readConfiguration())
    }

    @objc func ping(withReply completion: @escaping (Bool) -> Void) {
        logMessage("ping() called via XPC")
        completion(true)
    }

    private func setupFileMonitoring() {
        let configURL = URL(fileURLWithPath: configPath)
        let configDir = configURL.deletingLastPathComponent()

        // Create config directory if it doesn't exist
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // Monitor the config file for changes
        let fileDescriptor = open(configPath, O_EVTONLY)
        if fileDescriptor >= 0 {
            fileMonitor = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: .write,
                queue: DispatchQueue.main
            )

            fileMonitor?.setEventHandler { [weak self] in
                logMessage("Config file changed, broadcasting update", type: .info)
                // Read the current config file content for debugging
                if let fileContent = try? String(contentsOfFile: self?.configPath ?? "") {
                    logMessage("Current config file content: \(fileContent)")
                }
                
                // Force reload the config from disk and broadcast it
                guard let self = self else { return }
                let configManager = ConfigManager.shared
                let config = configManager.loadConfig()
                
                // Serialize to JSON for sending
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let jsonData = try encoder.encode(config)
                    
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        // Store this as the last broadcast config
                        self.lastBroadcastConfig = jsonString
                        
                        // Use NSDistributedNotificationCenter to broadcast config
                        let notification = Notification.Name("TintedMacConfigUpdate")
                        DistributedNotificationCenter.default().post(
                            name: notification,
                            object: "TintedMacHelper",
                            userInfo: ["configData": jsonString]
                        )
                        
                        logMessage("Broadcast updated config from file change")
                    }
                } catch {
                    logMessage("Failed to encode config: \(error)", type: .error)
                }
            }

            fileMonitor?.setCancelHandler {
                close(fileDescriptor)
            }

            fileMonitor?.resume()
            logMessage("File monitoring setup for \(configPath)")
        } else {
            logMessage("Failed to setup file monitoring for \(configPath)", type: .error)
        }
    }
}



// MARK: - Main Entry Point
let helper = TintedMacHelper()
helper.start()
