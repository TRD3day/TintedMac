//
//  TintedMacProtocol.swift
//  TintedMac
//
//  Created by TintedMac on 2024.
//

import Foundation

/// Protocol for NSXPCConnection communication between TintedMacHelper and injected dylib
@objc public protocol TintedMacHelperProtocol {
    /// Get current configuration from helper
    /// - Parameter completion: Callback with configuration data as a string
    func getCurrentConfiguration(withReply completion: @escaping (String?) -> Void)

    /// Check if the connection is alive
    /// - Parameter completion: Callback with connection status
    func ping(withReply completion: @escaping (Bool) -> Void)
}

/// Protocol for dylib to communicate back to helper
@objc public protocol TintedMacDylibProtocol {
    /// Receive configuration from helper
    /// - Parameter configData: The configuration data as a string
    func receiveConfiguration(_ configData: String)

    /// Acknowledge that configuration was received
    /// - Parameter success: Whether the configuration was successfully applied
    func acknowledgeConfiguration(_ success: Bool)
}

/// Shared constants for NSXPCConnection
public struct TintedMacConnection {
    public static let serviceName = "com.aspauldingcode.TintedMac.helper"
    public static let dylibServiceName = "com.aspauldingcode.TintedMac.dylib"
    public static let connectionTimeout: TimeInterval = 5.0
    public static let machServiceName = "com.aspauldingcode.TintedMac.helper.xpc"
}