//
//  TintedMacInject.swift
//  TintedMacInject
//
//  Theme injection dylib for TintedMac
//

import Cocoa
import TintedThemingSwift
import TintedMacConfig
import os.log
import Darwin
import Foundation

// Import shared protocol definitions
import class Foundation.NSXPCConnection
import class Foundation.NSXPCInterface

// Import shared protocol file
import TintedMacProtocol

// MARK: - Logging
fileprivate let logger = Logger(subsystem: "com.aspauldingcode.TintedMac.inject", category: "TintedMacInject")

// Configuration is now handled by shared TintedMacConfig module
// TintedMacInject receives pre-parsed JSON from TintedMacHelper

@objc public class TintedMacInject: NSObject {
    @objc public static var shared: TintedMacInject?
    var currentConfig: TintedMacConfig?

    var isIPCConnected: Bool = false
    var originalWindowTitles: [NSWindow: String] = [:]
    private var lastConfigUpdateTime: Date = Date.distantPast
    private var helperConnection: NSXPCConnection?

    override init() {
        super.init()
        NSLog("TintedMacInject: init() called, setting up IPC configuration listener")

        // Setup distributed notification listener for config updates
        setupConfigurationListener()

        // Try to establish XPC connection after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if let self = self {
                let success = self.establishDOConnection()
                if success {
                    NSLog("TintedMacInject: Successfully established XPC connection to helper")
                } else {
                    NSLog("TintedMacInject: Failed to establish XPC connection, will rely on distributed notifications")
                    // Show error titles since helper is not available
                    self.updateAllWindowTitles()
                }
            }
        }

        // Set up simple periodic check to update window titles and ping helper (every 10 seconds)
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.pingHelperAndUpdateStatus()
        }

        NSLog("TintedMacInject: init() completed, waiting for configuration from helper process")


    }

    deinit {
        // Cleanup if needed
    }

    @objc public static func initializeInjection() {
        do {
            NSLog("TintedMacInject: Initializing injection")
            let injector = TintedMacInject()
            TintedMacInject.shared = injector
            try injector.setupInjection()
            NSLog("TintedMacInject: Injection initialized successfully")
        } catch {
            NSLog("TintedMacInject: Failed to initialize injection: %@", error.localizedDescription)
            logger.error("Failed to initialize injection: \(error.localizedDescription)")
        }
    }

    private func setupInjection() throws {
        logger.info("Setting up theme injection")

        // Apply theme to all existing windows with error handling
        for window in NSApplication.shared.windows {
            do {
                try applyTheme(to: window)
            } catch {
                NSLog("TintedMacInject: Warning - Failed to apply theme to window: %@", error.localizedDescription)
                logger.warning("Failed to apply theme to window: \(error.localizedDescription)")
                // Continue with other windows
            }
        }

        // Monitor for new windows with error handling
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.windowDidBecomeKey(notification)
        }

        // Monitor for new windows being created
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.windowDidOpen(notification)
        }

        // Monitor for theme changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TintedMacThemeDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleConfigurationUpdate(notification)
        }

        // Monitor for appearance changes
         NotificationCenter.default.addObserver(
             forName: NSApplication.didChangeScreenParametersNotification,
             object: nil,
             queue: .main
         ) { [weak self] notification in
             self?.systemAppearanceDidChange(notification)
         }

         // Also monitor for system color changes which can indicate appearance changes
         NotificationCenter.default.addObserver(
             forName: NSColor.systemColorsDidChangeNotification,
             object: nil,
             queue: .main
         ) { [weak self] notification in
             self?.systemAppearanceDidChange(notification)
         }

         // Monitor for fullscreen transitions to reapply theming
         NotificationCenter.default.addObserver(
             forName: NSWindow.didEnterFullScreenNotification,
             object: nil,
             queue: .main
         ) { [weak self] notification in
             self?.windowDidEnterFullScreen(notification)
         }

         NotificationCenter.default.addObserver(
             forName: NSWindow.didExitFullScreenNotification,
             object: nil,
             queue: .main
         ) { [weak self] notification in
             self?.windowDidExitFullScreen(notification)
         }

        logger.info("Theme injection setup complete")
    }

    // MARK: - XPC IPC

    private func establishDOConnection() -> Bool {
        NSLog("TintedMacInject: Attempting to connect to TintedMacHelper via NSXPCConnection")

        // Create a new XPC connection to the helper service
        let connection = NSXPCConnection(machServiceName: TintedMacConnection.machServiceName)
        
        // Configure the connection
        connection.remoteObjectInterface = NSXPCInterface(with: TintedMacHelperProtocol.self)
        
        // Set up error handling
        connection.invalidationHandler = { [weak self] in
            NSLog("TintedMacInject: XPC connection invalidated")
            self?.isIPCConnected = false
            self?.handleHelperQuit()
        }
        
        connection.interruptionHandler = { [weak self] in
            NSLog("TintedMacInject: XPC connection interrupted")
            self?.isIPCConnected = false
            self?.handleHelperQuit()
        }
        
        // Activate the connection
        connection.resume()
        
        // Store the connection
        self.helperConnection = connection
        
        // Get the remote proxy object
        guard let remoteProxy = connection.remoteObjectProxyWithErrorHandler({ error in
            NSLog("TintedMacInject: Error getting remote proxy: \(error)")
            self.isIPCConnected = false
            return
        }) as? TintedMacHelperProtocol else {
            NSLog("TintedMacInject: Failed to get remote proxy")
            self.isIPCConnected = false
            return false
        }
        
        // Test the connection with a ping
        var connectionResult = false
        let semaphore = DispatchSemaphore(value: 0)
        
        remoteProxy.ping(withReply: { success in
            if success {
                NSLog("TintedMacInject: Successfully connected to TintedMacHelper via NSXPCConnection")
                self.isIPCConnected = true
                
                // Get the current configuration
                remoteProxy.getCurrentConfiguration(withReply: { configData in
                    if let configData = configData {
                        NSLog("TintedMacInject: Received configuration from helper via NSXPCConnection")
                        DispatchQueue.main.async {
                            self.processConfigurationFromHelper(configData)
                            NSLog("TintedMacInject: IPC connection established and config received")
                        }
                        connectionResult = true
                    } else {
                        NSLog("TintedMacInject: Helper connected but no configuration available")
                    }
                    semaphore.signal()
                })
            } else {
                NSLog("TintedMacInject: NSXPCConnection ping failed")
                self.isIPCConnected = false
                semaphore.signal()
            }
        })
        
        // Wait for the ping to complete
        _ = semaphore.wait(timeout: .now() + 5.0) // 5 second timeout
        return connectionResult
    }



    private func setupConfigurationListener() {
        NSLog("TintedMacInject: Setting up distributed notification listener")

        let notificationName = Notification.Name("TintedMacConfigUpdate")
        NSLog("TintedMacInject: Registering for notification: \(notificationName) from object: TintedMacHelper")
        
        DistributedNotificationCenter.default().addObserver(forName: notificationName, object: "TintedMacHelper", queue: .main) { [weak self] notification in
            NSLog("TintedMacInject: Distributed notification received!")
            NSLog("TintedMacInject: Notification details - name: \(notification.name), object: \(String(describing: notification.object))")
            self?.handleConfigurationUpdate(notification)
        }

        NSLog("TintedMacInject: Distributed notification listener setup complete for name: \(notificationName)")
        NSLog("TintedMacInject: Current notification center: \(DistributedNotificationCenter.default())")
    }





    private func handleHelperQuit() {
        NSLog("TintedMacInject: Helper disconnected - clearing configuration and stopping tinting")

        // Clear current configuration
        currentConfig = nil
        isIPCConnected = false

        // Update window titles to show error and remove theme from all windows
        DispatchQueue.main.async { [weak self] in
            self?.updateAllWindowTitles() // Show error titles
            self?.removeThemeFromAllWindows()
        }
    }

    private func removeThemeFromAllWindows() {
        NSLog("TintedMacInject: Removing theme from all windows due to helper quit")

        for window in NSApplication.shared.windows {
            removeTheme(from: window)
        }
    }

    private func removeTheme(from window: NSWindow) {
        // Remove any tinting layers or effects applied to the window
        if let contentView = window.contentView {
            removeThemeFromView(contentView)
        }

        // Restore original window title if we have it stored
        if let originalTitle = originalWindowTitles[window] {
            window.title = originalTitle
            originalWindowTitles.removeValue(forKey: window)
        }


    }

    private func pingHelperAndUpdateStatus() {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastConfigUpdateTime)
        
        // If we have a connection, ping the helper to keep it alive
        if let connection = helperConnection, isIPCConnected {
            guard let remoteProxy = connection.remoteObjectProxyWithErrorHandler({ error in
                NSLog("TintedMacInject: Error getting remote proxy for ping: \(error)")
                self.isIPCConnected = false
                self.updateAllWindowTitles()
            }) as? TintedMacHelperProtocol else {
                NSLog("TintedMacInject: Failed to get remote proxy for ping")
                self.isIPCConnected = false
                self.updateAllWindowTitles()
                return
            }
            
            // Send a ping to keep the connection alive
            remoteProxy.ping(withReply: { success in
                if success {
                    NSLog("TintedMacInject: Ping successful, connection is alive")
                    self.isIPCConnected = true
                } else {
                    NSLog("TintedMacInject: Ping failed, connection may be broken")
                    self.isIPCConnected = false
                }
                self.updateAllWindowTitles()
            })
        } else if timeSinceLastUpdate > 30.0 {
            // If we haven't received config updates for 30 seconds and don't have a connection, try to reconnect
            NSLog("TintedMacInject: No configuration updates for %.1f seconds, attempting to reconnect", timeSinceLastUpdate)
            let success = establishDOConnection()
            if !success {
                handleHelperQuit()
            }
        } else {
            // Just update titles based on current status
            updateAllWindowTitles()
        }
    }

    private func updateAllWindowTitles() {
        NSLog("TintedMacInject: Updating window titles, IPC connected: %@", isIPCConnected ? "YES" : "NO")

        for window in NSApplication.shared.windows {
            if window.styleMask.contains(.titled) {
                // Store original title if not already stored
                if originalWindowTitles[window] == nil {
                    originalWindowTitles[window] = window.title
                }

                // Update title based on IPC status
                let originalTitle = originalWindowTitles[window] ?? window.title
                if isIPCConnected {
                    // IPC is working - restore original titles
                    window.title = originalTitle
                } else {
                    // No IPC connection - show error
                    let errorTitle = "⚠️ TintedMac Error - Must start TintedMacHelper process"
                    window.title = errorTitle
                }
            }
        }
    }

    private func removeThemeFromView(_ view: NSView) {
        // Remove any tinting layers we may have added
        if let layer = view.layer {
            layer.backgroundColor = nil
            layer.borderColor = nil
        }

        // Recursively remove from subviews
        for subview in view.subviews {
            removeThemeFromView(subview)
        }
    }

    private func handleConfigurationUpdate(_ notification: Notification) {
        NSLog("TintedMacInject: Received configuration update notification")

        guard let userInfo = notification.userInfo,
              let configData = userInfo["configData"] as? String else {
            NSLog("TintedMacInject: Invalid configuration data in notification")
            NSLog("TintedMacInject: Notification userInfo: \(notification.userInfo ?? [:])")
            return
        }

        NSLog("TintedMacInject: Processing configuration update from helper via IPC")
        NSLog("TintedMacInject: Notification name: \(notification.name)")
        NSLog("TintedMacInject: Notification object: \(String(describing: notification.object))")
        NSLog("TintedMacInject: Notification received at: \(Date())")
        self.isIPCConnected = true
        self.lastConfigUpdateTime = Date()  // Record when we last heard from helper
        processConfigurationFromHelper(configData)

        // Apply themes to existing windows and restore normal titles
        DispatchQueue.main.async { [weak self] in
            NSLog("TintedMacInject: Applying theme to existing windows after configuration update")
            self?.updateAllWindowTitles() // Clear any error titles
            self?.applyThemeToExistingWindows()
        }
    }

    private func processConfigurationFromHelper(_ configData: String) {
        // Parse JSON configuration sent by TintedMacHelper
        NSLog("TintedMacInject: Processing configuration data of length: \(configData.count)")
        
        // Log the first 100 characters of config data for quick inspection
        let previewLength = min(100, configData.count)
        let configPreview = String(configData.prefix(previewLength))
        NSLog("TintedMacInject: Config data preview: \(configPreview)\(configData.count > previewLength ? "..." : "")")
        
        // Check for black colors in the JSON and replace them before parsing
        var modifiedConfigData = configData
        if configData.contains("\"base00\" : \"#000000\"") {
            NSLog("TintedMacInject: WARNING - Found black colors in config JSON, replacing before parsing")
            
            // Replace all instances of black colors with appropriate values for each theme
            if configData.contains("\"lightTheme\"") && configData.contains("\"base00\" : \"#000000\"") {
                modifiedConfigData = modifiedConfigData.replacingOccurrences(
                    of: "\"base00\" : \"#000000\"",
                    with: "\"base00\" : \"#f8f8f8\""
                )
                NSLog("TintedMacInject: Replaced black colors in light theme")
            }
            
            // Make sure we replace any remaining black colors for dark theme
            if modifiedConfigData.contains("\"base00\" : \"#000000\"") {
                modifiedConfigData = modifiedConfigData.replacingOccurrences(
                    of: "\"base00\" : \"#000000\"",
                    with: "\"base00\" : \"#181818\""
                )
                NSLog("TintedMacInject: Replaced black colors in dark theme")
            }
        }
        
        // Log the modified config data for debugging
        NSLog("TintedMacInject: Using modified config data: \(modifiedConfigData.prefix(100))...")
        
        guard let jsonData = modifiedConfigData.data(using: .utf8) else {
            NSLog("TintedMacInject: Failed to convert config string to data")
            return
        }
        
        NSLog("TintedMacInject: Successfully converted config string to data of size: \(jsonData.count) bytes")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        do {
            var config = try decoder.decode(TintedMacConfig.self, from: jsonData)
            
            // Double-check for any black colors that might have slipped through
            if config.lightTheme.colors.base00 == "#000000" {
                NSLog("TintedMacInject: WARNING - Light theme still has black base00, replacing with #f8f8f8")
                config.lightTheme.colors.base00 = "#f8f8f8"
            }
            
            if config.darkTheme.colors.base00 == "#000000" {
                NSLog("TintedMacInject: WARNING - Dark theme has black base00, replacing with #181818")
                config.darkTheme.colors.base00 = "#181818"
            }
            
            // Log theme colors for debugging
            let isDarkMode = isDarkMode()
            let selectedTheme = isDarkMode ? config.darkTheme : config.lightTheme
            NSLog("TintedMacInject: Successfully decoded configuration")
            NSLog("TintedMacInject: Using \(isDarkMode ? "dark" : "light") theme: \(selectedTheme.name) of type: \(selectedTheme.type)")
            
            // Log all theme colors for debugging
            NSLog("TintedMacInject: Theme colors - base00: \(selectedTheme.colors.base00)")
            NSLog("TintedMacInject: Theme colors - base01: \(selectedTheme.colors.base01)")
            NSLog("TintedMacInject: Theme colors - base02: \(selectedTheme.colors.base02)")
            NSLog("TintedMacInject: Theme colors - base03: \(selectedTheme.colors.base03)")
            NSLog("TintedMacInject: Theme colors - base04: \(selectedTheme.colors.base04)")
            NSLog("TintedMacInject: Theme colors - base05: \(selectedTheme.colors.base05)")
            NSLog("TintedMacInject: Theme colors - base06: \(selectedTheme.colors.base06)")
            NSLog("TintedMacInject: Theme colors - base07: \(selectedTheme.colors.base07)")
            NSLog("TintedMacInject: Theme colors - base08: \(selectedTheme.colors.base08)")
            NSLog("TintedMacInject: Theme colors - base09: \(selectedTheme.colors.base09)")
            NSLog("TintedMacInject: Theme colors - base0A: \(selectedTheme.colors.base0A)")
            NSLog("TintedMacInject: Theme colors - base0B: \(selectedTheme.colors.base0B)")
            NSLog("TintedMacInject: Theme colors - base0C: \(selectedTheme.colors.base0C)")
            NSLog("TintedMacInject: Theme colors - base0D: \(selectedTheme.colors.base0D)")
            NSLog("TintedMacInject: Theme colors - base0E: \(selectedTheme.colors.base0E)")
            NSLog("TintedMacInject: Theme colors - base0F: \(selectedTheme.colors.base0F)")
            
            // Store the config
            self.currentConfig = config
            NSLog("TintedMacInject: Configuration stored successfully")
        } catch {
            NSLog("TintedMacInject: JSON decoding error: \(error)")
            
            // Try to debug the JSON structure
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
               let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let prettyPrintedJson = String(data: prettyJsonData, encoding: .utf8) {
                NSLog("TintedMacInject: JSON structure: \(prettyPrintedJson)")
            } else {
                NSLog("TintedMacInject: Failed to pretty print JSON for debugging")
            }
        }
    }

    private func applyThemeToExistingWindows() {
        for window in NSApplication.shared.windows {
            do {
                try applyTheme(to: window)
            } catch {
                NSLog("TintedMacInject: Failed to apply theme to existing window: %@", error.localizedDescription)
                // Continue with other windows
            }
        }
    }







    private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        do {
            try applyTheme(to: window)
        } catch {
            NSLog("TintedMacInject: Failed to apply theme to window that became key: %@", error.localizedDescription)
        }
    }

    private func windowDidOpen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        do {
            try applyTheme(to: window)
        } catch {
            NSLog("TintedMacInject: Failed to apply theme to newly opened window: %@", error.localizedDescription)
        }
    }

    private func windowDidEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Reapply theming after entering fullscreen with a delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            do {
                try self.applyTheme(to: window)
            } catch {
                NSLog("TintedMacInject: Failed to reapply theme after entering fullscreen: %@", error.localizedDescription)
            }
        }
    }

    private func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Reapply theming after exiting fullscreen with a delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            do {
                try self.applyTheme(to: window)
            } catch {
                NSLog("TintedMacInject: Failed to reapply theme after exiting fullscreen: %@", error.localizedDescription)
            }
        }
    }

    private func themeDidChange(_ notification: Notification) {
        // Apply theme to all windows when theme changes
        applyThemeToExistingWindows()
    }

    private func systemAppearanceDidChange(_ notification: Notification) {
        NSLog("TintedMacInject: System appearance changed, re-applying themes")

        guard currentConfig != nil else {
            NSLog("TintedMacInject: No configuration loaded, skipping re-tinting")
            return
        }

        // Re-apply theme to all visible windows
        for window in NSApp.windows {
            guard window.isVisible else { continue }

            do {
                try applyTheme(to: window)
                NSLog("TintedMacInject: Re-applied theme to window '%@'", window.title as NSString? ?? "Untitled")
            } catch {
                NSLog("TintedMacInject: Failed to re-apply theme to window '%@': %@",
                      window.title as NSString? ?? "Untitled", error.localizedDescription)
            }
        }
    }

    private func isDarkMode() -> Bool {
        // Simple, reliable appearance detection using NSApp.effectiveAppearance
        guard let appearance = NSApp?.effectiveAppearance else {
            // Fallback to system appearance if NSApp is not available
            return NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    enum ThemeError: Error {
        case configurationMissing
        case invalidColor(String)
        case windowAccessFailed
    }

    private func applyTheme(to window: NSWindow) throws {
        guard let config = currentConfig else {
            NSLog("TintedMacInject: Cannot apply theme - configuration is missing")
            throw ThemeError.configurationMissing
        }

        // Always follow system appearance - select theme based on current appearance
        let isDarkMode = isDarkMode()
        let theme = isDarkMode ? config.darkTheme : config.lightTheme

        NSLog("TintedMacInject: Theme selection for window '%@' - isDarkMode: %@, selected theme: %@, theme type: %@",
              window.title as NSString? ?? "Untitled",
              isDarkMode ? "true" : "false",
              theme.name as NSString,
              theme.type.rawValue as NSString)

        // Log window properties for debugging
        NSLog("TintedMacInject: Window properties - isVisible: %@, isKeyWindow: %@, styleMask: %d",
              window.isVisible ? "true" : "false",
              window.isKeyWindow ? "true" : "false",
              window.styleMask.rawValue)

        // Apply appearance with error handling
        do {
            // Bypass system appearance and set based on theme
            let oldAppearance = window.appearance
            NSLog("TintedMacInject: Changing window.appearance from %@ to nil", String(describing: oldAppearance))
            window.appearance = nil

            // Apply background color from theme
            NSLog("TintedMacInject: Attempting to create NSColor from hex: %@", theme.colors.base00)
            if let bgColor = NSColor(hex: theme.colors.base00) {
                NSLog("TintedMacInject: Setting window background color to: %@", theme.colors.base00)
                window.backgroundColor = bgColor
                NSLog("TintedMacInject: Window background color set successfully")
            } else {
                NSLog("TintedMacInject: Failed to create NSColor from hex: %@", theme.colors.base00)
            }

            // Apply titlebar colorization
            NSLog("TintedMacInject: Applying titlebar theme with base01: %@", theme.colors.base01)
            try applyTitlebarTheme(to: window, theme: theme)

            // Apply traffic lights colorization
            NSLog("TintedMacInject: Applying traffic lights theme with base08: %@, base0A: %@, base0B: %@", 
                  theme.colors.base08, theme.colors.base0A, theme.colors.base0B)
            try applyTrafficLightsTheme(to: window, theme: theme)

            // Apply to content view if it exists
            if let contentView = window.contentView {
                NSLog("TintedMacInject: Found content view of type: %@, applying theme", String(describing: type(of: contentView)))
                contentView.appearance = window.appearance

                // Apply theme colors to the content view hierarchy
                try applyThemeToView(contentView, theme: theme)
            } else {
                NSLog("TintedMacInject: Window has no content view")
            }

            // Force window to redraw
            NSLog("TintedMacInject: Forcing window redraw")
            window.contentView?.needsDisplay = true
            window.display()

            NSLog("TintedMacInject: Applied theme '%@' to window: %@", theme.name as NSString, window.title as NSString? ?? "Untitled")
        } catch {
            NSLog("TintedMacInject: Error applying theme to window: %@", error.localizedDescription)
            throw error
        }
    }

    private func applyThemeToView(_ view: NSView, theme: ThemeConfig) throws {
        // Apply theme colors based on view type (simplified for safety)
        if let textField = view as? NSTextField {
            // Only apply text color, not background to avoid weird UI artifacts
            if let textColor = NSColor(hex: theme.colors.base05) {
                textField.textColor = textColor
            }
            // Don't modify background for text fields to preserve native appearance
        } else if let button = view as? NSButton {
            if let contentColor = NSColor(hex: theme.colors.base05) {
                button.contentTintColor = contentColor
            }
            // Apply button background for certain button types
            if button.bezelStyle == .rounded || button.bezelStyle == .regularSquare {
                if let bgColor = NSColor(hex: theme.colors.base01) {
                    button.layer?.backgroundColor = bgColor.cgColor
                }
            }
        } else if let scrollView = view as? NSScrollView {
            if let bgColor = NSColor(hex: theme.colors.base01) {
                scrollView.backgroundColor = bgColor
                scrollView.documentView?.layer?.backgroundColor = bgColor.cgColor
            }
        } else if let tableView = view as? NSTableView {
            if let bgColor = NSColor(hex: theme.colors.base00) {
                tableView.backgroundColor = bgColor
                // Disable alternating row colors for consistent theming
                tableView.usesAlternatingRowBackgroundColors = false
            }
        } else if let outlineView = view as? NSOutlineView {
            if let bgColor = NSColor(hex: theme.colors.base00) {
                outlineView.backgroundColor = bgColor
            }
        }

        // Apply general view background
        if let bgColor = NSColor(hex: theme.colors.base00) {
            view.layer?.backgroundColor = bgColor.cgColor
            view.wantsLayer = true
        }

        // Force view to redraw
        view.needsDisplay = true

        // Recursively apply to subviews with error handling
        for subview in view.subviews {
            do {
                try applyThemeToView(subview, theme: theme)
            } catch {
                // Log error but continue with other subviews
                NSLog("TintedMacInject: Warning - Failed to apply theme to subview: %@", error.localizedDescription)
            }
        }
    }

    private func applyTitlebarTheme(to window: NSWindow, theme: ThemeConfig) throws {
        // Determine if this is a dark theme by checking if it matches the dark theme in config
        let isDarkTheme = currentConfig?.darkTheme.name == theme.name
        NSLog("TintedMacInject: Applying titlebar theme, isDarkTheme: %@, window title: %@", 
              isDarkTheme ? "true" : "false", 
              window.title as NSString? ?? "Untitled")
        
        // Find and modify titlebar elements
        guard let titlebarView = findTitlebarView(in: window) else {
            NSLog("TintedMacInject: Could not find titlebar view for window: %@", window.title as NSString? ?? "Untitled")
            return
        }
        NSLog("TintedMacInject: Found titlebar view: %@, frame: %@", 
              String(describing: type(of: titlebarView)),
              NSStringFromRect(titlebarView.frame))

        // Apply titlebar background color
        NSLog("TintedMacInject: Attempting to create titlebar color from hex: %@", theme.colors.base01)
        if let titlebarColor = NSColor(hex: theme.colors.base01) {
            NSLog("TintedMacInject: Setting titlebar background color to: %@", theme.colors.base01)
            titlebarView.wantsLayer = true
            let oldColor = titlebarView.layer?.backgroundColor != nil ? 
                NSColor(cgColor: titlebarView.layer!.backgroundColor!) : nil
            NSLog("TintedMacInject: Changing titlebar background from %@ to %@", 
                  String(describing: oldColor), 
                  String(describing: titlebarColor))
            titlebarView.layer?.backgroundColor = titlebarColor.cgColor
        } else {
            NSLog("TintedMacInject: Failed to create NSColor from hex: %@", theme.colors.base01)
        }

        // Find and colorize title text
        if let titleTextField = findTitleTextField(in: titlebarView) {
            NSLog("TintedMacInject: Found title text field: %@, current text: %@", 
                  String(describing: type(of: titleTextField)),
                  titleTextField.stringValue as NSString)
            
            NSLog("TintedMacInject: Attempting to create text color from hex: %@", theme.colors.base05)
            if let textColor = NSColor(hex: theme.colors.base05) {
                let oldTextColor = titleTextField.textColor
                NSLog("TintedMacInject: Setting titlebar text color from %@ to %@", 
                      String(describing: oldTextColor),
                      String(describing: textColor))
                titleTextField.textColor = textColor
            } else {
                NSLog("TintedMacInject: Failed to create text color from hex: %@", theme.colors.base05)
            }
        } else {
            NSLog("TintedMacInject: Could not find title text field")
        }

        NSLog("TintedMacInject: Applied titlebar theme to window: %@", window.title as NSString? ?? "Untitled")
    }

    private func findTitlebarView(in window: NSWindow) -> NSView? {
        // Look for the titlebar container view
        let windowFrame = window.contentView?.superview
        return findViewByClassName(windowFrame, className: "NSTitlebarContainerView")
    }

    private func findTitleTextField(in titlebarView: NSView) -> NSTextField? {
        // Recursively search for title text field
        if let textField = titlebarView as? NSTextField {
            return textField
        }

        for subview in titlebarView.subviews {
            if let found = findTitleTextField(in: subview) {
                return found
            }
        }

        return nil
    }

    private func findViewByClassName(_ view: NSView?, className: String) -> NSView? {
        guard let view = view else { return nil }

        if NSStringFromClass(type(of: view)).contains(className) {
            return view
        }

        for subview in view.subviews {
            if let found = findViewByClassName(subview, className: className) {
                return found
            }
        }

        return nil
     }

     private func applyTrafficLightsTheme(to window: NSWindow, theme: ThemeConfig) throws {
         // Find traffic light buttons
         guard let titlebarView = findTitlebarView(in: window) else {
             NSLog("TintedMacInject: Could not find titlebar for traffic lights in window: %@", window.title as NSString? ?? "Untitled")
             return
         }

         // Find the traffic light buttons container
         let accessoryContainer = findViewByClassName(titlebarView, className: "NSTitlebarAccessoryViewContainer")
         let themeFrame = findViewByClassName(titlebarView, className: "NSThemeFrame")
         
         NSLog("TintedMacInject: Searching for traffic lights container - accessoryContainer: %@, themeFrame: %@",
               accessoryContainer != nil ? "found" : "not found",
               themeFrame != nil ? "found" : "not found")
         
         guard let trafficLightsView = accessoryContainer ?? themeFrame else {
             NSLog("TintedMacInject: Could not find traffic lights container in window: %@", window.title as NSString? ?? "Untitled")
             return
         }
         
         NSLog("TintedMacInject: Found traffic lights container: %@, frame: %@", 
               String(describing: type(of: trafficLightsView)),
               NSStringFromRect(trafficLightsView.frame))

         // Find individual traffic light buttons
         let closeButton = findTrafficLightButton(in: trafficLightsView, type: "Close")
         let minimizeButton = findTrafficLightButton(in: trafficLightsView, type: "Miniaturize")
         let zoomButton = findTrafficLightButton(in: trafficLightsView, type: "Zoom")
         
         NSLog("TintedMacInject: Found traffic light buttons - close: %@, minimize: %@, zoom: %@", 
               closeButton != nil ? "yes" : "no",
               minimizeButton != nil ? "yes" : "no",
               zoomButton != nil ? "yes" : "no")

         // Log button details if found
         if let close = closeButton {
             NSLog("TintedMacInject: Close button details - frame: %@, class: %@", 
                   NSStringFromRect(close.frame),
                   String(describing: type(of: close)))
         }
         
         if let minimize = minimizeButton {
             NSLog("TintedMacInject: Minimize button details - frame: %@, class: %@", 
                   NSStringFromRect(minimize.frame),
                   String(describing: type(of: minimize)))
         }
         
         if let zoom = zoomButton {
             NSLog("TintedMacInject: Zoom button details - frame: %@, class: %@", 
                   NSStringFromRect(zoom.frame),
                   String(describing: type(of: zoom)))
         }

         // Apply custom colors to traffic lights
         NSLog("TintedMacInject: Attempting to create close button color from hex: %@", theme.colors.base08)
         if let close = closeButton, let closeColor = NSColor(hex: theme.colors.base08) {
             NSLog("TintedMacInject: Applying close button color: %@", theme.colors.base08)
             applyTrafficLightColor(to: close, color: closeColor, type: "close")
         } else if closeButton != nil {
             NSLog("TintedMacInject: Failed to create close button color from hex: %@", theme.colors.base08)
         }

         NSLog("TintedMacInject: Attempting to create minimize button color from hex: %@", theme.colors.base0A)
         if let minimize = minimizeButton, let minimizeColor = NSColor(hex: theme.colors.base0A) {
             NSLog("TintedMacInject: Applying minimize button color: %@", theme.colors.base0A)
             applyTrafficLightColor(to: minimize, color: minimizeColor, type: "minimize")
         } else if minimizeButton != nil {
             NSLog("TintedMacInject: Failed to create minimize button color from hex: %@", theme.colors.base0A)
         }

         NSLog("TintedMacInject: Attempting to create zoom button color from hex: %@", theme.colors.base0B)
         if let zoom = zoomButton, let zoomColor = NSColor(hex: theme.colors.base0B) {
             NSLog("TintedMacInject: Applying zoom button color: %@", theme.colors.base0B)
             applyTrafficLightColor(to: zoom, color: zoomColor, type: "zoom")
         } else if zoomButton != nil {
             NSLog("TintedMacInject: Failed to create zoom button color from hex: %@", theme.colors.base0B)
         }

         NSLog("TintedMacInject: Applied traffic lights theme to window: %@", window.title as NSString? ?? "Untitled")
     }

     private func findTrafficLightButton(in view: NSView, type: String) -> NSButton? {
         // Look for buttons with specific action selectors
         if let button = view as? NSButton {
             let actionString = button.action?.description ?? ""
             if actionString.contains(type.lowercased()) || actionString.contains(type) {
                 return button
             }
         }

         // Recursively search subviews
         for subview in view.subviews {
             if let found = findTrafficLightButton(in: subview, type: type) {
                 return found
             }
         }

         return nil
     }

     private func applyTrafficLightColor(to button: NSButton, color: NSColor, type: String) {
         // Enable layer-backed view for custom drawing
         button.wantsLayer = true
         NSLog("TintedMacInject: Setting up %@ traffic light button with color: %@, button frame: %@", 
               type, color, NSStringFromRect(button.frame))

         // Log button's current state
         NSLog("TintedMacInject: Button %@ current state - enabled: %@, hidden: %@, layer-backed: %@", 
               type,
               button.isEnabled ? "yes" : "no",
               button.isHidden ? "yes" : "no",
               button.wantsLayer ? "yes" : "no")

         // Create a custom layer with the theme color
         let colorLayer = CALayer()
         colorLayer.backgroundColor = color.cgColor
         colorLayer.cornerRadius = 6.0 // Standard traffic light radius
         colorLayer.frame = CGRect(x: 0, y: 0, width: 12, height: 12)
         
         NSLog("TintedMacInject: Created color layer for %@ button with frame: %@, color: %@, cornerRadius: %.1f", 
               type, 
               NSStringFromRect(colorLayer.frame), 
               color,
               colorLayer.cornerRadius)

         // Clear existing layers and add our custom color layer
         let existingLayerCount = button.layer?.sublayers?.count ?? 0
         NSLog("TintedMacInject: Removing %d existing sublayers from %@ button", existingLayerCount, type)
         
         if existingLayerCount > 0 {
             NSLog("TintedMacInject: Existing sublayers for %@ button: %@", 
                   type, 
                   String(describing: button.layer?.sublayers))
         }
         
         button.layer?.sublayers?.removeAll()
         button.layer?.addSublayer(colorLayer)
         
         NSLog("TintedMacInject: After adding color layer, %@ button has %d sublayers", 
               type, 
               button.layer?.sublayers?.count ?? 0)

         // Ensure the button maintains its functionality
         button.layer?.masksToBounds = false

         NSLog("TintedMacInject: Applied %@ traffic light color successfully", type)
     }
 }

// MARK: - Color Extensions

// NSColor extension for hex color parsing (consistent with AppearanceManager.swift)
extension NSColor {
    convenience init?(hex: String) {
        // Remove only whitespace and preserve the hashtag
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("TintedMacInject: Parsing hex color: \(hex), cleaned to: \(cleanHex)")
        
        // Check for empty or invalid hex strings
        if cleanHex.isEmpty {
            NSLog("TintedMacInject: Empty hex color string, using fallback dark gray")
            self.init(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            return
        }
        
        // Replace pure black (#000000) with a dark gray to prevent UI issues
        if cleanHex.lowercased() == "#000000" {
            NSLog("TintedMacInject: Pure black color detected, using dark gray #181818 instead")
            self.init(red: 0.094, green: 0.094, blue: 0.094, alpha: 1.0) // #181818
            return
        }
        
        let hexString = cleanHex.hasPrefix("#") ? String(cleanHex.dropFirst()) : cleanHex
        NSLog("TintedMacInject: Hex string for parsing: \(hexString)")

        var int: UInt64 = 0
        let scanSuccess = Scanner(string: hexString).scanHexInt64(&int)
        
        // If scanning fails, use a default color
        if !scanSuccess {
            NSLog("TintedMacInject: Failed to parse hex color: \(cleanHex), using fallback gray")
            self.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            return
        }
        
        NSLog("TintedMacInject: Successfully parsed hex color \(cleanHex) to int value: \(int)")
         
         let a, r, g, b: UInt64
         switch hexString.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            NSLog("TintedMacInject: Parsed 3-digit hex color - r: \(r), g: \(g), b: \(b), a: \(a)")
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            NSLog("TintedMacInject: Parsed 6-digit hex color - r: \(r), g: \(g), b: \(b), a: \(a)")
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            NSLog("TintedMacInject: Parsed 8-digit hex color - r: \(r), g: \(g), b: \(b), a: \(a)")
        default:
            NSLog("TintedMacInject: Invalid hex color format: \(cleanHex), using fallback")
            self.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            return
        }

        let redComponent = Double(r) / 255
        let greenComponent = Double(g) / 255
        let blueComponent = Double(b) / 255
        let alphaComponent = Double(a) / 255
        
        NSLog("TintedMacInject: Final color components - red: \(redComponent), green: \(greenComponent), blue: \(blueComponent), alpha: \(alphaComponent)")
        
        self.init(
            red: redComponent,
            green: greenComponent,
            blue: blueComponent,
            alpha: Double(a) / 255
        )
    }
}

// MARK: - Safety Checks

private func isSafeToInject() -> Bool {
    let processName = ProcessInfo.processInfo.processName
    let bundleID = Bundle.main.bundleIdentifier

    // Skip injection into our own components
    if processName.hasPrefix("TintedMac") {
        return false
    }

    // Skip command-line tools and system processes
    let commandLineTools = [
        "sh", "bash", "zsh", "fish", "csh", "tcsh",
        "make", "swift", "swift-build", "swift-package", "swiftc",
        "ls", "rm", "cp", "mv", "mkdir", "cat", "grep", "find", "git",
        "launchctl", "sudo", "ditto", "xcodebuild", "xcrun",
        "oh-my-posh", "starship", "powerlevel10k"
    ]

    if commandLineTools.contains(processName) {
        return false
    }

    // Skip system daemons and background processes
    if processName.hasSuffix("d") || processName.contains("daemon") ||
       processName.contains("agent") || processName.contains("helper") {
        return false
    }

    // Ensure we have AppKit available
    guard NSClassFromString("NSApplication") != nil else {
        return false
    }

    // Check if this is actually a GUI application by verifying it has windows capability
    guard NSClassFromString("NSWindow") != nil else {
        return false
    }

    // Additional check: ensure the process can create windows (not just link AppKit)
    guard NSClassFromString("NSWindowController") != nil else {
        return false
    }

    // Check if the bundle is an actual app bundle (has .app structure)
    let bundle = Bundle.main
    let bundlePath = bundle.bundlePath

    // Must be in an .app bundle or be a known GUI application
    if !bundlePath.hasSuffix(".app") {
        // Allow some known GUI applications that don't use .app bundles
        let allowedNonAppBundleGUI = [
            "Terminal", "iTerm", "iTerm2", "Hyper", "Alacritty",
            "kitty", "WezTerm", "Finder", "SystemUIServer"
        ]
        if !allowedNonAppBundleGUI.contains(processName) {
            return false
        }
    }

    // Final check: verify the process has an actual window server connection
    // This ensures it's a real GUI app, not just something linking AppKit
    let app = NSApplication.shared
    if app.windows.isEmpty {
        // Give it a moment to initialize windows, but don't inject into processes
        // that clearly don't intend to show windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if app.windows.isEmpty {
                // Still no windows after brief delay - probably not a GUI app
                return
            }
        }
    }

    NSLog("[TintedMac] GUI application detected: %@ (bundle: %@)", processName, bundleID ?? "unknown")
    return true
}

// MARK: - Dylib Constructor
// This function is called automatically when the dylib is loaded
@_cdecl("tinted_mac_dylib_constructor")
public func tinted_mac_dylib_constructor() {
    // Log to both system log and console for debugging
    NSLog("[TintedMac] Dylib constructor called for PID: %d", getpid())
    logger.info("tinted_mac_dylib_constructor() called for PID: \(getpid())")

    // Get process name for debugging
    let processName = ProcessInfo.processInfo.processName
    NSLog("[TintedMac] Injecting into process: %@", processName)
    logger.info("Injecting into process: \(processName)")

    // Safety check before injection
    guard isSafeToInject() else {
        NSLog("[TintedMac] Injection skipped for safety reasons")
        return
    }

    // Initialize injection
    TintedMacInject.initializeInjection()
}
