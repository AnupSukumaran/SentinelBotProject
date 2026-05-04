//
//  RobotCommand.swift
//  SentinelBot
//
//  Commands sent from the iOS app to the robot via MQTT.
//  Each command has a corresponding topic under `sentinelbot/cmd/*`.
//
//  All commands include a timestamp so the robot can reject stale messages
//  (important for safety — a delayed "move forward" arriving after the user
//  has already lifted their finger off the joystick is a hazard).
//

import Foundation

// MARK: - Movement

/// Velocity command. linear and angular are normalised to -1.0 ... 1.0
/// The robot side (mqtt_bridge_node.py) converts these to /cmd_vel Twist messages.
struct MoveCommand: Codable, Equatable {
    let linear: Double      // forward/back, -1.0 ... 1.0
    let angular: Double     // turn left/right, -1.0 ... 1.0
    let timestamp: Date

    init(linear: Double, angular: Double, timestamp: Date = Date()) {
        self.linear = linear.clamped(to: -1.0...1.0)
        self.angular = angular.clamped(to: -1.0...1.0)
        self.timestamp = timestamp
    }

    static let stop = MoveCommand(linear: 0, angular: 0)
}

// MARK: - Mode

struct ModeCommand: Codable, Equatable {
    let mode: RobotMode
    let timestamp: Date

    init(mode: RobotMode, timestamp: Date = Date()) {
        self.mode = mode
        self.timestamp = timestamp
    }
}

// MARK: - Emergency Stop

/// Highest-priority command. Robot must halt all motors immediately and
/// require explicit user action to resume.
struct EmergencyStopCommand: Codable, Equatable {
    let timestamp: Date

    init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
