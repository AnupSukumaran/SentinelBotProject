//
//  CommandServiceProtocol.swift
//  SentinelBot
//
//  High-level command API. ViewModels call these methods rather than
//  building MQTT payloads themselves. The implementation handles JSON
//  encoding, topic routing, QoS selection, and throttling.
//

import Foundation

protocol CommandServiceProtocol: AnyObject {

    /// Send a velocity command. Called at high frequency (~20Hz) while
    /// the joystick is active. The implementation should throttle internally.
    func sendMove(linear: Double, angular: Double) async throws

    /// Stop the robot. Equivalent to sendMove(0, 0) but uses a higher QoS
    /// to ensure delivery.
    func sendStop() async throws

    /// Switch operating mode.
    func sendModeChange(_ mode: RobotMode) async throws

    /// Emergency stop. Highest QoS, retained on broker so any subscriber
    /// (including a robot that reconnects) receives it immediately.
    func sendEmergencyStop() async throws

    /// Clears the retained emergency stop from the broker by publishing an
    /// empty payload to the same topic. Call this when the user resumes.
    func clearEmergencyStop() async throws
}
