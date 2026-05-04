//
//  RobotMode.swift
//  SentinelBot
//
//  The operating mode of the robot. Manual = controlled via joystick.
//  Auto = robot runs its own obstacle-avoidance loop on the Pi.
//

import Foundation

enum RobotMode: String, Codable, CaseIterable, Equatable {
    case manual
    case auto

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .auto:   return "Autonomous"
        }
    }

    var symbolName: String {
        switch self {
        case .manual: return "gamecontroller.fill"
        case .auto:   return "cpu.fill"
        }
    }
}
