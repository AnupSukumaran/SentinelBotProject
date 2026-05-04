//
//  Constants.swift
//  SentinelBot
//
//  Centralised constants. The MQTT topic strings here MUST match those in
//  the robot-side mqtt_bridge_node.py — keep both files in sync.
//

import Foundation

enum Constants {

    // MARK: - MQTT Topics

    enum Topics {
        static let root = "sentinelbot"

        // Outgoing — iOS to robot
        enum Command {
            static let move          = "sentinelbot/cmd/move"
            static let mode          = "sentinelbot/cmd/mode"
            static let emergencyStop = "sentinelbot/cmd/estop"
        }

        // Incoming — robot to iOS
        enum Status {
            static let distance = "sentinelbot/status/distance"
            static let battery  = "sentinelbot/status/battery"
            static let position = "sentinelbot/status/position"
            static let mode     = "sentinelbot/status/mode"

            /// Wildcard subscription that catches all status topics.
            static let allWildcard = "sentinelbot/status/+"
        }

        // Last-Will-and-Testament — broker publishes this if the robot drops off
        static let robotPresence = "sentinelbot/presence/robot"
    }

    // MARK: - Defaults

    enum Defaults {
        static let mqttPort: UInt16 = 1883
        static let mqttTLSPort: UInt16 = 8883
        static let keepAliveSeconds: UInt16 = 30
        static let connectTimeoutSeconds: TimeInterval = 10
        static let reconnectInitialDelay: TimeInterval = 1.0
        static let reconnectMaxDelay: TimeInterval = 30.0
        static let reconnectMaxAttempts: Int = 10
    }

    // MARK: - Control

    enum Control {
        /// Throttle joystick publishes to this rate (Hz) to avoid flooding the broker.
        static let joystickPublishHz: Double = 20

        /// Maximum duration between joystick publishes before the robot considers
        /// the link dead and stops moving. Matches the robot-side watchdog.
        static let watchdogTimeoutSeconds: TimeInterval = 0.5
    }

    // MARK: - Persistence Keys

    enum PersistenceKeys {
        static let brokerConfig = "sentinelbot.brokerConfig"
        static let lastUsedMode = "sentinelbot.lastUsedMode"
        static let hasCompletedOnboarding = "sentinelbot.hasCompletedOnboarding"
    }
}
