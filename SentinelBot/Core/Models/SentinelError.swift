//
//  SentinelError.swift
//  SentinelBot
//
//  Single source of truth for app-level errors.
//  Conforms to LocalizedError so SwiftUI alerts can show user-friendly messages
//  via .errorDescription.
//

import Foundation

enum SentinelError: LocalizedError, Equatable {
    case notConnected
    case connectionFailed(reason: String)
    case publishFailed(topic: String, reason: String)
    case subscribeFailed(topic: String, reason: String)
    case decodingFailed(topic: String)
    case encodingFailed(commandType: String)
    case invalidConfiguration(reason: String)
    case timeout(operation: String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to the robot. Check your network and broker settings."
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .publishFailed(let topic, let reason):
            return "Failed to send command on \(topic): \(reason)"
        case .subscribeFailed(let topic, let reason):
            return "Failed to subscribe to \(topic): \(reason)"
        case .decodingFailed(let topic):
            return "Received unreadable data on \(topic)."
        case .encodingFailed(let commandType):
            return "Could not prepare \(commandType) for sending."
        case .invalidConfiguration(let reason):
            return "Invalid broker configuration: \(reason)"
        case .timeout(let operation):
            return "\(operation) timed out."
        }
    }
}
