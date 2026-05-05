//
//  ServiceTests.swift
//  SentinelBotTests
//
//  Unit tests for CommandService and TelemetryService using MockMQTTService
//  as the transport layer. No network or broker required.
//

import Testing
import Foundation
import Combine
@testable import SentinelBot

// MARK: - CommandService Tests

@Suite("CommandService")
struct CommandServiceTests {

    private func makeSUT() -> (CommandService, MockMQTTService) {
        let mock = MockMQTTService()
        let sut  = CommandService(mqttService: mock)
        return (sut, mock)
    }

    @Test("sendMove publishes to the correct topic with QoS 0")
    func sendMoveTopic() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)

        try await sut.sendMove(linear: 0.5, angular: -0.3)

        let msg = try #require(mock.publishedMessages.last)
        #expect(msg.topic    == Constants.Topics.Command.move)
        #expect(msg.qos      == .atMostOnce)
        #expect(msg.retained == false)
    }

    @Test("sendMove payload encodes linear and angular correctly")
    func sendMovePayload() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)

        try await sut.sendMove(linear: 1.0, angular: -1.0)

        let msg     = try #require(mock.publishedMessages.last)
        let decoded = try #require(msg.payload.decode(as: MoveCommand.self))
        #expect(decoded.linear  ==  1.0)
        #expect(decoded.angular == -1.0)
    }

    @Test("sendMove clamps values outside -1…1")
    func sendMoveClamping() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)

        try await sut.sendMove(linear: 5.0, angular: -9.0)

        let msg     = try #require(mock.publishedMessages.last)
        let decoded = try #require(msg.payload.decode(as: MoveCommand.self))
        #expect(decoded.linear  ==  1.0)
        #expect(decoded.angular == -1.0)
    }

    @Test("sendMove throttles high-frequency calls")
    func sendMoveThrottling() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)

        // Fire 5 sends back-to-back — only the first should get through
        for _ in 0..<5 {
            try await sut.sendMove(linear: 0.1, angular: 0.0)
        }

        #expect(mock.publishedMessages.count == 1)
    }

    @Test("sendStop uses QoS 1 and encodes a zero-velocity payload")
    func sendStop() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)

        try await sut.sendStop()

        let msg     = try #require(mock.publishedMessages.last)
        let decoded = try #require(msg.payload.decode(as: MoveCommand.self))
        #expect(msg.qos         == .atLeastOnce)
        #expect(decoded.linear  == 0.0)
        #expect(decoded.angular == 0.0)
    }

    @Test("sendModeChange encodes correct mode and uses QoS 1")
    func sendModeChange() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)

        try await sut.sendModeChange(.auto)

        let msg     = try #require(mock.publishedMessages.last)
        let decoded = try #require(msg.payload.decode(as: ModeCommand.self))
        #expect(msg.topic    == Constants.Topics.Command.mode)
        #expect(msg.qos      == .atLeastOnce)
        #expect(decoded.mode == .auto)
    }

    @Test("sendEmergencyStop uses QoS 2 and sets retained flag")
    func sendEmergencyStop() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)

        try await sut.sendEmergencyStop()

        let msg = try #require(mock.publishedMessages.last)
        #expect(msg.topic    == Constants.Topics.Command.emergencyStop)
        #expect(msg.qos      == .exactlyOnce)
        #expect(msg.retained == true)
        #expect(msg.payload.decode(as: EmergencyStopCommand.self) != nil)
    }

    @Test("clearEmergencyStop publishes empty retained payload to estop topic")
    func clearEmergencyStop() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)

        try await sut.clearEmergencyStop()

        let msg = try #require(mock.publishedMessages.last)
        #expect(msg.topic    == Constants.Topics.Command.emergencyStop)
        #expect(msg.retained == true)
        #expect(msg.payload.isEmpty)
    }

    @Test("publish throws when mqttService reports an error")
    func throwsOnPublishError() async throws {
        let (sut, mock) = makeSUT()
        mock.publishError = SentinelError.notConnected

        do {
            try await sut.sendStop()
            Issue.record("Expected an error to be thrown")
        } catch {
            #expect(error is SentinelError)
        }
    }
}

// MARK: - TelemetryService Tests

@Suite("TelemetryService")
struct TelemetryServiceTests {

    private func makeSUT() -> (TelemetryService, MockMQTTService) {
        let mock = MockMQTTService()
        let sut  = TelemetryService(mqttService: mock)
        return (sut, mock)
    }

    @Test("startListening subscribes to status wildcard topic")
    func startListeningSubscribes() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)

        try await sut.startListening()

        #expect(mock.subscribedTopics.contains(Constants.Topics.Status.allWildcard))
    }

    @Test("stopListening unsubscribes from wildcard topic")
    func stopListeningUnsubscribes() async throws {
        let (sut, mock) = makeSUT()
        try await mock.connect(config: .default)
        try await sut.startListening()

        await sut.stopListening()

        #expect(mock.unsubscribedTopics.contains(Constants.Topics.Status.allWildcard))
    }

    @Test("incoming distance message emits DistanceReading")
    func distanceMessageDecoded() async throws {
        let (sut, mock) = makeSUT()
        var cancellables = Set<AnyCancellable>()
        var received: DistanceReading?

        sut.distancePublisher
            .sink { received = $0 }
            .store(in: &cancellables)

        let reading = DistanceReading(distanceMeters: 0.45, timestamp: Date())
        try mock.simulateIncoming(topic: Constants.Topics.Status.distance, value: reading)

        #expect(received?.distanceMeters == 0.45)
    }

    @Test("incoming battery message emits BatteryStatus")
    func batteryMessageDecoded() async throws {
        let (sut, mock) = makeSUT()
        var cancellables = Set<AnyCancellable>()
        var received: BatteryStatus?

        sut.batteryPublisher
            .sink { received = $0 }
            .store(in: &cancellables)

        let status = BatteryStatus(voltageVolts: 11.8, percentage: 0.75, isCharging: false, timestamp: Date())
        try mock.simulateIncoming(topic: Constants.Topics.Status.battery, value: status)

        #expect(received?.displayPercentage == 75)
    }

    @Test("incoming position message emits Position")
    func positionMessageDecoded() async throws {
        let (sut, mock) = makeSUT()
        var cancellables = Set<AnyCancellable>()
        var received: Position?

        sut.positionPublisher
            .sink { received = $0 }
            .store(in: &cancellables)

        let pos = Position(xMeters: 1.5, yMeters: -0.3, headingRadians: 0.0, timestamp: Date())
        try mock.simulateIncoming(topic: Constants.Topics.Status.position, value: pos)

        #expect(received?.xMeters == 1.5)
    }

    @Test("incoming mode message emits ModeStatus")
    func modeMessageDecoded() async throws {
        let (sut, mock) = makeSUT()
        var cancellables = Set<AnyCancellable>()
        var received: ModeStatus?

        sut.modePublisher
            .sink { received = $0 }
            .store(in: &cancellables)

        let mode = ModeStatus(mode: .auto, timestamp: Date())
        try mock.simulateIncoming(topic: Constants.Topics.Status.mode, value: mode)

        #expect(received?.mode == .auto)
    }

    @Test("malformed payload is silently dropped")
    func malformedPayloadDropped() async throws {
        let (sut, mock) = makeSUT()
        var cancellables = Set<AnyCancellable>()
        var receivedCount = 0

        sut.distancePublisher
            .sink { _ in receivedCount += 1 }
            .store(in: &cancellables)

        mock.simulateIncoming(
            topic: Constants.Topics.Status.distance,
            payload: Data("not json".utf8)
        )

        #expect(receivedCount == 0)
    }

    @Test("snapshot updates when any individual stream emits")
    func snapshotUpdatesOnEmit() async throws {
        let (sut, mock) = makeSUT()
        var cancellables = Set<AnyCancellable>()
        var snapshots: [TelemetrySnapshot] = []

        sut.snapshotPublisher
            .dropFirst() // skip the initial .empty value
            .sink { snapshots.append($0) }
            .store(in: &cancellables)

        let reading = DistanceReading(distanceMeters: 1.0, timestamp: Date())
        try mock.simulateIncoming(topic: Constants.Topics.Status.distance, value: reading)

        let battery = BatteryStatus(voltageVolts: 12.0, percentage: 0.90, isCharging: false, timestamp: Date())
        try mock.simulateIncoming(topic: Constants.Topics.Status.battery, value: battery)

        #expect(snapshots.count == 2)
        #expect(snapshots.last?.distance?.distanceMeters == 1.0)
        #expect(snapshots.last?.battery?.displayPercentage == 90)
    }

    @Test("unknown topic is silently ignored")
    func unknownTopicIgnored() async throws {
        let (sut, mock) = makeSUT()
        var cancellables = Set<AnyCancellable>()
        var receivedAny = false

        Publishers.MergeMany(
            sut.distancePublisher.map { _ in true },
            sut.batteryPublisher.map  { _ in true },
            sut.positionPublisher.map { _ in true },
            sut.modePublisher.map     { _ in true }
        )
        .sink { receivedAny = $0 }
        .store(in: &cancellables)

        mock.simulateIncoming(
            topic: "sentinelbot/presence/robot",
            payload: Data("online".utf8)
        )

        #expect(receivedAny == false)
    }
}

// MARK: - Data decode helper (mirrors MQTTMessage.decode for test payloads)

private extension Data {
    func decode<T: Decodable>(as type: T.Type) -> T? {
        try? JSONDecoder.iso8601.decode(type, from: self)
    }
}
