//
//  TelemetryServiceProtocol.swift
//  SentinelBot
//
//  Decodes incoming MQTT messages into typed telemetry packets and
//  exposes them as Combine publishers. ViewModels subscribe to whichever
//  streams they need.
//

import Foundation
import Combine

protocol TelemetryServiceProtocol: AnyObject {

    /// Stream of distance readings from the HC-SR04.
    var distancePublisher: AnyPublisher<DistanceReading, Never> { get }

    /// Stream of battery status updates.
    var batteryPublisher: AnyPublisher<BatteryStatus, Never> { get }

    /// Stream of position updates from wheel odometry.
    var positionPublisher: AnyPublisher<Position, Never> { get }

    /// Stream of mode acknowledgements from the robot.
    var modePublisher: AnyPublisher<ModeStatus, Never> { get }

    /// Aggregate snapshot — combines latest values of all streams above.
    /// Convenient for views that need a single source of truth.
    var snapshotPublisher: AnyPublisher<TelemetrySnapshot, Never> { get }

    /// Subscribe to all robot status topics. Call after the MQTT connection
    /// is established.
    func startListening() async throws

    /// Unsubscribe from all status topics.
    func stopListening() async
}
