//
//  MQTTServiceProtocol.swift
//  SentinelBot
//
//  Abstraction over our MQTT transport. The rest of the app depends on this
//  protocol, never on CocoaMQTT directly. That means:
//    1. Tests can substitute MockMQTTService.
//    2. Swapping libraries (or moving to URLSession WebSockets) requires
//       changing only the concrete implementation.
//
//  The protocol exposes Combine publishers for ongoing state and async
//  functions for one-shot operations — the right tool for each shape of work.
//

import Foundation
import Combine

// MARK: - Supporting types

enum MQTTQoS: Int {
    case atMostOnce  = 0     // fire-and-forget — fine for high-frequency telemetry
    case atLeastOnce = 1     // delivery confirmed — use for commands
    case exactlyOnce = 2     // delivery confirmed exactly once — overkill for us
}

/// A raw message received from the broker, before any decoding.
/// TelemetryService is responsible for decoding into typed packets.
struct MQTTMessage: Equatable {
    let topic: String
    let payload: Data
    let qos: MQTTQoS
    let retained: Bool
    let receivedAt: Date

    /// Convenience: decode payload as JSON to a Decodable type.
    func decode<T: Decodable>(as type: T.Type, decoder: JSONDecoder = .iso8601) -> T? {
        try? decoder.decode(type, from: payload)
    }
}

// MARK: - Protocol

protocol MQTTServiceProtocol: AnyObject {

    /// Continuous stream of connection state changes.
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }

    /// Continuous stream of all incoming messages across all subscribed topics.
    /// TelemetryService filters this by topic.
    var incomingMessagesPublisher: AnyPublisher<MQTTMessage, Never> { get }

    /// Current connection state — synchronous snapshot. Useful for guards.
    var currentState: ConnectionState { get }

    /// Establish the MQTT connection. Throws on failure. Awaits CONNACK.
    func connect(config: BrokerConfig) async throws

    /// Cleanly disconnect, sending DISCONNECT to the broker.
    func disconnect() async

    /// Publish a payload to a topic.
    func publish(topic: String, payload: Data, qos: MQTTQoS, retained: Bool) async throws

    /// Subscribe to a topic (or wildcard pattern).
    func subscribe(topic: String, qos: MQTTQoS) async throws

    /// Unsubscribe from a previously subscribed topic.
    func unsubscribe(topic: String) async throws
}

// MARK: - Convenience defaults

extension MQTTServiceProtocol {
    func publish(topic: String, payload: Data, qos: MQTTQoS = .atLeastOnce) async throws {
        try await publish(topic: topic, payload: payload, qos: qos, retained: false)
    }

    func subscribe(topic: String) async throws {
        try await subscribe(topic: topic, qos: .atLeastOnce)
    }
}

// MARK: - JSONDecoder ISO8601 default

extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
