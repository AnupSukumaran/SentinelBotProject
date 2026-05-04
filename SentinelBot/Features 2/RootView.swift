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
//    2  Telemetry   — Phase E  (placeholder)
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

            // Phase E placeholder
            PlaceholderTabView(
                icon: "chart.bar.fill",
                title: "Telemetry",
                subtitle: "Distance gauge, battery, and alerts arrive in Phase E."
            )
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

// MARK: - Placeholder tab

private struct PlaceholderTabView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 52))
                    .foregroundStyle(Color.Theme.robotPrimary.opacity(0.4))
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.Theme.groupedBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environmentObject(AppContainer())
}
