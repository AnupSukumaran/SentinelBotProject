//
//  ConnectionView.swift
//  SentinelBot
//
//  Shows live connection status and lets the user connect / disconnect.
//  The broker address shown is pulled from the saved PersistenceService config,
//  so editing it in Settings immediately reflects here on next connect.
//

import SwiftUI
import Combine

struct ConnectionView: View {

    @StateObject private var viewModel: ConnectionViewModel

    init(mqttService: MQTTServiceProtocol, persistenceService: PersistenceServiceProtocol) {
        _viewModel = StateObject(wrappedValue:
            ConnectionViewModel(mqttService: mqttService, persistenceService: persistenceService)
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                statusCard
                Spacer()
                connectButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.Theme.groupedBackground.ignoresSafeArea())
        }
    }

    // MARK: Status card

    private var statusCard: some View {
        VStack(spacing: 20) {
            // Robot icon with state colour ring
            ZStack {
                Circle()
                    .stroke(viewModel.connectionState.color.opacity(0.25), lineWidth: 12)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: viewModel.connectionState.isTransitioning ? 0.7 : 1)
                    .stroke(viewModel.connectionState.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(viewModel.connectionState.isTransitioning ? 360 : 0))
                    .animation(
                        viewModel.connectionState.isTransitioning
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: viewModel.connectionState.isTransitioning
                    )
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(viewModel.connectionState.color)
            }

            // Status text
            Text(viewModel.connectionState.displayText)
                .font(.headline)
                .foregroundStyle(viewModel.connectionState.color)
                .animation(.default, value: viewModel.connectionState.displayText)

            // Broker address
            Label(viewModel.brokerAddress, systemImage: "network")
                .font(.subheadline)
                .foregroundStyle(Color.Theme.secondaryText)

            // Error message
            if let error = viewModel.errorMessage {
                errorBanner(message: error)
            }
        }
        .padding(32)
        .background(Color.Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 24)
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.Theme.danger)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.Theme.danger)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Connect / Disconnect button

    private var connectButton: some View {
        Button {
            if viewModel.connectionState.isConnected {
                viewModel.disconnect()
            } else if !viewModel.connectionState.isTransitioning {
                viewModel.connect()
            }
        } label: {
            HStack(spacing: 10) {
                if viewModel.connectionState.isTransitioning {
                    ProgressView()
                        .tint(.white)
                }
                Text(buttonTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(buttonColor, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .disabled(viewModel.connectionState.isTransitioning)
        .animation(.default, value: viewModel.connectionState)
    }

    private var buttonTitle: String {
        switch viewModel.connectionState {
        case .connected:                return "Disconnect"
        case .connecting, .reconnecting: return "Connecting…"
        case .disconnected, .error:     return "Connect"
        }
    }

    private var buttonColor: Color {
        viewModel.connectionState.isConnected ? Color.Theme.danger : Color.Theme.robotPrimary
    }
}

// MARK: - Preview

#Preview {
    ConnectionView(
        mqttService: PreviewMQTTService(),
        persistenceService: PersistenceService()
    )
}

// Minimal preview stub — not used in production
private final class PreviewMQTTService: MQTTServiceProtocol {
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        Just(.disconnected).eraseToAnyPublisher()
    }
    var incomingMessagesPublisher: AnyPublisher<MQTTMessage, Never> {
        Empty().eraseToAnyPublisher()
    }
    var currentState: ConnectionState { .disconnected }
    func connect(config: BrokerConfig) async throws {}
    func disconnect() async {}
    func publish(topic: String, payload: Data, qos: MQTTQoS, retained: Bool) async throws {}
    func subscribe(topic: String, qos: MQTTQoS) async throws {}
    func unsubscribe(topic: String) async throws {}
}
