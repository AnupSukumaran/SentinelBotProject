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
            // Replaced with a real root view in Phase C.
            PlaceholderRootView()
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

        Log.app.info("AppContainer initialised (Phase B)")
    }
}

// MARK: - Phase A/B placeholder root view

private struct PlaceholderRootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(Color.Theme.robotPrimary)
            Text("SentinelBot")
                .font(.largeTitle.bold())
            Text("Phase B — services wired")
                .foregroundStyle(.secondary)
            Text("Connection & Control views arrive in Phases C–D.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    PlaceholderRootView()
}
