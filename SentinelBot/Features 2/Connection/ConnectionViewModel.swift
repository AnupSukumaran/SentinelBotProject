//
//  ConnectionViewModel.swift
//  SentinelBot
//
//  Manages the MQTT connection lifecycle for the Connection screen.
//  Loads the saved BrokerConfig from persistence on connect, so the
//  Settings screen and this screen share the same stored config.
//

import Foundation
import Combine

@MainActor
final class ConnectionViewModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var errorMessage: String?

    // MARK: Dependencies

    private let mqttService: MQTTServiceProtocol
    private let persistenceService: PersistenceServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: Derived

    /// Display string for the configured broker, shown in the UI.
    var brokerAddress: String {
        let config = persistenceService.loadBrokerConfig() ?? .default
        return "\(config.host):\(config.port)"
    }

    // MARK: Init

    init(mqttService: MQTTServiceProtocol, persistenceService: PersistenceServiceProtocol) {
        self.mqttService = mqttService
        self.persistenceService = persistenceService
        connectionState = mqttService.currentState

        mqttService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                connectionState = state
                if case .error(let msg) = state {
                    errorMessage = msg
                } else if state.isConnected {
                    errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Actions

    func connect() {
        let config = persistenceService.loadBrokerConfig() ?? .default
        errorMessage = nil
        Task {
            do {
                try await mqttService.connect(config: config)
                Haptic.success()
                Log.app.info("Connected to \(config.host):\(config.port)")
            } catch {
                errorMessage = error.localizedDescription
                Haptic.error()
            }
        }
    }

    func disconnect() {
        Task {
            await mqttService.disconnect()
            Haptic.medium()
        }
    }
}
