//
//  MockMQTTService.swift
//  SentinelBotTests
//
//  In-memory MQTT service for unit tests. Lets us:
//    - Verify that ViewModels publish the right payload to the right topic
//    - Inject fake incoming messages to test telemetry handling
//    - Simulate connection failures and disconnects
//

import Foundation
import Combine
@testable import SentinelBot

final class MockMQTTService: MQTTServiceProtocol {

    // MARK: - Publishers

    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let incomingSubject = PassthroughSubject<MQTTMessage, Never>()

    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var incomingMessagesPublisher: AnyPublisher<MQTTMessage, Never> {
        incomingSubject.eraseToAnyPublisher()
    }

    var currentState: ConnectionState { connectionStateSubject.value }

    // MARK: - Test inspection

    /// Every published message recorded in order. Tests assert on this.
    private(set) var publishedMessages: [(topic: String, payload: Data, qos: MQTTQoS, retained: Bool)] = []

    /// Every subscribed topic recorded in order.
    private(set) var subscribedTopics: [String] = []

    /// Every unsubscribed topic recorded in order.
    private(set) var unsubscribedTopics: [String] = []

    // MARK: - Test controls

    /// If set, connect() throws this error.
    var connectError: Error?

    /// If set, publish() throws this error.
    var publishError: Error?

    /// If set, subscribe() throws this error.
    var subscribeError: Error?

    // MARK: - Protocol implementation

    func connect(config: BrokerConfig) async throws {
        connectionStateSubject.send(.connecting)
        if let error = connectError {
            connectionStateSubject.send(.error(error.localizedDescription))
            throw error
        }
        connectionStateSubject.send(.connected)
    }

    func disconnect() async {
        connectionStateSubject.send(.disconnected)
    }

    func publish(topic: String, payload: Data, qos: MQTTQoS, retained: Bool) async throws {
        if let error = publishError { throw error }
        publishedMessages.append((topic, payload, qos, retained))
    }

    func subscribe(topic: String, qos: MQTTQoS) async throws {
        if let error = subscribeError { throw error }
        subscribedTopics.append(topic)
    }

    func unsubscribe(topic: String) async throws {
        unsubscribedTopics.append(topic)
    }

    // MARK: - Test helpers

    /// Inject a fake incoming message — simulates the robot publishing telemetry.
    func simulateIncoming(topic: String, payload: Data, qos: MQTTQoS = .atLeastOnce, retained: Bool = false) {
        let msg = MQTTMessage(topic: topic, payload: payload, qos: qos, retained: retained, receivedAt: Date())
        incomingSubject.send(msg)
    }

    /// Convenience: encode a payload then send.
    func simulateIncoming<T: Encodable>(topic: String, value: T) throws {
        let data = try JSONEncoder.iso8601.encode(value)
        simulateIncoming(topic: topic, payload: data)
    }

    /// Force a connection state for tests that need to simulate drops.
    func forceState(_ state: ConnectionState) {
        connectionStateSubject.send(state)
    }
}
