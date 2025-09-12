//
//  AppDelegate.swift
//  TintedMac
//
//  Created on 2024.
//  Copyright © 2024 TintedMac. All rights reserved.
//

import Cocoa

enum AppStyle {
    case standard
    case liquidGlass
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var appStyle: AppStyle = .standard
    private var cliProcess: Process?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Check for liquid glass style
        if ProcessInfo.processInfo.environment["TINTED_MAC_STYLE"] == "liquid-glass" {
            appStyle = .liquidGlass
        }
        
        // Set the activation policy to regular app
        NSApp.setActivationPolicy(.regular)
        
        // Create the main window with appropriate styling
        let styleMask: NSWindow.StyleMask = appStyle == .liquidGlass ? 
            [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView] :
            [.titled, .closable, .miniaturizable, .resizable]
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        window.title = "TintedMac"
        window.center()
        
        // Apply liquid glass effects if enabled
        if appStyle == .liquidGlass {
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor.clear
            if #available(macOS 10.14, *) {
                window.appearance = NSAppearance(named: .vibrantDark)
            }
        }
        
        // Create and set the view controller
        let viewController = ViewController(appStyle: appStyle)
        window.contentViewController = viewController
        
        // Set window delegate to handle closing events
        window.delegate = self
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        
        // Activate the application to bring it to the front
        NSApp.activate(ignoringOtherApps: true)
        
        print("TintedMac application started")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Terminate any running CLI processes
        terminateCLIProcess()
    }
    
    // MARK: - NSWindowDelegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Terminate CLI process when window is closed
        terminateCLIProcess()
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        // Ensure CLI process is terminated
        terminateCLIProcess()
        // Terminate the application when window closes
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - CLI Process Management
    
    private func terminateCLIProcess() {
        // Find and terminate any running 'make run' or TintedMac CLI processes
        let task = Process()
        task.launchPath = "/usr/bin/pkill"
        task.arguments = ["-f", "swift run TintedMac"]
        
        do {
            try task.run()
            task.waitUntilExit()
            print("Terminated CLI processes")
        } catch {
            print("Failed to terminate CLI processes: \(error)")
        }
        
        // Also try to kill any processes with TintedMac in the name
        let task2 = Process()
        task2.launchPath = "/usr/bin/pkill"
        task2.arguments = ["-f", "TintedMac"]
        
        do {
            try task2.run()
            task2.waitUntilExit()
        } catch {
            // Ignore errors for this cleanup attempt
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}