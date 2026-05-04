//
//  MQTTService.swift
//  SentinelBot
//
//  Concrete MQTT transport backed by CocoaMQTT.
//
//  Design notes
//  ────────────
//  • CocoaMQTT's delegate methods are dispatched on the main thread by
//    default (its internal `dispatchQueue` is `.main`). We exploit this by
//    keeping all mutable state on the main actor and bridging delegate
//    callbacks with `Task { @MainActor in … }`.
//
//  • `connect()` suspends the caller until a CONNACK (success or failure)
//    arrives, or until CocoaMQTT's internal socket timeout fires, which
//    causes `mqttDidDisconnect` to be called — also resuming the continuation.
//
//  • On an unexpected disconnect we schedule exponential-backoff reconnect
//    attempts up to `Constants.Defaults.reconnectMaxAttempts`. An intentional
//    `disconnect()` cancels any in-flight reconnect task.
//
//  • We deliberately avoid naming `CocoaMQTTQOS` as a return type anywhere.
//    Instead we pass dot-literal QoS values (`.qos0`, `.qos1`, `.qos2`) in
//    switch statements so the compiler infers the type from context. This
//    keeps the code resilient to the exact type name the installed package
//    version exports.
//

import Foundation
import Combine
import CocoaMQTT

// MARK: - MQTTService

@MainActor
final class MQTTService: NSObject, MQTTServiceProtocol {

    // MARK: Publishers (nonisolated so callers don't need to be @MainActor)

    nonisolated let connectionStatePublisher: AnyPublisher<ConnectionState, Never>
    nonisolated let incomingMessagesPublisher: AnyPublisher<MQTTMessage, Never>

    nonisolated var currentState: ConnectionState {
        _connectionStateSubject.value
    }

    // MARK: Private subjects
    //
    // `nonisolated(unsafe)` is safe here because CurrentValueSubject /
    // PassthroughSubject are internally thread-safe for send() / subscribe().

    nonisolated(unsafe) private let _connectionStateSubject =
        CurrentValueSubject<ConnectionState, Never>(.disconnected)
    nonisolated(unsafe) private let _incomingSubject =
        PassthroughSubject<MQTTMessage, Never>()

    // MARK: Private state

    private var client: CocoaMQTT?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var reconnectTask: Task<Void, Never>?
    private var lastConfig: BrokerConfig?
    private var reconnectAttempts = 0
    private var intentionalDisconnect = false

    // MARK: Init

    override init() {
        connectionStatePublisher  = _connectionStateSubject.eraseToAnyPublisher()
        incomingMessagesPublisher = _incomingSubject.eraseToAnyPublisher()
        super.init()
    }

    // MARK: MQTTServiceProtocol – connect / disconnect

    func connect(config: BrokerConfig) async throws {
        if let validationError = config.validationError() {
            throw SentinelError.invalidConfiguration(reason: validationError)
        }

        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0
        intentionalDisconnect = false
        lastConfig = config

        client?.delegate = nil
        client?.disconnect()
        client = nil

        _connectionStateSubject.send(.connecting)

        let newClient = makeClient(from: config)
        self.client = newClient

        // Suspend until didConnectAck or mqttDidDisconnect fires
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connectContinuation = cont
            let started = newClient.connect()
            if !started {
                connectContinuation = nil
                cont.resume(throwing: SentinelError.connectionFailed(reason: "Socket could not be opened"))
            }
        }
    }

    func disconnect() async {
        intentionalDisconnect = true
        reconnectTask?.cancel()
        reconnectTask = nil
        connectContinuation?.resume(throwing: SentinelError.connectionFailed(reason: "Disconnected by user"))
        connectContinuation = nil
        client?.disconnect()
        _connectionStateSubject.send(.disconnected)
        Log.mqtt.info("Disconnected (intentional)")
    }

    // MARK: MQTTServiceProtocol – pub / sub

    func publish(topic: String, payload: Data, qos: MQTTQoS, retained: Bool) async throws {
        guard currentState.isConnected, let client else {
            throw SentinelError.notConnected
        }
        let msg = cocoaMessage(topic: topic, payload: [UInt8](payload), qos: qos, retained: retained)
        client.publish(msg)
        Log.mqtt.debug("→ \(topic) [\(payload.count)B qos\(qos.rawValue) ret:\(retained)]")
    }

    func subscribe(topic: String, qos: MQTTQoS) async throws {
        guard currentState.isConnected, let client else {
            throw SentinelError.notConnected
        }
        cocoaSubscribe(client: client, topic: topic, qos: qos)
        Log.mqtt.debug("SUB \(topic)")
    }

    func unsubscribe(topic: String) async throws {
        client?.unsubscribe(topic)
        Log.mqtt.debug("UNSUB \(topic)")
    }

    // MARK: QoS helpers
    //
    // Using switch with dot-literal enum cases (.qos0/.qos1/.qos2) lets the
    // compiler infer the CocoaMQTT QoS type from context without us ever
    // spelling out the type name — which varies across CocoaMQTT versions.

    private func cocoaMessage(
        topic: String,
        payload: [UInt8],
        qos: MQTTQoS,
        retained: Bool
    ) -> CocoaMQTTMessage {
        switch qos {
        case .atMostOnce:
            return CocoaMQTTMessage(topic: topic, payload: payload, qos: .qos0, retained: retained)
        case .atLeastOnce:
            return CocoaMQTTMessage(topic: topic, payload: payload, qos: .qos1, retained: retained)
        case .exactlyOnce:
            return CocoaMQTTMessage(topic: topic, payload: payload, qos: .qos2, retained: retained)
        }
    }

    private func cocoaSubscribe(client: CocoaMQTT, topic: String, qos: MQTTQoS) {
        switch qos {
        case .atMostOnce:  client.subscribe(topic, qos: .qos0)
        case .atLeastOnce: client.subscribe(topic, qos: .qos1)
        case .exactlyOnce: client.subscribe(topic, qos: .qos2)
        }
    }

    // MARK: Client factory

    private func makeClient(from config: BrokerConfig) -> CocoaMQTT {
        let c = CocoaMQTT(clientID: config.clientID, host: config.host, port: config.port)
        c.username = config.username
        c.password = config.password
        c.keepAlive = config.keepAliveSeconds
        c.enableSSL = config.useTLS
        c.autoReconnect = false   // We manage reconnect ourselves with backoff
        c.delegate = self
        // Last-Will-and-Testament: broker publishes "offline" if our socket drops
        c.willMessage = CocoaMQTTMessage(
            topic: Constants.Topics.robotPresence,
            payload: Array("offline".utf8),
            qos: .qos1,
            retained: true
        )
        Log.mqtt.info("Client created — \(config.host):\(config.port) id:\(config.clientID)")
        return c
    }

    // MARK: Reconnect

    private func scheduleReconnect() {
        guard let config = lastConfig else { return }
        guard reconnectAttempts < Constants.Defaults.reconnectMaxAttempts else {
            let msg = "Max reconnect attempts (\(Constants.Defaults.reconnectMaxAttempts)) reached"
            Log.mqtt.error("\(msg)")
            _connectionStateSubject.send(.error(msg))
            return
        }

        reconnectAttempts += 1
        let delay = min(
            Constants.Defaults.reconnectInitialDelay * pow(2.0, Double(reconnectAttempts - 1)),
            Constants.Defaults.reconnectMaxDelay
        )
        _connectionStateSubject.send(.reconnecting(attempt: reconnectAttempts))
        Log.mqtt.info("Scheduling reconnect attempt \(self.reconnectAttempts) in \(String(format: "%.1f", delay))s")

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            try? await self.connect(config: config)
        }
    }
}

// MARK: - CocoaMQTTDelegate

extension MQTTService: CocoaMQTTDelegate {

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if ack == .accept {
                Log.mqtt.info("CONNACK: accepted ✓")
                reconnectAttempts = 0
                _connectionStateSubject.send(.connected)
                connectContinuation?.resume()
            } else {
                let reason = String(describing: ack)
                Log.mqtt.error("CONNACK refused: \(reason)")
                _connectionStateSubject.send(.error(reason))
                connectContinuation?.resume(
                    throwing: SentinelError.connectionFailed(reason: reason)
                )
            }
            connectContinuation = nil
        }
    }

    nonisolated func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let cont = connectContinuation {
                // Failure during initial connect attempt
                let reason = err?.localizedDescription ?? "Connection closed before CONNACK"
                _connectionStateSubject.send(.error(reason))
                cont.resume(throwing: SentinelError.connectionFailed(reason: reason))
                connectContinuation = nil
            } else if !intentionalDisconnect {
                Log.mqtt.warning("Unexpected disconnect: \(err?.localizedDescription ?? "unknown")")
                scheduleReconnect()
            }
        }
    }

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // CocoaMQTT's QoS rawValue is UInt8; our MQTTQoS.rawValue is Int
            let qos = MQTTQoS(rawValue: Int(message.qos.rawValue)) ?? .atMostOnce
            let incoming = MQTTMessage(
                topic: message.topic,
                payload: Data(message.payload),
                qos: qos,
                retained: message.retained,
                receivedAt: Date()
            )
            Log.mqtt.debug("← \(message.topic)")
            _incomingSubject.send(incoming)
        }
    }

    // Required delegate stubs

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}
    nonisolated func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        if !failed.isEmpty {
            Log.mqtt.warning("Failed to subscribe to topics: \(failed)")
        }
    }

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}
    nonisolated func mqttDidPing(_ mqtt: CocoaMQTT) {}
    nonisolated func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
}
