import SwiftUI
import TintedThemingSwift
import AppKit
import QuartzCore
import ObjectiveC

// Window delegate to handle titlebar theming persistence
class PreviewWindowDelegate: NSObject, NSWindowDelegate {
    let theme: Base16Theme

    init(theme: Base16Theme) {
        self.theme = theme
        super.init()
    }





    private func applyThemeToWindow(_ window: NSWindow) {
        // Convert Base16Theme to ThemeConfig format
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

        do {
            try applyPreviewWindowTheme(to: window, theme: themeConfig)
        } catch {
            NSLog("Failed to apply theme to preview window: \(error)")
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
            throw NSError(domain: "ThemeError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find titlebar view"])
        }

        // Apply background color to titlebar
        titlebarView.wantsLayer = true
        titlebarView.layer?.backgroundColor = (NSColor(hex: theme.colors.base01) ?? NSColor.windowBackgroundColor).cgColor

        // Find and theme the title text
        if let titleTextField = findTitleTextField(in: titlebarView) {
            titleTextField.textColor = NSColor(hex: theme.colors.base05) ?? NSColor.labelColor
        }
    }

    private func applyTrafficLightsTheme(to window: NSWindow, theme: ThemeConfig) throws {
        // Prevent fullscreen
        window.collectionBehavior = [.managed, .fullScreenNone]

        guard let titlebarView = findTitlebarView(in: window) else {
            throw NSError(domain: "ThemeError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find titlebar view for traffic lights"])
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
            // Completely disable and hide zoom button
            zoom.isHidden = true
            zoom.isEnabled = false
            zoom.target = nil
            zoom.action = nil
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
        // Remove any existing tint overlays
        button.subviews.filter { $0.identifier?.rawValue == "trafficLightTint" }.forEach { $0.removeFromSuperview() }
        
        // Create a tint overlay that applies the color to the actual button
        let tintOverlay = NSView(frame: button.bounds)
        tintOverlay.identifier = NSUserInterfaceItemIdentifier("trafficLightTint")
        tintOverlay.wantsLayer = true
        tintOverlay.layer?.backgroundColor = color.cgColor
        tintOverlay.layer?.cornerRadius = button.bounds.width / 2
        tintOverlay.layer?.opacity = 0.7
        tintOverlay.layer?.compositingFilter = "multiplyBlendMode"
        
        button.addSubview(tintOverlay)
        tintOverlay.layer?.zPosition = 1
    }
}

struct ThemePreviewWindow: View {
    let theme: Base16Theme
    @Environment(\.dismiss) private var dismiss
    @State private var previewWindow: NSWindow?

    var body: some View {
        VStack(spacing: 0) {
            // Real window content (titlebar will be handled by NSWindow)
            Button("Open Themed Preview Window") {
                openThemedPreviewWindow()
            }
            .buttonStyle(.borderedProminent)
            .padding()



            // Main content area
            VStack(spacing: 20) {
                // Static menu bar (removed - not part of window content)
                // Menu items belong in global menu bar, not window content

                // Static toolbar with native macOS styling
                HStack {
                    Button("New") { }
                        .buttonStyle(.bordered)

                    Button("Open") { }
                        .buttonStyle(.bordered)

                    Button("Save") { }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: theme.base0D))

                    Spacer()

                    Button("Settings") { }
                        .buttonStyle(.bordered)
                }
                .font(.system(size: 13))
                .padding(.horizontal)

                // Simulated sidebar and content
                HStack(spacing: 0) {
                    // Static Sidebar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SIDEBAR")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: theme.base03) ?? .secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            SidebarItem(title: "Documents", icon: "folder", theme: theme, isSelected: true)
                            SidebarItem(title: "Downloads", icon: "arrow.down.circle", theme: theme, isSelected: false)
                            SidebarItem(title: "Desktop", icon: "desktopcomputer", theme: theme, isSelected: false)
                            SidebarItem(title: "Applications", icon: "app.badge", theme: theme, isSelected: false)
                        }

                        Spacer()
                    }
                    .padding()
                    .frame(width: 180)
                    .background(Color(hex: theme.base01) ?? Color(NSColor.controlBackgroundColor))

                    // Main content
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Theme Preview: \(theme.name)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: theme.base05) ?? .primary)
                            Spacer()
                        }

                        Text("This window demonstrates how your macOS interface would look with this theme applied. The colors shown here represent:")
                            .foregroundColor(Color(hex: theme.base04) ?? .secondary)

                        // Static text field example with native styling
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Text Field Example:")
                                .font(.headline)

                            TextField("Sample text content", text: .constant("Sample text content"))
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ColorDescriptionRow(color: Color(hex: theme.base00) ?? .black, label: "Background", description: "Window backgrounds")
                            ColorDescriptionRow(color: Color(hex: theme.base01) ?? .gray, label: "Secondary Background", description: "Sidebar, toolbar backgrounds")
                            ColorDescriptionRow(color: Color(hex: theme.base05) ?? .white, label: "Text", description: "Primary text color")
                            ColorDescriptionRow(color: Color(hex: theme.base0D) ?? .blue, label: "Accent", description: "Buttons, links, selections")
                            ColorDescriptionRow(color: Color(hex: theme.base08) ?? .red, label: "Close Button", description: "Window controls")
                        }

                        Spacer()

                        // Sample text editor with proper syntax highlighting
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sample Code Editor")
                                .font(.headline)
                                .foregroundColor(Color(hex: theme.base05) ?? .primary)

                            VStack(alignment: .leading, spacing: 2) {
                                SyntaxHighlightedCodeLine(code: "// This is a comment", theme: theme)
                                SyntaxHighlightedCodeLine(code: "function example() {", theme: theme)
                                SyntaxHighlightedCodeLine(code: "  const message = \"Hello World\";", theme: theme)
                                SyntaxHighlightedCodeLine(code: "  if (message.length > 0) {", theme: theme)
                                SyntaxHighlightedCodeLine(code: "    console.log(message);", theme: theme)
                                SyntaxHighlightedCodeLine(code: "    return true;", theme: theme)
                                SyntaxHighlightedCodeLine(code: "  }", theme: theme)
                                SyntaxHighlightedCodeLine(code: "}", theme: theme)
                            }
                            .padding()
                            .background(Color(hex: theme.base00) ?? .black)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(hex: theme.base00) ?? Color(NSColor.textBackgroundColor))
                }
            }
            .background(Color(hex: theme.base00) ?? Color(NSColor.textBackgroundColor))
        }
        .frame(width: 800, height: 600)
        .onDisappear {
            previewWindow?.close()
        }
    }

    private func openThemedPreviewWindow() {
        // Close existing window if any
        previewWindow?.close()

        // Create the content view
        let contentView = ThemedPreviewContentView(theme: theme)
        let hostingController = NSHostingController(rootView: contentView)

        // Create the window without fullscreen capability
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "\(theme.name) - Preview"
        window.contentViewController = hostingController

        // Disable fullscreen capability completely
        window.collectionBehavior = [.managed, .fullScreenNone]
        
        // Enable transparent titlebar for better theming
        window.titlebarAppearsTransparent = true

        // Set up window delegate for titlebar theming persistence
        let delegate = PreviewWindowDelegate(theme: theme)
        window.delegate = delegate

        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store reference
        previewWindow = window

        // Apply theme to window after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.applyThemeToPreviewWindow(window, theme: theme)
        }
    }

    func applyThemeToPreviewWindow(_ window: NSWindow, theme: Base16Theme) {
        // Convert Base16Theme to ThemeConfig format
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

        do {
            try applyPreviewWindowTheme(to: window, theme: themeConfig)
        } catch {
            NSLog("Failed to apply theme to preview window: \(error)")
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
        guard let titlebarContainer = findTitlebarView(in: window) else {
            NSLog("Could not find titlebar view for preview window")
            return
        }

        // Find the actual titlebar view (not container)
        let titlebarView = titlebarContainer.subviews.first { subview in
            NSStringFromClass(type(of: subview)).contains("NSTitlebarView")
        } ?? titlebarContainer

        // Apply titlebar background color
        let titlebarColor = NSColor(hex: theme.colors.base01) ?? NSColor.windowBackgroundColor
        titlebarView.wantsLayer = true
        titlebarView.layer?.backgroundColor = titlebarColor.cgColor

        // Find and colorize title text field
         let titleTextField = findTitleTextField(in: titlebarContainer) ?? 
                            findTitleTextField(in: titlebarView)
         
         if let titleField = titleTextField {
             titleField.textColor = NSColor(hex: theme.colors.base05) ?? NSColor.labelColor
             titleField.backgroundColor = .clear
         }
        
        // Ensure titlebar transparency is enabled for better theming
        window.titlebarAppearsTransparent = false
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
            // Disable zoom functionality but keep the button visible
            zoom.target = nil
            zoom.action = nil
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
        // Directly tint the traffic light button without creating overlays
        button.wantsLayer = true
        
        // Apply color tint to the button's content
        if #available(macOS 11.0, *) {
            button.contentTintColor = color
        } else {
            // Fallback for older macOS versions
            button.appearance = NSAppearance(named: .aqua)
            button.layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
            button.layer?.cornerRadius = button.bounds.width / 2
        }
    }
}

// Separate view for the themed window content
struct ThemedPreviewContentView: View {
    let theme: Base16Theme

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 8) {
                Text("Sidebar")
                    .font(.headline)
                    .foregroundColor(Color(NSColor(hex: theme.base05) ?? NSColor.labelColor))
                    .padding(.bottom, 4)

                SidebarItem(title: "Documents", theme: theme)
                SidebarItem(title: "Downloads", theme: theme)
                SidebarItem(title: "Desktop", theme: theme)
                SidebarItem(title: "Applications", theme: theme)

                Spacer()
            }
            .padding()
            .frame(width: 200)
            .background(Color(NSColor(hex: theme.base01) ?? NSColor.controlBackgroundColor))

            // Main content area
            VStack(alignment: .leading, spacing: 16) {
                // macOS UI Elements Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("TintedMac UI Elements")
                        .font(.headline)
                        .foregroundColor(Color(NSColor(hex: theme.base05) ?? NSColor.labelColor))

                    // Toggle switches
                    HStack {
                        Text("Dark Mode:")
                            .foregroundColor(Color(NSColor(hex: theme.base05) ?? NSColor.labelColor))
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .toggleStyle(SwitchToggleStyle(tint: Color(NSColor(hex: theme.base0D) ?? NSColor.systemBlue)))
                    }

                    HStack {
                        Text("Notifications:")
                            .foregroundColor(Color(NSColor(hex: theme.base05) ?? NSColor.labelColor))
                        Spacer()
                        Toggle("", isOn: .constant(false))
                            .toggleStyle(SwitchToggleStyle(tint: Color(NSColor(hex: theme.base0D) ?? NSColor.systemBlue)))
                    }

                    // Sliders
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volume: 75%")
                            .font(.caption)
                            .foregroundColor(Color(NSColor(hex: theme.base04) ?? NSColor.secondaryLabelColor))
                        Slider(value: .constant(0.75))
                            .accentColor(Color(NSColor(hex: theme.base0D) ?? NSColor.systemBlue))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Brightness: 50%")
                            .font(.caption)
                            .foregroundColor(Color(NSColor(hex: theme.base04) ?? NSColor.secondaryLabelColor))
                        Slider(value: .constant(0.5))
                            .accentColor(Color(NSColor(hex: theme.base0A) ?? NSColor.systemYellow))
                    }

                    // Buttons
                    HStack(spacing: 8) {
                        Button("Primary") {}
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)

                        Button("Secondary") {}
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                        Button("Destructive") {}
                            .buttonStyle(.bordered)
                            .foregroundColor(Color(NSColor(hex: theme.base08) ?? NSColor.systemRed))
                            .controlSize(.regular)
                    }

                    // Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Loading Progress")
                            .font(.caption)
                            .foregroundColor(Color(NSColor(hex: theme.base04) ?? NSColor.secondaryLabelColor))
                        ProgressView(value: 0.6)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color(NSColor(hex: theme.base0B) ?? NSColor.systemGreen)))
                    }
                }

                // Color descriptions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme Colors:")
                        .font(.headline)
                        .foregroundColor(Color(NSColor(hex: theme.base05) ?? NSColor.labelColor))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base00) ?? NSColor.textBackgroundColor), label: "Background", description: theme.base00)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base01) ?? NSColor.controlBackgroundColor), label: "Lighter BG", description: theme.base01)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base02) ?? NSColor.separatorColor), label: "Selection", description: theme.base02)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base03) ?? NSColor.tertiaryLabelColor), label: "Comments", description: theme.base03)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base04) ?? NSColor.secondaryLabelColor), label: "Dark FG", description: theme.base04)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base05) ?? NSColor.labelColor), label: "Default FG", description: theme.base05)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base06) ?? NSColor.labelColor), label: "Light FG", description: theme.base06)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base07) ?? NSColor.labelColor), label: "Lightest FG", description: theme.base07)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base08) ?? NSColor.systemRed), label: "Red", description: theme.base08)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base09) ?? NSColor.systemOrange), label: "Orange", description: theme.base09)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base0A) ?? NSColor.systemYellow), label: "Yellow", description: theme.base0A)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base0B) ?? NSColor.systemGreen), label: "Green", description: theme.base0B)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base0C) ?? NSColor.systemTeal), label: "Cyan", description: theme.base0C)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base0D) ?? NSColor.systemBlue), label: "Blue", description: theme.base0D)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base0E) ?? NSColor.systemPurple), label: "Purple", description: theme.base0E)
                        ColorDescriptionRow(color: Color(NSColor(hex: theme.base0F) ?? NSColor.systemBrown), label: "Brown", description: theme.base0F)
                    }
                }

                // Sample code editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Code Preview:")
                        .font(.headline)
                        .foregroundColor(Color(NSColor(hex: theme.base05) ?? NSColor.labelColor))

                    VStack(alignment: .leading, spacing: 2) {
                        SyntaxHighlightedCodeLine(code: "func greetUser(name: String) {", theme: theme)
                        SyntaxHighlightedCodeLine(code: "    print(\"Hello, \\(name)!\")", theme: theme)
                        SyntaxHighlightedCodeLine(code: "    // This is a comment", theme: theme)
                        SyntaxHighlightedCodeLine(code: "    let message = \"Welcome to \\(theme.name)\"", theme: theme)
                        SyntaxHighlightedCodeLine(code: "    return message", theme: theme)
                        SyntaxHighlightedCodeLine(code: "}", theme: theme)
                    }
                    .padding(12)
                    .background(Color(NSColor(hex: theme.base00) ?? NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor(hex: theme.base02) ?? NSColor.separatorColor), lineWidth: 1)
                    )
                }

                Spacer()
            }
            .padding()
            .background(Color(NSColor(hex: theme.base00) ?? NSColor.textBackgroundColor))
        }
        .background(Color(NSColor(hex: theme.base00) ?? NSColor.textBackgroundColor))
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let theme: Base16Theme
    let isSelected: Bool

    init(title: String, icon: String = "folder", theme: Base16Theme, isSelected: Bool = false) {
        self.title = title
        self.icon = icon
        self.theme = theme
        self.isSelected = isSelected
    }

    init(title: String, theme: Base16Theme) {
        self.title = title
        self.icon = "folder"
        self.theme = theme
        self.isSelected = false
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isSelected ? Color(hex: theme.base0D) ?? .blue : Color(hex: theme.base04) ?? .secondary)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? Color(hex: theme.base07) ?? .primary : Color(hex: theme.base04) ?? .secondary)
                .fontWeight(isSelected ? .medium : .regular)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color(hex: theme.base02) ?? Color.blue.opacity(0.2) : Color.clear)
        .cornerRadius(6)
    }
}

struct ColorDescriptionRow: View {
    let color: Color
    let label: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct SyntaxHighlightedCodeLine: View {
    let code: String
    let theme: Base16Theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tokenizeCode(code).enumerated()), id: \.offset) { _, token in
                Text(token.text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(colorForToken(token))
            }
            Spacer()
        }
    }

    private func colorForToken(_ token: CodeToken) -> Color {
        switch token.type {
        case .comment:
            return Color(NSColor(hex: theme.base03) ?? NSColor.tertiaryLabelColor)
        case .keyword:
            return Color(NSColor(hex: theme.base0E) ?? NSColor.systemPurple)
        case .string:
            return Color(NSColor(hex: theme.base0B) ?? NSColor.systemGreen)
        case .number:
            return Color(NSColor(hex: theme.base09) ?? NSColor.systemOrange)
        case .function:
            return Color(NSColor(hex: theme.base0D) ?? NSColor.systemBlue)
        case .operator:
            return Color(NSColor(hex: theme.base08) ?? NSColor.systemRed)
        case .property:
            return Color(NSColor(hex: theme.base0A) ?? NSColor.systemYellow)
        case .bracket:
            return Color(NSColor(hex: theme.base0C) ?? NSColor.systemTeal)
        case .normal:
            return Color(NSColor(hex: theme.base05) ?? NSColor.labelColor)
        }
    }

    private func tokenizeCode(_ code: String) -> [CodeToken] {
        var tokens: [CodeToken] = []
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)

        // Handle comments
        if trimmedCode.hasPrefix("//") {
            return [CodeToken(text: code, type: .comment)]
        }

        // Simple tokenization for JavaScript-like syntax
        let keywords = ["function", "const", "let", "var", "if", "else", "for", "while", "return", "true", "false", "null", "undefined"]
        let operators = ["=", "+", "-", "*", "/", ">", "<", "!", "&", "|", "?", ":"]
        let brackets = ["{", "}", "(", ")", "[", "]"]

        var currentIndex = code.startIndex
        var currentToken = ""

        while currentIndex < code.endIndex {
            let char = code[currentIndex]

            if char.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(createToken(currentToken, keywords: keywords))
                    currentToken = ""
                }
                tokens.append(CodeToken(text: String(char), type: .normal))
            } else if char == "\"" {
                // Handle string literals
                if !currentToken.isEmpty {
                    tokens.append(createToken(currentToken, keywords: keywords))
                    currentToken = ""
                }

                var stringLiteral = String(char)
                currentIndex = code.index(after: currentIndex)

                while currentIndex < code.endIndex {
                    let stringChar = code[currentIndex]
                    stringLiteral += String(stringChar)
                    if stringChar == "\"" {
                        break
                    }
                    currentIndex = code.index(after: currentIndex)
                }

                tokens.append(CodeToken(text: stringLiteral, type: .string))
            } else if operators.contains(String(char)) {
                if !currentToken.isEmpty {
                    tokens.append(createToken(currentToken, keywords: keywords))
                    currentToken = ""
                }
                tokens.append(CodeToken(text: String(char), type: .operator))
            } else if brackets.contains(String(char)) {
                if !currentToken.isEmpty {
                    tokens.append(createToken(currentToken, keywords: keywords))
                    currentToken = ""
                }
                tokens.append(CodeToken(text: String(char), type: .bracket))
            } else if char == "." {
                if !currentToken.isEmpty {
                    tokens.append(createToken(currentToken, keywords: keywords))
                    currentToken = ""
                }
                tokens.append(CodeToken(text: String(char), type: .operator))
            } else if char == ";" {
                if !currentToken.isEmpty {
                    tokens.append(createToken(currentToken, keywords: keywords))
                    currentToken = ""
                }
                tokens.append(CodeToken(text: String(char), type: .normal))
            } else {
                currentToken += String(char)
            }

            currentIndex = code.index(after: currentIndex)
        }

        if !currentToken.isEmpty {
            tokens.append(createToken(currentToken, keywords: keywords))
        }

        return tokens
    }

    private func createToken(_ text: String, keywords: [String]) -> CodeToken {
        if keywords.contains(text) {
            return CodeToken(text: text, type: .keyword)
        } else if text.allSatisfy({ $0.isNumber }) {
            return CodeToken(text: text, type: .number)
        } else if text.contains("(") || (text.hasSuffix("()") && !text.contains(" ")) {
            return CodeToken(text: text, type: .function)
        } else if text == "console" || text == "log" || text == "length" {
            return CodeToken(text: text, type: .property)
        } else {
            return CodeToken(text: text, type: .normal)
        }
    }
}

struct CodeToken {
    let text: String
    let type: TokenType
}

enum TokenType {
    case comment
    case keyword
    case string
    case number
    case function
    case `operator`
    case property
    case bracket
    case normal
}

#Preview {
    ThemePreviewWindow(theme: Base16Theme(
        name: "Sample Theme",
        author: "Preview",
        variant: "dark",
        base00: "2d3748", base01: "4a5568", base02: "718096", base03: "a0aec0",
        base04: "cbd5e0", base05: "e2e8f0", base06: "edf2f7", base07: "f7fafc",
        base08: "f56565", base09: "ed8936", base0A: "ecc94b", base0B: "48bb78",
        base0C: "38b2ac", base0D: "4299e1", base0E: "9f7aea", base0F: "a0522d"
    ))
}
