//
//  TelemetryService.swift
//  SentinelBot
//
//  Subscribes to MQTT status topics and decodes incoming payloads into typed
//  telemetry packets, emitting them on per-type Combine publishers.
//
//  Topic → type mapping
//  ────────────────────
//    sentinelbot/status/distance  →  DistanceReading
//    sentinelbot/status/battery   →  BatteryStatus
//    sentinelbot/status/position  →  Position
//    sentinelbot/status/mode      →  ModeStatus
//
//  We subscribe with the single wildcard `sentinelbot/status/+` so one
//  SUBSCRIBE packet covers all four topics. The dispatch method routes each
//  message by exact topic string to the correct subject.
//
//  Snapshot
//  ────────
//  `snapshotPublisher` exposes a `TelemetrySnapshot` that is updated each
//  time any individual stream emits. Views that need all values at once can
//  bind to this instead of setting up four separate subscriptions.
//

import Foundation
import Combine

// MARK: - TelemetryService

final class TelemetryService: TelemetryServiceProtocol {

    // MARK: Individual publishers (protocol requirement)

    var distancePublisher: AnyPublisher<DistanceReading, Never> {
        distanceSubject.eraseToAnyPublisher()
    }
    var batteryPublisher: AnyPublisher<BatteryStatus, Never> {
        batterySubject.eraseToAnyPublisher()
    }
    var positionPublisher: AnyPublisher<Position, Never> {
        positionSubject.eraseToAnyPublisher()
    }
    var modePublisher: AnyPublisher<ModeStatus, Never> {
        modeSubject.eraseToAnyPublisher()
    }
    var snapshotPublisher: AnyPublisher<TelemetrySnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }

    // MARK: Private subjects

    private let distanceSubject = PassthroughSubject<DistanceReading, Never>()
    private let batterySubject  = PassthroughSubject<BatteryStatus,   Never>()
    private let positionSubject = PassthroughSubject<Position,         Never>()
    private let modeSubject     = PassthroughSubject<ModeStatus,       Never>()
    private let snapshotSubject = CurrentValueSubject<TelemetrySnapshot, Never>(.empty)

    // MARK: Dependencies

    private let mqttService: MQTTServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    init(mqttService: MQTTServiceProtocol) {
        self.mqttService = mqttService
        wireMessagePipeline()
        wireSnapshotPipeline()
        Log.telemetry.info("TelemetryService ready")
    }

    // MARK: TelemetryServiceProtocol

    func startListening() async throws {
        try await mqttService.subscribe(
            topic: Constants.Topics.Status.allWildcard,
            qos: .atLeastOnce
        )
        Log.telemetry.info("Subscribed to \(Constants.Topics.Status.allWildcard)")
    }

    func stopListening() async {
        try? await mqttService.unsubscribe(topic: Constants.Topics.Status.allWildcard)
        Log.telemetry.info("Unsubscribed from status topics")
    }

    // MARK: Pipeline setup

    /// Routes raw MQTT messages to typed subjects.
    private func wireMessagePipeline() {
        mqttService.incomingMessagesPublisher
            .sink { [weak self] message in
                self?.dispatch(message: message)
            }
            .store(in: &cancellables)
    }

    /// Merges all typed streams into the aggregate snapshot subject.
    private func wireSnapshotPipeline() {
        distanceSubject
            .sink { [weak self] reading in
                guard let self else { return }
                var snap = snapshotSubject.value
                snap.distance = reading
                snapshotSubject.send(snap)
            }
            .store(in: &cancellables)

        batterySubject
            .sink { [weak self] status in
                guard let self else { return }
                var snap = snapshotSubject.value
                snap.battery = status
                snapshotSubject.send(snap)
            }
            .store(in: &cancellables)

        positionSubject
            .sink { [weak self] position in
                guard let self else { return }
                var snap = snapshotSubject.value
                snap.position = position
                snapshotSubject.send(snap)
            }
            .store(in: &cancellables)

        modeSubject
            .sink { [weak self] mode in
                guard let self else { return }
                var snap = snapshotSubject.value
                snap.mode = mode
                snapshotSubject.send(snap)
            }
            .store(in: &cancellables)
    }

    // MARK: Dispatch

    private func dispatch(message: MQTTMessage) {
        switch message.topic {
        case Constants.Topics.Status.distance:
            guard let reading = message.decode(as: DistanceReading.self) else {
                Log.telemetry.warning("Could not decode DistanceReading on \(message.topic)")
                return
            }
            distanceSubject.send(reading)

        case Constants.Topics.Status.battery:
            guard let status = message.decode(as: BatteryStatus.self) else {
                Log.telemetry.warning("Could not decode BatteryStatus on \(message.topic)")
                return
            }
            batterySubject.send(status)

        case Constants.Topics.Status.position:
            guard let position = message.decode(as: Position.self) else {
                Log.telemetry.warning("Could not decode Position on \(message.topic)")
                return
            }
            positionSubject.send(position)

        case Constants.Topics.Status.mode:
            guard let mode = message.decode(as: ModeStatus.self) else {
                Log.telemetry.warning("Could not decode ModeStatus on \(message.topic)")
                return
            }
            modeSubject.send(mode)

        default:
            // Wildcard may catch presence or future topics — silently ignore
            break
        }
    }
}
