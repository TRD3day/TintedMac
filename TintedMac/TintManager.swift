//
//  TintManager.swift
//  TintedMac
//
//  Created on 2024.
//  Copyright © 2024 TintedMac. All rights reserved.
//

import Cocoa
import QuartzCore
import WindowAdditions

class TintManager {
    static let shared = TintManager()
    
    private var currentTintColor: NSColor = NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.1)
    private var isEnabled: Bool = false
    
    private init() {}
    
    func setTintColor(_ color: NSColor) {
        currentTintColor = color
        if isEnabled {
            updateAllWindowTints()
        }
    }
    
    func enableTinting() {
        isEnabled = true
        applyTintToAllWindows()
    }
    
    func disableTinting() {
        isEnabled = false
        removeTintFromAllWindows()
    }
    
    func toggleTinting() {
        if isEnabled {
            disableTinting()
        } else {
            enableTinting()
        }
    }
    
    private func applyTintToAllWindows() {
        for window in NSApplication.shared.windows {
            if window.isVisible {
                window.applyTintEffect()
                window.updateTintColor(currentTintColor)
            }
        }
    }
    
    private func removeTintFromAllWindows() {
        for window in NSApplication.shared.windows {
            window.removeTintEffect()
        }
    }
    
    private func updateAllWindowTints() {
        for window in NSApplication.shared.windows {
            if window.isVisible {
                window.updateTintColor(currentTintColor)
            }
        }
    }
    
    func handleNewWindow(_ window: NSWindow) {
        if isEnabled && window.isVisible {
            window.applyTintEffect()
            window.updateTintColor(currentTintColor)
        }
    }
}