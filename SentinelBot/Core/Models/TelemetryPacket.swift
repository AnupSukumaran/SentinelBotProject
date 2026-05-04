//
//  TelemetryPacket.swift
//  SentinelBot
//
//  Telemetry data flowing FROM the robot TO the iOS app via MQTT.
//  Each field has its own MQTT topic under `sentinelbot/status/*`.
//  We model them as separate structs because they arrive on independent
//  schedules — distance updates 10Hz, battery every few seconds, etc.
//

import Foundation

// MARK: - Distance (HC-SR04 ultrasonic sensor)

struct DistanceReading: Codable, Equatable {
    let distanceMeters: Double      // 0.02 ... 4.0 typical range for HC-SR04
    let timestamp: Date

    var distanceCM: Double { distanceMeters * 100 }

    /// Whether this reading represents an obstacle close enough to warrant warning the user.
    var isWarning: Bool { distanceMeters < 0.30 }

    /// Whether this reading represents an imminent collision threat.
    var isCritical: Bool { distanceMeters < 0.15 }
}

// MARK: - Battery

struct BatteryStatus: Codable, Equatable {
    let voltageVolts: Double
    let percentage: Double          // 0.0 ... 1.0
    let isCharging: Bool
    let timestamp: Date

    var displayPercentage: Int { Int((percentage * 100).rounded()) }

    var isLow: Bool { percentage < 0.20 }
    var isCritical: Bool { percentage < 0.10 }
}

// MARK: - Position

/// Robot position relative to its starting point (origin = where it powered on).
/// Not GPS — derived from wheel odometry on the Pi.
struct Position: Codable, Equatable {
    let xMeters: Double
    let yMeters: Double
    let headingRadians: Double      // 0 = facing +x, π/2 = facing +y
    let timestamp: Date

    var headingDegrees: Double { headingRadians * 180.0 / .pi }
}

// MARK: - Mode acknowledgement

/// Sent by the robot whenever its mode actually changes. Allows the app
/// to verify a ModeCommand was honoured rather than just assuming.
struct ModeStatus: Codable, Equatable {
    let mode: RobotMode
    let timestamp: Date
}

// MARK: - Aggregate snapshot

/// Convenience container holding the most recent of each telemetry type.
/// The TelemetryViewModel maintains one of these by merging incoming streams.
struct TelemetrySnapshot: Equatable {
    var distance: DistanceReading?
    var battery: BatteryStatus?
    var position: Position?
    var mode: ModeStatus?

    static let empty = TelemetrySnapshot()
}
