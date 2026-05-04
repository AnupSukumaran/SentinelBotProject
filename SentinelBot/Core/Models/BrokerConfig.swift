//
//  BrokerConfig.swift
//  SentinelBot
//
//  MQTT broker connection configuration. Persisted in UserDefaults via PersistenceService.
//  The clientID is generated once per install so the broker can recognise this device.
//

import Foundation

struct BrokerConfig: Codable, Equatable {
    var host: String
    var port: UInt16
    var username: String?
    var password: String?
    var useTLS: Bool
    var clientID: String
    var keepAliveSeconds: UInt16

    static let `default` = BrokerConfig(
        host: "raspberrypi.local",
        port: 1883,
        username: nil,
        password: nil,
        useTLS: false,
        clientID: "sentinelbot-ios-\(UUID().uuidString.prefix(8))",
        keepAliveSeconds: 30
    )

    /// Validates the config. Returns nil if valid, an error message string otherwise.
    func validationError() -> String? {
        if host.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Host cannot be empty"
        }
        if port == 0 {
            return "Port must be between 1 and 65535"
        }
        if useTLS && port == 1883 {
            return "TLS usually runs on port 8883, not 1883"
        }
        return nil
    }
}
