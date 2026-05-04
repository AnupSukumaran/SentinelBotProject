//
//  ControlViewModel.swift
//  SentinelBot
//
//  Drives the robot via CommandService.
//
//  Watchdog
//  ────────
//  The robot-side watchdog stops the motors if no MoveCommand arrives within
//  Constants.Control.watchdogTimeoutSeconds (0.5 s). We keep a repeating Timer
//  that fires at joystickPublishHz (20 Hz) while the joystick is active, so the
//  robot always gets a fresh command even when the finger sits still on the pad.
//
//  Emergency stop
//  ──────────────
//  triggerEmergencyStop() locks the UI and sends a retained QoS-2 e-stop to
//  the broker. clearEmergencyStop() re-enables the UI; the broker retains the
//  e-stop until the app or another client explicitly clears it (Phase F).
//

import Foundation
import Combine

@MainActor
final class ControlViewModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var currentMode: RobotMode = .manual
    @Published private(set) var isEmergencyStopped = false
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var commandError: String?

    // MARK: Derived

    var joystickEnabled: Bool {
        connectionState.isConnected && !isEmergencyStopped && currentMode == .manual
    }

    // MARK: Private

    private let commandService: CommandServiceProtocol
    private let mqttService: MQTTServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    private var lastLinear: Double = 0
    private var lastAngular: Double = 0
    private var watchdogTimer: Timer?

    // MARK: Init

    init(commandService: CommandServiceProtocol, mqttService: MQTTServiceProtocol) {
        self.commandService = commandService
        self.mqttService = mqttService
        connectionState = mqttService.currentState

        mqttService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                connectionState = state
                if !state.isConnected {
                    stopWatchdog()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Joystick

    /// Called by the joystick view on every gesture update.
    func joystickMoved(linear: Double, angular: Double) {
        guard joystickEnabled else { return }
        lastLinear = linear
        lastAngular = angular
        if watchdogTimer == nil {
            startWatchdog()
        }
    }

    /// Called when the finger lifts off the joystick.
    func joystickReleased() {
        stopWatchdog()
        lastLinear = 0
        lastAngular = 0
        Task {
            do {
                try await commandService.sendStop()
            } catch {
                commandError = error.localizedDescription
            }
        }
    }

    // MARK: Mode

    func changeMode(_ mode: RobotMode) {
        guard connectionState.isConnected, !isEmergencyStopped else { return }
        guard mode != currentMode else { return }
        // Stop any active movement before switching modes
        if watchdogTimer != nil { joystickReleased() }
        Task {
            do {
                try await commandService.sendModeChange(mode)
                currentMode = mode
                Haptic.selection()
                Log.app.info("Mode changed to \(mode.rawValue)")
            } catch {
                commandError = error.localizedDescription
                Haptic.warning()
            }
        }
    }

    // MARK: Emergency stop

    func triggerEmergencyStop() {
        stopWatchdog()
        isEmergencyStopped = true
        Haptic.heavy()
        Task {
            do {
                try await commandService.sendEmergencyStop()
                Log.app.notice("Emergency stop triggered")
            } catch {
                commandError = error.localizedDescription
            }
        }
    }

    /// Re-enables the UI. Does not publish a broker clear (Phase F).
    func clearEmergencyStop() {
        isEmergencyStopped = false
        lastLinear = 0
        lastAngular = 0
        Haptic.medium()
        Log.app.info("Emergency stop cleared by user")
    }

    // MARK: Watchdog timer

    private func startWatchdog() {
        let interval = 1.0 / Constants.Control.joystickPublishHz
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.joystickEnabled else { return }
                try? await self.commandService.sendMove(
                    linear: self.lastLinear,
                    angular: self.lastAngular
                )
            }
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }
}
