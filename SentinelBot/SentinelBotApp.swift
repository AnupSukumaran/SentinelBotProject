//
//  SentinelBotApp.swift
//  SentinelBot
//
//  Application entry point. Constructs the service dependency container once
//  and injects it into the root view via the environment.
//

import SwiftUI
import Combine

@main
struct SentinelBotApp: App {

    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
        }
    }
}

// MARK: - Dependency container

@MainActor
final class AppContainer: ObservableObject {

    // Services — protocol-typed so ViewModels never import CocoaMQTT directly.
    let mqttService: MQTTServiceProtocol
    let commandService: CommandServiceProtocol
    let telemetryService: TelemetryServiceProtocol
    let persistenceService: PersistenceServiceProtocol

    /// True while any telemetry reading is in a critical state.
    /// Drives the Telemetry tab badge in RootView.
    @Published private(set) var criticalAlertActive = false

    init() {
        let mqtt        = MQTTService()
        let commands    = CommandService(mqttService: mqtt)
        let telemetry   = TelemetryService(mqttService: mqtt)
        let persistence = PersistenceService()

        self.mqttService        = mqtt
        self.commandService     = commands
        self.telemetryService   = telemetry
        self.persistenceService = persistence

        // Watch for critical sensor conditions to drive the tab badge
        telemetry.snapshotPublisher
            .map { snap in
                (snap.distance?.isCritical ?? false) || (snap.battery?.isCritical ?? false)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$criticalAlertActive)

        Log.app.info("AppContainer initialised (Phase F)")
    }
}
