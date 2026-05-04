//
//  SentinelBotApp.swift
//  SentinelBot
//
//  Application entry point. Constructs the service dependency container once
//  and injects it into the root view via the environment.
//

import SwiftUI

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

    init() {
        let mqtt        = MQTTService()
        let commands    = CommandService(mqttService: mqtt)
        let telemetry   = TelemetryService(mqttService: mqtt)
        let persistence = PersistenceService()

        self.mqttService        = mqtt
        self.commandService     = commands
        self.telemetryService   = telemetry
        self.persistenceService = persistence

        Log.app.info("AppContainer initialised (Phase C)")
    }
}
