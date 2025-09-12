//
//  ThemeBrowserView.swift
//  TintedMac
//
//  Theme browser interface similar to Whisperer watchOS app
//

import SwiftUI
import TintedThemingSwift
import AppKit



struct ThemeBrowserView: View {
    @ObservedObject var themeManager: ThemeManager
    let searchText: String
    let selectedCategory: String
    let selectedVariant: String
    @State private var gridColumns = 3
    @State private var showingCustomizeSheet = false
    @State private var themeToCustomize: String?
    @State private var themes: [Base16Theme] = []
    @State private var selectedThemeForCustomization: Base16Theme?
    
    private var selectedThemeBinding: Binding<Base16Theme?> {
        Binding(
            get: { selectedThemeForCustomization },
            set: { selectedThemeForCustomization = $0 }
        )
    }
    
    private var categories: [String] {
        return themeManager.categories
    }
    
    private var filteredSchemes: [String] {
        let schemes: [String]
        
        switch selectedCategory {
        case "All":
            schemes = themeManager.availableSchemes + themeManager.availableBase24Schemes
        case "Base16":
            schemes = themeManager.availableSchemes
        case "Base24":
            schemes = themeManager.availableBase24Schemes
        default:
            let categorizedSchemes = themeManager.getSchemesByCategory()
            schemes = categorizedSchemes[selectedCategory] ?? []
        }
        
        var filtered = schemes
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { scheme in
                scheme.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply variant filter
        if selectedVariant != "Any" {
            filtered = filtered.filter { scheme in
                // This is a simplified variant filtering - you may need to enhance based on actual theme data
                let variant = selectedVariant.lowercased()
                return scheme.lowercased().contains(variant) || 
                       (variant == "unknown" && !scheme.lowercased().contains("light") && !scheme.lowercased().contains("dark"))
            }
        }
        
        return filtered
    }
    
    private func revertToDefault() {
        themeManager.revertToDefault()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Grid columns control
            HStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Columns: \(gridColumns)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: Binding(
                        get: { Double(gridColumns) },
                        set: { gridColumns = Int($0.rounded()) }
                    ), in: 2...5, step: 1)
                    .frame(width: 120)
                }
                .frame(width: 140)
            }
            .padding()
            
            Divider()
            
            // Loading indicator
            if themeManager.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading themes...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                }
            } else {
                // Theme grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: gridColumns), spacing: 16) {
                        ForEach(filteredSchemes, id: \.self) { scheme in
                            ThemeCardView(
                                scheme: scheme,
                                themeManager: themeManager,
                                themeToCustomize: $themeToCustomize,
                                showingCustomizeSheet: $showingCustomizeSheet
                            )
                        }
                    }
                    .padding()
                    .id("\(searchText)-\(selectedCategory)-\(gridColumns)") // Force refresh when search/filter changes
                }
            }
            
            // Status bar with actions
            HStack {
                Text("\(filteredSchemes.count) themes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Revert to Default button
                Button("Revert to Default") {
                    revertToDefault()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                if !themeManager.isLoading {
                    Button("Refresh") {
                        themeManager.refreshThemes()
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingCustomizeSheet) {
            if let themeName = themeToCustomize {
                ThemeCustomizeView(theme: selectedThemeBinding)
                    .onAppear {
                        Task {
                            do {
                                let themes = try await TintedThemesLoader.shared.loadAllBase16Themes()
                                await MainActor.run {
                                    selectedThemeForCustomization = themes.first { $0.name == themeName }
                                }
                            } catch {
                                print("Error loading theme for customization: \(error)")
                            }
                        }
                    }
            }
        }
    }
}

struct ThemeCardView: View {
    let scheme: String
    @ObservedObject var themeManager: ThemeManager
    @Binding var themeToCustomize: String?
    @Binding var showingCustomizeSheet: Bool
    @State private var isHovered = false

    @State private var themeData: Base16Theme?
    // Base24 support removed temporarily
    // @State private var base24ThemeData: Base24Theme?
    
    private var isBase24Theme: Bool {
        // Base24 support removed temporarily
        return false
    }
    
    private func loadThemeData() {
         Task {
             do {
                 // Base24 support removed temporarily
                 let themes = try await TintedThemesLoader.shared.loadAllBase16Themes()
                 await MainActor.run {
                     themeData = themes.first { $0.name == scheme }
                 }
             } catch {
                 print("Error loading theme data: \(error)")
             }
         }
     }
     
    private func openPreviewWindow() {
        guard let theme = themeData else { return }
        
        let previewWindow = ThemePreviewWindow(theme: theme)
        let hostingController = NSHostingController(rootView: previewWindow)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Theme Preview - \(theme.name)"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
        
        // Apply actual window theming using TintedMacInject functionality
        applyThemeToPreviewWindow(window, theme: theme)
        
        window.makeKeyAndOrderFront(nil)
    }
    
    private func applyThemeToPreviewWindow(_ window: NSWindow, theme: Base16Theme) {
        // Convert Base16Theme to ThemeConfig format for injection
        let themeConfig = ThemeConfig(
            name: theme.name,
            type: .base16,
            colors: ThemeColors(
                base00: theme.base00, base01: theme.base01, base02: theme.base02, base03: theme.base03,
                base04: theme.base04, base05: theme.base05, base06: theme.base06, base07: theme.base07,
                base08: theme.base08, base09: theme.base09, base0A: theme.base0A, base0B: theme.base0B,
                base0C: theme.base0C, base0D: theme.base0D, base0E: theme.base0E, base0F: theme.base0F
            )
        )
        
        // Apply theme to window after a short delay to ensure window is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                try self.applyPreviewWindowTheme(to: window, theme: themeConfig)
            } catch {
                NSLog("Failed to apply theme to preview window: \(error)")
            }
        }
    }
    
    private func applyPreviewWindowTheme(to window: NSWindow, theme: ThemeConfig) throws {
        // Apply titlebar theming
        try applyTitlebarTheme(to: window, theme: theme)
        
        // Apply traffic lights theming
        try applyTrafficLightsTheme(to: window, theme: theme)
        
        // Set window background
        window.backgroundColor = NSColor(hex: theme.colors.base00) ?? NSColor.windowBackgroundColor
    }
    
    private func applyTitlebarTheme(to window: NSWindow, theme: ThemeConfig) throws {
        guard let titlebarView = findTitlebarView(in: window) else {
            NSLog("Could not find titlebar view for preview window")
            return
        }
        
        // Apply titlebar background color
        let titlebarColor = NSColor(hex: theme.colors.base01) ?? NSColor.windowBackgroundColor
        titlebarView.wantsLayer = true
        titlebarView.layer?.backgroundColor = titlebarColor.cgColor
        
        // Find and colorize title text
        if let titleTextField = findTitleTextField(in: titlebarView) {
            titleTextField.textColor = NSColor(hex: theme.colors.base05) ?? NSColor.labelColor
        }
    }
    
    private func applyTrafficLightsTheme(to window: NSWindow, theme: ThemeConfig) throws {
        guard let titlebarView = findTitlebarView(in: window) else {
            NSLog("Could not find titlebar for traffic lights")
            return
        }
        
        // Find individual traffic light buttons
        let closeButton = findTrafficLightButton(in: titlebarView, type: "Close")
        let minimizeButton = findTrafficLightButton(in: titlebarView, type: "Miniaturize")
        let zoomButton = findTrafficLightButton(in: titlebarView, type: "Zoom")
        
        // Apply custom colors to traffic lights
        if let close = closeButton {
            applyTrafficLightColor(to: close, color: NSColor(hex: theme.colors.base08) ?? NSColor.systemRed)
        }
        
        if let minimize = minimizeButton {
            applyTrafficLightColor(to: minimize, color: NSColor(hex: theme.colors.base0A) ?? NSColor.systemYellow)
        }
        
        if let zoom = zoomButton {
            applyTrafficLightColor(to: zoom, color: NSColor(hex: theme.colors.base0B) ?? NSColor.systemGreen)
        }
    }
    
    private func findTitlebarView(in window: NSWindow) -> NSView? {
        let windowFrame = window.contentView?.superview
        return findViewByClassName(windowFrame, className: "NSTitlebarContainerView")
    }
    
    private func findTitleTextField(in titlebarView: NSView) -> NSTextField? {
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
    
    private func findTrafficLightButton(in view: NSView, type: String) -> NSButton? {
        if let button = view as? NSButton {
            let actionString = button.action?.description ?? ""
            if actionString.contains(type.lowercased()) || actionString.contains(type) {
                return button
            }
        }
        
        for subview in view.subviews {
            if let found = findTrafficLightButton(in: subview, type: type) {
                return found
            }
        }
        
        return nil
    }
    
    private func applyTrafficLightColor(to button: NSButton, color: NSColor) {
        button.wantsLayer = true
        
        let colorLayer = CALayer()
        colorLayer.backgroundColor = color.cgColor
        colorLayer.cornerRadius = 6.0
        colorLayer.frame = CGRect(x: 0, y: 0, width: 12, height: 12)
        
        button.layer?.sublayers?.removeAll()
        button.layer?.addSublayer(colorLayer)
        button.layer?.masksToBounds = false
    }

    private var isCurrentTheme: Bool {
        themeManager.currentConfig.lightTheme.name == scheme ||
        themeManager.currentConfig.darkTheme.name == scheme
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Color preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .frame(height: 120)
                
                // Color palette preview using actual theme colors
                if let theme = themeData {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            ColorDot(color: Color(hex: theme.base00) ?? .black)   // Background
                            ColorDot(color: Color(hex: theme.base01) ?? .gray)    // Lighter BG
                            ColorDot(color: Color(hex: theme.base02) ?? .gray)    // Selection
                            ColorDot(color: Color(hex: theme.base03) ?? .gray)    // Comments
                        }
                        HStack(spacing: 2) {
                            ColorDot(color: Color(hex: theme.base04) ?? .gray)    // Dark FG
                            ColorDot(color: Color(hex: theme.base05) ?? .white)   // Foreground
                            ColorDot(color: Color(hex: theme.base06) ?? .white)   // Light FG
                            ColorDot(color: Color(hex: theme.base07) ?? .white)   // Light BG
                        }
                        HStack(spacing: 2) {
                            ColorDot(color: Color(hex: theme.base08) ?? .red)     // Red
                            ColorDot(color: Color(hex: theme.base09) ?? .orange)  // Orange
                            ColorDot(color: Color(hex: theme.base0A) ?? .yellow)  // Yellow
                            ColorDot(color: Color(hex: theme.base0B) ?? .green)   // Green
                        }
                        HStack(spacing: 2) {
                            ColorDot(color: Color(hex: theme.base0C) ?? .cyan)    // Cyan
                            ColorDot(color: Color(hex: theme.base0D) ?? .blue)    // Blue
                            ColorDot(color: Color(hex: theme.base0E) ?? .purple)  // Purple
                            ColorDot(color: Color(hex: theme.base0F) ?? .brown)   // Brown
                        }
                    }
                // Base24 support removed temporarily
                } else {
                    // Fallback colors when theme data is not available
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            ColorDot(color: .black)
                            ColorDot(color: .gray)
                            ColorDot(color: .gray)
                            ColorDot(color: .gray)
                        }
                        HStack(spacing: 2) {
                            ColorDot(color: .gray)
                            ColorDot(color: .white)
                            ColorDot(color: .white)
                            ColorDot(color: .white)
                        }
                        HStack(spacing: 2) {
                            ColorDot(color: .red)
                            ColorDot(color: .orange)
                            ColorDot(color: .yellow)
                            ColorDot(color: .green)
                        }
                        HStack(spacing: 2) {
                            ColorDot(color: .cyan)
                            ColorDot(color: .blue)
                            ColorDot(color: .purple)
                            ColorDot(color: .brown)
                        }
                    }
                }
                
                // Selection indicator
                if isCurrentTheme {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Hover overlay
                if isHovered {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            VStack(spacing: 8) {
                                Button("Apply Theme") {
                                    Task {
                                        let variant = await themeManager.getThemeVariant(for: scheme)
                                        await MainActor.run {
                                            themeManager.applyScheme(scheme, for: variant)
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .font(.caption)
                                
                                HStack(spacing: 8) {
                                    Button("Customize") {
                                        themeToCustomize = scheme
                                        showingCustomizeSheet = true
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Preview") {
                                        openPreviewWindow()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        )
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            
            // Theme info
            VStack(alignment: .leading, spacing: 2) {
                Text(scheme)
                    .font(.headline)
                    .lineLimit(1)
                    .textSelection(.disabled)
                
                Text("by \(themeData?.author ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .textSelection(.disabled)
                
                HStack {
                    Text("BASE16")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                        .textSelection(.disabled)
                    
                    if let variant = themeData?.variant, !variant.isEmpty {
                        Text(variant.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                            .textSelection(.disabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .onAppear {
            loadThemeData()
        }
        .onChange(of: scheme) { _ in
            // Reset theme data when scheme changes (e.g., due to search filtering)
            themeData = nil
            // Base24 support removed temporarily
            loadThemeData()
        }
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)


    }
}

struct ColorDot: View {
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

// ThemePreviewView removed temporarily during Base24 removal
/*
struct ThemePreviewView: View {
    let scheme: String
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode
    @State private var themeColors: ThemeColors?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(scheme)
                    .font(.title)
                    .fontWeight(.bold)
                Text("by Unknown")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            
            // Color palette
            VStack(spacing: 16) {
                Text("Color Palette")
                    .font(.headline)
                
                if let colors = themeColors {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ColorPreviewItem(name: "base00", color: colors.base00, description: "Background")
                        ColorPreviewItem(name: "base01", color: colors.base01, description: "Lighter BG")
                        ColorPreviewItem(name: "base02", color: colors.base02, description: "Selection")
                        ColorPreviewItem(name: "base03", color: colors.base03, description: "Comments")
                        ColorPreviewItem(name: "base04", color: colors.base04, description: "Dark FG")
                        ColorPreviewItem(name: "base05", color: colors.base05, description: "Foreground")
                        ColorPreviewItem(name: "base06", color: colors.base06, description: "Light FG")
                        ColorPreviewItem(name: "base07", color: colors.base07, description: "Light BG")
                        ColorPreviewItem(name: "base08", color: colors.base08, description: "Red")
                        ColorPreviewItem(name: "base09", color: colors.base09, description: "Orange")
                        ColorPreviewItem(name: "base0A", color: colors.base0A, description: "Yellow")
                        ColorPreviewItem(name: "base0B", color: colors.base0B, description: "Green")
                        ColorPreviewItem(name: "base0C", color: colors.base0C, description: "Cyan")
                        ColorPreviewItem(name: "base0D", color: colors.base0D, description: "Blue")
                        ColorPreviewItem(name: "base0E", color: colors.base0E, description: "Purple")
                        ColorPreviewItem(name: "base0F", color: colors.base0F, description: "Brown")
                    }
                } else {
                    ProgressView("Loading theme colors...")
                        .frame(height: 200)
                }
            }
            .padding()
            
            // Action buttons
            Button("Apply Theme") {
                Task {
                    let variant = await themeManager.getThemeVariant(for: scheme)
                    await MainActor.run {
                        themeManager.applyScheme(scheme, for: variant)
                        
                        // Save configuration - let dylib handle theme application
                        themeManager.saveConfiguration()
                        
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Spacer()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadThemeColors()
        }
    }
    
    private func loadThemeColors() {
        Task {
            // Load theme colors based on scheme name
            do {
                let themes = try await TintedThemesLoader.shared.loadAllBase16Themes()
                if let base16Theme = themes.first(where: { $0.name == scheme }) {
                    await MainActor.run {
                        themeColors = themeManager.createThemeColors(from: base16Theme)
                    }
                }
            } catch {
                print("Error loading Base16 theme: \(error)")
            }
        }
    }
*/


// ThemePreviewWindow removed temporarily during Base24 removal
/*
struct ThemePreviewWindow: View {
    let theme: Base16Theme
    
    var body: some View {
        ThemePreviewView(scheme: theme.name, themeManager: ThemeManager.shared)
    }
}
*/

struct ColorPreviewItem: View {
    let name: String
    let color: String
    let description: String
    
    private var colorValue: Color {
        let cleanColor = color.hasPrefix("#") ? String(color.dropFirst()) : color
        if let colorInt = Int(cleanColor, radix: 16) {
            let red = Double((colorInt >> 16) & 0xFF) / 255.0
            let green = Double((colorInt >> 8) & 0xFF) / 255.0
            let blue = Double(colorInt & 0xFF) / 255.0
            return Color(red: red, green: green, blue: blue)
        }
        return Color.gray
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(colorValue)
                .frame(height: 40)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
            
            Text(name)
                .font(.caption2)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}