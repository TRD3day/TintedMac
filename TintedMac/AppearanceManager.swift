//
//  AppearanceManager.swift
//  TintedMac
//
//  NSAppearance-based system tinting for macOS theming
//

import Cocoa
import SwiftUI

class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()


    @Published var currentSystemTint: NSColor?

    private var originalAppearance: NSAppearance?
    private var customAppearance: NSAppearance?
    private var tintedWindows: Set<NSWindow> = []

    private init() {
        setupNotifications()
    }

    // MARK: - Public Methods



    /// Apply tinting to a specific window
    func applyToWindow(_ window: NSWindow, theme: ThemeConfig) {
        guard let backgroundColor = NSColor(hex: theme.colors.base00),
              let _ = NSColor(hex: theme.colors.base05) else {
            return
        }

        // Store original appearance if not already stored
        if originalAppearance == nil {
            originalAppearance = window.appearance
        }

        // Apply custom appearance
        if let customAppearance = customAppearance {
            window.appearance = customAppearance
        }

        // Apply background color
        window.backgroundColor = backgroundColor

        // Apply to window content
        if let contentView = window.contentView {
            applyToView(contentView, theme: theme)
        }

        // Track this window
        tintedWindows.insert(window)
    }

    /// Remove tinting from a specific window
    func removeFromWindow(_ window: NSWindow) {
        // Restore original appearance
        if let originalAppearance = originalAppearance {
            window.appearance = originalAppearance
        } else {
            window.appearance = nil
        }

        // Reset background color
        window.backgroundColor = .windowBackgroundColor

        // Remove from tracked windows
        tintedWindows.remove(window)
    }

    // MARK: - Private Methods

    private func setupNotifications() {
        // Listen for system appearance changes using DistributedNotificationCenter
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // Listen for window changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
    }

    private func createCustomAppearance(theme: ThemeConfig) {
        // Create a custom appearance based on whether the theme is dark or light
        // We determine this by checking the background color brightness
        let baseAppearance: NSAppearance

        if let bgColor = NSColor(hex: theme.colors.base00) {
            let brightness = bgColor.brightnessComponent
            if brightness < 0.5 {
                baseAppearance = NSAppearance(named: .darkAqua) ?? NSAppearance(named: .aqua)!
            } else {
                baseAppearance = NSAppearance(named: .aqua) ?? NSAppearance(named: .darkAqua)!
            }
        } else {
            baseAppearance = NSAppearance(named: .aqua)!
        }

        customAppearance = baseAppearance
    }

    private func applyToSystem() {
        // Store original if not already stored
        if originalAppearance == nil {
            originalAppearance = NSApp.appearance
        }

        // Apply custom appearance to the application
        if let customAppearance = customAppearance {
            NSApp.appearance = customAppearance
        }
    }

    private func applyToAllWindows(theme: ThemeConfig) {
        for window in NSApp.windows {
            applyToWindow(window, theme: theme)
        }
    }

    private func removeFromAllWindows() {
        for window in tintedWindows {
            removeFromWindow(window)
        }
        tintedWindows.removeAll()
    }

    private func applyToView(_ view: NSView, theme: ThemeConfig) {
        // Apply theme colors to the view hierarchy
        applyThemeToViewRecursively(view, theme: theme)
    }

    private func applyThemeToViewRecursively(_ view: NSView, theme: ThemeConfig) {
        // Apply theme based on view type
        switch view {
        case let textField as NSTextField:
            applyToTextField(textField, theme: theme)
        case let button as NSButton:
            applyToButton(button, theme: theme)
        case let scrollView as NSScrollView:
            applyToScrollView(scrollView, theme: theme)
        case let tableView as NSTableView:
            applyToTableView(tableView, theme: theme)
        case let outlineView as NSOutlineView:
            applyToOutlineView(outlineView, theme: theme)
        default:
            // Apply general styling
            if let backgroundColor = NSColor(hex: theme.colors.base00) {
                view.wantsLayer = true
                view.layer?.backgroundColor = backgroundColor.cgColor
            }
        }

        // Recursively apply to subviews
        for subview in view.subviews {
            applyThemeToViewRecursively(subview, theme: theme)
        }
    }

    private func applyToTextField(_ textField: NSTextField, theme: ThemeConfig) {
        if let textColor = NSColor(hex: theme.colors.base05) {
            textField.textColor = textColor
        }

        if let backgroundColor = NSColor(hex: theme.colors.base01) {
            textField.backgroundColor = backgroundColor
        }
    }

    private func applyToButton(_ button: NSButton, theme: ThemeConfig) {
        if let accentColor = NSColor(hex: theme.colors.base0D) {
            button.contentTintColor = accentColor
        }
    }

    private func applyToScrollView(_ scrollView: NSScrollView, theme: ThemeConfig) {
        if let backgroundColor = NSColor(hex: theme.colors.base00) {
            scrollView.backgroundColor = backgroundColor
        }
    }

    private func applyToTableView(_ tableView: NSTableView, theme: ThemeConfig) {
        if let backgroundColor = NSColor(hex: theme.colors.base00) {
            tableView.backgroundColor = backgroundColor
        }

        if NSColor(hex: theme.colors.base01) != nil {
            tableView.usesAlternatingRowBackgroundColors = true
            // Note: alternatingRowBackgroundColors is not available in modern macOS
        }
    }

    private func applyToOutlineView(_ outlineView: NSOutlineView, theme: ThemeConfig) {
        applyToTableView(outlineView, theme: theme)
    }

    private func updateControlTints(accentColor: NSColor) {
        // Update system control tint (this affects buttons, sliders, etc.)
        if #available(macOS 11.0, *) {
            // Modern approach for macOS 11+
            NSApp.appearance?.performAsCurrentDrawingAppearance {
                // This will influence the accent color for controls
            }
        }

        // Update specific control appearances
        updateButtonAppearances(accentColor: accentColor)
        updateSliderAppearances(accentColor: accentColor)
    }

    private func updateButtonAppearances(accentColor: NSColor) {
        // This would typically require more complex implementation
        // For now, we'll rely on the appearance changes
    }

    private func updateSliderAppearances(accentColor: NSColor) {
        // This would typically require more complex implementation
        // For now, we'll rely on the appearance changes
    }

    private func restoreOriginalAppearance() {
        if let originalAppearance = originalAppearance {
            NSApp.appearance = originalAppearance
        } else {
            NSApp.appearance = nil
        }
    }

    private func resetControlTints() {
        // Reset to system defaults
        NSApp.appearance = nil
    }

    // MARK: - Notification Handlers

    @objc private func systemAppearanceChanged(_ notification: Notification) {
        // Handle system appearance changes
        DispatchQueue.main.async {
            // Re-create custom appearance based on new system appearance
            // This would need the current theme, which should be passed or stored
        }
    }

    @objc private func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        // Apply tinting to newly focused windows if not already applied
        if !tintedWindows.contains(window) {
            // This would need the current theme
            // applyToWindow(window, theme: currentTheme)
        }
    }
}

// MARK: - NSColor Extensions

extension NSColor {
    convenience init?(hex: String) {
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
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }

    var hexString: String {
        guard let ciColor = CIColor(color: self) else {
            return "#000000"
        }
        let red = Int(ciColor.red * 255)
        let green = Int(ciColor.green * 255)
        let blue = Int(ciColor.blue * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// MARK: - Theme Application Helper

extension AppearanceManager {
    /// Apply theme with automatic appearance detection
    func applyTheme(_ theme: ThemeConfig, force: Bool = false) {
        // Apply theme to individual windows as needed
        print("Theme application requested: \(theme.name)")
    }



    /// Check if a specific window is currently tinted
    func isWindowTinted(_ window: NSWindow) -> Bool {
        return tintedWindows.contains(window)
    }

    /// Get the number of currently tinted windows
    var tintedWindowCount: Int {
        return tintedWindows.count
    }
}
