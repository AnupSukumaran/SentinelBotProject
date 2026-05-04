//
//  TelemetryViewModel.swift
//  SentinelBot
//
//  Subscribes to the TelemetryService snapshot publisher and exposes the
//  latest readings to the TelemetryView. Also watches for critical
//  conditions (obstacle too close, battery too low) and triggers a haptic
//  alert exactly once per transition into the critical state.
//
//  Lifecycle
//  ─────────
//  Call startListening() in onAppear — it issues the MQTT SUBSCRIBE if not
//  already subscribed. Call stopListening() in onDisappear to clean up.
//  TelemetryService is shared across the app so concurrent listeners are safe.
//

import Foundation
import Combine

@MainActor
final class TelemetryViewModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var snapshot: TelemetrySnapshot = .empty
    @Published private(set) var connectionState: ConnectionState = .disconnected
    /// Non-nil while a distance or battery critical condition is active.
    @Published private(set) var criticalAlert: String?

    // MARK: Dependencies

    private let telemetryService: TelemetryServiceProtocol
    private let mqttService: MQTTServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // Track last alerted state so haptic fires once per transition, not every update
    private var lastDistanceCritical = false
    private var lastBatteryCritical = false

    // MARK: Init

    init(telemetryService: TelemetryServiceProtocol, mqttService: MQTTServiceProtocol) {
        self.telemetryService = telemetryService
        self.mqttService = mqttService
        connectionState = mqttService.currentState

        mqttService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)

        telemetryService.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.snapshot = snapshot
                self.evaluateAlerts(snapshot: snapshot)
            }
            .store(in: &cancellables)
    }

    // MARK: Lifecycle

    func startListening() async {
        do {
            try await telemetryService.startListening()
            Log.telemetry.info("TelemetryView: subscribed to status topics")
        } catch {
            Log.telemetry.error("TelemetryView: startListening failed — \(error.localizedDescription)")
        }
    }

    func stopListening() async {
        await telemetryService.stopListening()
    }

    // MARK: Alert logic

    private func evaluateAlerts(snapshot: TelemetrySnapshot) {
        let distCritical = snapshot.distance?.isCritical ?? false
        let batCritical  = snapshot.battery?.isCritical  ?? false

        if distCritical {
            let cm = Int((snapshot.distance?.distanceCM ?? 0).rounded())
            criticalAlert = "Obstacle at \(cm) cm — collision risk!"
            if !lastDistanceCritical { Haptic.error() }
        } else if batCritical {
            let pct = snapshot.battery?.displayPercentage ?? 0
            criticalAlert = "Battery critical: \(pct)%"
            if !lastBatteryCritical { Haptic.warning() }
        } else {
            criticalAlert = nil
        }

        lastDistanceCritical = distCritical
        lastBatteryCritical  = batCritical
    }
}
