//
//  ConnectionState.swift
//  SentinelBot
//
//  Represents the lifecycle of the MQTT connection.
//  Used by the UI to show connection status, banners, and reconnect buttons.
//

import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isTransitioning: Bool {
        switch self {
        case .connecting, .reconnecting: return true
        default: return false
        }
    }

    var displayText: String {
        switch self {
        case .disconnected:            return "Disconnected"
        case .connecting:              return "Connecting…"
        case .connected:               return "Connected"
        case .reconnecting(let n):     return "Reconnecting (attempt \(n))…"
        case .error(let msg):          return "Error: \(msg)"
        }
    }
}
