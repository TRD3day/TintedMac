//
//  ViewController.swift
//  TintedMac
//
//  Main view controller for TintedMac theme configuration
//

import Cocoa
import SwiftUI

struct FilterView: View {
    @Binding var selectedCategory: String
    @Binding var selectedVariant: String
    @Environment(\.dismiss) private var dismiss
    
    let categories = ["All", "Base16"]
    let variants = ["Any", "Light", "Dark", "Unknown"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Filter Themes")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Category")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                
                Text("Variant")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Variant", selection: $selectedVariant) {
                    ForEach(variants, id: \.self) { variant in
                        Text(variant).tag(variant)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Button("Reset") {
                    selectedCategory = "All"
                    selectedVariant = "Any"
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// Sidebar width modifier with version compatibility
struct SidebarWidthModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } else {
            content
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 250)
        }
    }
}

// Visual Effect View for liquid glass styling
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

class ViewController: NSViewController {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    private var hostingController: NSHostingController<ContentView>?
    private let appStyle: AppStyle
    
    init(appStyle: AppStyle = .standard) {
        self.appStyle = appStyle
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.appStyle = .standard
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUIView()
    }
    
    private func setupSwiftUIView() {
        let contentView = ContentView(
            themeManager: themeManager,
            appearanceManager: appearanceManager,
            appStyle: appStyle
        )
        hostingController = NSHostingController(rootView: contentView)
        
        guard let hostingController = hostingController else { return }
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        addChild(hostingController)
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

struct ContentView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var appearanceManager: AppearanceManager
    let appStyle: AppStyle
    @State private var showingSettings = false
    @State private var showingFilters = false
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedVariant = "Any"
    @State private var showingColorPicker = false
    @State private var selectedColorKey = ""
    @State private var selectedColor = Color.blue
    
    var body: some View {
        VStack {
            // Header with settings button
            HStack {
                Image(systemName: "paintpalette.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading) {
                    Text("TintedMac")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("System-wide theme configuration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Search button
                Button(action: {
                    showingSearch.toggle()
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .help("Search")
                
                // Filter button
                Button(action: {
                    showingFilters = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .help("Filters")
                
                // Settings button
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
            .padding()
            
            Divider()
            
            // Search field (conditionally shown)
            if showingSearch {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search themes...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Main content - Theme Browser as the primary view
            ThemeBrowserView(
                themeManager: themeManager,
                searchText: searchText,
                selectedCategory: selectedCategory,
                selectedVariant: selectedVariant
            )
        }
        .frame(minWidth: 600, minHeight: 400)
        .textSelection(.disabled)
        .background(
            Group {
                if appStyle == .liquidGlass {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                } else {
                    Color.clear
                }
            }
        )
        .sheet(isPresented: $showingSettings) {
            SettingsView(themeManager: themeManager)
                .frame(width: 600, height: 500)
        }
        .sheet(isPresented: $showingFilters) {
            FilterView(
                selectedCategory: $selectedCategory,
                selectedVariant: $selectedVariant
            )
            .frame(width: 300, height: 200)
        }
        .sheet(isPresented: $showingColorPicker) {
            VStack(spacing: 20) {
                Text("Edit Color: \(selectedColorKey)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                ColorPicker("Select Color", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(height: 200)
                
                Button("Done") {
                    showingColorPicker = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(width: 400, height: 300)
        }
    }
}