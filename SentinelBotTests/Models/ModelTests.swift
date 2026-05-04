//
//  ModelTests.swift
//  SentinelBotTests
//
//  Unit tests for the Core Models. We test:
//    - Codable round-trips (encode then decode → equal value)
//    - Validation logic (clamping, error detection)
//    - Computed properties (display strings, threshold flags)
//

import XCTest
@testable import SentinelBot

final class ModelTests: XCTestCase {

    private let encoder = JSONEncoder.iso8601
    private let decoder = JSONDecoder.iso8601

    // MARK: - MoveCommand

    func testMoveCommand_clampsValuesToValidRange() {
        let cmd = MoveCommand(linear: 5.0, angular: -3.0)
        XCTAssertEqual(cmd.linear, 1.0)
        XCTAssertEqual(cmd.angular, -1.0)
    }

    func testMoveCommand_codableRoundTrip() throws {
        let original = MoveCommand(linear: 0.5, angular: -0.2)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MoveCommand.self, from: data)
        XCTAssertEqual(decoded.linear, original.linear, accuracy: 0.0001)
        XCTAssertEqual(decoded.angular, original.angular, accuracy: 0.0001)
    }

    func testMoveCommand_stopHasZeroValues() {
        XCTAssertEqual(MoveCommand.stop.linear, 0)
        XCTAssertEqual(MoveCommand.stop.angular, 0)
    }

    // MARK: - DistanceReading

    func testDistanceReading_warningThresholds() {
        let safe = DistanceReading(distanceMeters: 1.0, timestamp: Date())
        let warn = DistanceReading(distanceMeters: 0.25, timestamp: Date())
        let crit = DistanceReading(distanceMeters: 0.10, timestamp: Date())

        XCTAssertFalse(safe.isWarning)
        XCTAssertFalse(safe.isCritical)

        XCTAssertTrue(warn.isWarning)
        XCTAssertFalse(warn.isCritical)

        XCTAssertTrue(crit.isWarning)
        XCTAssertTrue(crit.isCritical)
    }

    func testDistanceReading_metersToCM() {
        let r = DistanceReading(distanceMeters: 0.45, timestamp: Date())
        XCTAssertEqual(r.distanceCM, 45.0, accuracy: 0.0001)
    }

    // MARK: - BatteryStatus

    func testBatteryStatus_thresholds() {
        let healthy = BatteryStatus(voltageVolts: 12, percentage: 0.80, isCharging: false, timestamp: Date())
        let low     = BatteryStatus(voltageVolts: 12, percentage: 0.15, isCharging: false, timestamp: Date())
        let crit    = BatteryStatus(voltageVolts: 12, percentage: 0.05, isCharging: false, timestamp: Date())

        XCTAssertFalse(healthy.isLow)
        XCTAssertFalse(healthy.isCritical)
        XCTAssertEqual(healthy.displayPercentage, 80)

        XCTAssertTrue(low.isLow)
        XCTAssertFalse(low.isCritical)

        XCTAssertTrue(crit.isLow)
        XCTAssertTrue(crit.isCritical)
    }

    // MARK: - BrokerConfig

    func testBrokerConfig_validationRejectsEmptyHost() {
        var cfg = BrokerConfig.default
        cfg.host = "   "
        XCTAssertNotNil(cfg.validationError())
    }

    func testBrokerConfig_validationRejectsZeroPort() {
        var cfg = BrokerConfig.default
        cfg.port = 0
        XCTAssertNotNil(cfg.validationError())
    }

    func testBrokerConfig_validationFlagsTLSOnPlainPort() {
        var cfg = BrokerConfig.default
        cfg.useTLS = true
        cfg.port = 1883
        XCTAssertNotNil(cfg.validationError())
    }

    func testBrokerConfig_defaultIsValid() {
        XCTAssertNil(BrokerConfig.default.validationError())
    }

    // MARK: - ConnectionState

    func testConnectionState_isConnectedOnlyForConnected() {
        XCTAssertTrue(ConnectionState.connected.isConnected)
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
        XCTAssertFalse(ConnectionState.connecting.isConnected)
        XCTAssertFalse(ConnectionState.reconnecting(attempt: 1).isConnected)
        XCTAssertFalse(ConnectionState.error("x").isConnected)
    }

    func testConnectionState_isTransitioningForConnectingAndReconnecting() {
        XCTAssertTrue(ConnectionState.connecting.isTransitioning)
        XCTAssertTrue(ConnectionState.reconnecting(attempt: 3).isTransitioning)
        XCTAssertFalse(ConnectionState.connected.isTransitioning)
        XCTAssertFalse(ConnectionState.disconnected.isTransitioning)
    }

    // MARK: - RobotMode

    func testRobotMode_codableRoundTrip() throws {
        for mode in RobotMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(RobotMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }
}
