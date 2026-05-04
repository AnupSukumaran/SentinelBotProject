//
//  CommandService.swift
//  SentinelBot
//
//  Encodes and dispatches commands to the robot via MQTT.
//
//  Throttling
//  ──────────
//  `sendMove` is called at joystick frame rate (~20 Hz). To avoid flooding
//  the broker we drop calls that arrive faster than 1/joystickPublishHz.
//  All other commands bypass the throttle because they're rare and must land.
//
//  QoS choices match the robot-side watchdog contract:
//    move      → QoS 0 (fire-and-forget; stale moves are harmless, volume is high)
//    mode      → QoS 1 (delivery confirmed; mode changes must be acknowledged)
//    stop      → QoS 1 (confirmed stop)
//    e-stop    → QoS 2, retained (exactly-once, survives robot reconnects)
//

import Foundation

// MARK: - CommandService

final class CommandService: CommandServiceProtocol {

    private let mqttService: MQTTServiceProtocol
    private let encoder = JSONEncoder.iso8601

    /// Tracks when the most recent move command was published, for throttling.
    private var lastMoveSentAt: Date = .distantPast

    private var minMoveInterval: TimeInterval {
        1.0 / Constants.Control.joystickPublishHz
    }

    init(mqttService: MQTTServiceProtocol) {
        self.mqttService = mqttService
        Log.command.info("CommandService ready")
    }

    // MARK: CommandServiceProtocol

    func sendMove(linear: Double, angular: Double) async throws {
        // Throttle: drop if we published too recently
        let now = Date()
        guard now.timeIntervalSince(lastMoveSentAt) >= minMoveInterval else { return }
        lastMoveSentAt = now

        let cmd = MoveCommand(linear: linear, angular: angular)
        let payload = try encode(cmd, commandType: "MoveCommand")
        try await mqttService.publish(
            topic: Constants.Topics.Command.move,
            payload: payload,
            qos: .atMostOnce,
            retained: false
        )
    }

    func sendStop() async throws {
        let payload = try encode(MoveCommand.stop, commandType: "MoveCommand")
        // Use QoS 1 — stop must be confirmed
        try await mqttService.publish(
            topic: Constants.Topics.Command.move,
            payload: payload,
            qos: .atLeastOnce,
            retained: false
        )
        Log.command.info("Stop sent")
    }

    func sendModeChange(_ mode: RobotMode) async throws {
        let cmd = ModeCommand(mode: mode)
        let payload = try encode(cmd, commandType: "ModeCommand")
        try await mqttService.publish(
            topic: Constants.Topics.Command.mode,
            payload: payload,
            qos: .atLeastOnce,
            retained: false
        )
        Log.command.info("Mode change → \(mode.rawValue)")
    }

    func sendEmergencyStop() async throws {
        let cmd = EmergencyStopCommand()
        let payload = try encode(cmd, commandType: "EmergencyStopCommand")
        // QoS 2 + retained: robot receives exactly once even after reconnect
        try await mqttService.publish(
            topic: Constants.Topics.Command.emergencyStop,
            payload: payload,
            qos: .exactlyOnce,
            retained: true
        )
        Log.command.info("EMERGENCY STOP sent")
    }

    // MARK: Private

    private func encode<T: Encodable>(_ value: T, commandType: String) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            Log.command.error("Encoding failed for \(commandType): \(error)")
            throw SentinelError.encodingFailed(commandType: commandType)
        }
    }
}
