//
//  RootView.swift
//  SentinelBot
//
//  Tab-bar root view. Each tab is backed by its own NavigationStack so
//  navigation state is independent per tab.
//
//  Tab layout:
//    0  Connection  — Phase C  ✅
//    1  Control     — Phase D  ✅
//    2  Telemetry   — Phase E  ✅
//    3  Settings    — Phase C  ✅
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            ConnectionView(
                mqttService: container.mqttService,
                persistenceService: container.persistenceService
            )
            .tabItem {
                Label("Connection", systemImage: "wifi")
            }

            ControlView(
                commandService: container.commandService,
                mqttService: container.mqttService
            )
            .tabItem {
                Label("Control", systemImage: "gamecontroller.fill")
            }

            TelemetryView(
                telemetryService: container.telemetryService,
                mqttService: container.mqttService
            )
            .badge(container.criticalAlertActive ? 1 : 0)
            .tabItem {
                Label("Telemetry", systemImage: "chart.bar.fill")
            }

            SettingsView(persistenceService: container.persistenceService)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Color.Theme.robotPrimary)
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environmentObject(AppContainer())
}
