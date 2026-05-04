//
//  ControlView.swift
//  SentinelBot
//
//  Robot control screen: virtual joystick, mode picker, and emergency stop.
//
//  Layout adapts to orientation:
//    Portrait  — mode picker → joystick → e-stop (stacked vertically)
//    Landscape — joystick left | (mode picker + e-stop) right
//
//  JoystickView
//  ────────────
//  A 220 pt circular track with a 64 pt thumb. The drag gesture snaps the
//  thumb to the finger position (clamped to the track radius). Coordinates:
//    +linear  = forward   (finger above centre)
//    -linear  = backward  (finger below centre)
//    +angular = right     (finger right of centre)
//    -angular = left      (finger left of centre)
//

import SwiftUI
import Combine

// MARK: - ControlView

struct ControlView: View {

    @StateObject private var viewModel: ControlViewModel

    init(commandService: CommandServiceProtocol, mqttService: MQTTServiceProtocol) {
        _viewModel = StateObject(wrappedValue:
            ControlViewModel(commandService: commandService, mqttService: mqttService)
        )
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                if geo.size.width > geo.size.height {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            }
            .navigationTitle("Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { connectionBadge }
            .background(Color.Theme.groupedBackground.ignoresSafeArea())
        }
    }

    // MARK: Layouts

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            modePickerView
                .padding(.top, 16)
            Spacer()
            joystickOrDisabledView
            Spacer()
            eStopButton
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
        }
    }

    private var landscapeLayout: some View {
        HStack(spacing: 32) {
            joystickOrDisabledView
                .frame(maxWidth: .infinity)
            VStack(spacing: 20) {
                modePickerView
                Spacer()
                eStopButton
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Joystick / disabled state

    @ViewBuilder
    private var joystickOrDisabledView: some View {
        if !viewModel.connectionState.isConnected {
            joystickPlaceholder(
                icon: "wifi.slash",
                message: "Connect to the robot first"
            )
        } else if viewModel.isEmergencyStopped {
            joystickPlaceholder(
                icon: "exclamationmark.octagon.fill",
                message: "Emergency stop active\nTap Resume to continue"
            )
        } else if viewModel.currentMode == .auto {
            joystickPlaceholder(
                icon: "cpu.fill",
                message: "Autonomous mode\nJoystick inactive"
            )
        } else {
            JoystickView(
                onMove: viewModel.joystickMoved,
                onRelease: viewModel.joystickReleased,
                isEnabled: viewModel.joystickEnabled
            )
        }
    }

    private func joystickPlaceholder(icon: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.Theme.secondaryText.opacity(0.45))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(width: 220, height: 220)
        .background(
            Circle()
                .fill(Color.Theme.secondaryBackground)
                .overlay(Circle().stroke(Color.Theme.secondaryText.opacity(0.2), lineWidth: 1.5))
        )
    }

    // MARK: Mode picker

    private var modePickerView: some View {
        Picker("Mode", selection: Binding(
            get: { viewModel.currentMode },
            set: { viewModel.changeMode($0) }
        )) {
            ForEach(RobotMode.allCases, id: \.self) { mode in
                Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 32)
        .disabled(!viewModel.connectionState.isConnected || viewModel.isEmergencyStopped)
    }

    // MARK: E-stop / Resume

    @ViewBuilder
    private var eStopButton: some View {
        if viewModel.isEmergencyStopped {
            Button {
                viewModel.clearEmergencyStop()
            } label: {
                Label("Resume", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.Theme.warning, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
        } else {
            Button {
                viewModel.triggerEmergencyStop()
            } label: {
                Label("Emergency Stop", systemImage: "stop.fill")
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        viewModel.connectionState.isConnected
                            ? Color.Theme.danger
                            : Color.Theme.danger.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .foregroundStyle(.white)
            }
            .disabled(!viewModel.connectionState.isConnected)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var connectionBadge: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.connectionState.color)
                    .frame(width: 8, height: 8)
                Text(viewModel.connectionState.displayText)
                    .font(.caption)
                    .foregroundStyle(viewModel.connectionState.color)
            }
        }
    }
}

// MARK: - JoystickView

private struct JoystickView: View {

    let onMove: (Double, Double) -> Void   // (linear, angular), normalised -1...1
    let onRelease: () -> Void
    let isEnabled: Bool

    @State private var thumbOffset: CGSize = .zero

    private let trackDiameter: CGFloat = 220
    private let thumbDiameter: CGFloat = 64
    private var maxOffset: CGFloat { (trackDiameter - thumbDiameter) / 2 }

    var body: some View {
        ZStack {
            // Track background
            Circle()
                .fill(Color.Theme.secondaryBackground)
                .overlay(
                    Circle().stroke(
                        Color.Theme.robotPrimary.opacity(isEnabled ? 0.35 : 0.12),
                        lineWidth: 2
                    )
                )

            // Crosshair guides
            Rectangle()
                .fill(Color.Theme.robotPrimary.opacity(isEnabled ? 0.12 : 0.06))
                .frame(width: 1, height: trackDiameter * 0.65)
            Rectangle()
                .fill(Color.Theme.robotPrimary.opacity(isEnabled ? 0.12 : 0.06))
                .frame(width: trackDiameter * 0.65, height: 1)

            // Thumb
            Circle()
                .fill(isEnabled ? Color.Theme.robotPrimary : Color.Theme.secondaryText.opacity(0.4))
                .shadow(
                    color: isEnabled ? Color.Theme.robotPrimary.opacity(0.45) : .clear,
                    radius: thumbOffset == .zero ? 4 : 10
                )
                .frame(width: thumbDiameter, height: thumbDiameter)
                .offset(thumbOffset)
                .animation(.interactiveSpring(), value: thumbOffset)
        }
        .frame(width: trackDiameter, height: trackDiameter)
        .contentShape(Circle())
        .gesture(isEnabled ? dragGesture : nil)
        .opacity(isEnabled ? 1 : 0.6)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                // Snap thumb to finger position relative to track centre
                let centre = CGPoint(x: trackDiameter / 2, y: trackDiameter / 2)
                let dx = value.location.x - centre.x
                let dy = value.location.y - centre.y
                let dist = sqrt(dx * dx + dy * dy)
                let clamped = min(dist, maxOffset)
                let angle = atan2(dy, dx)

                thumbOffset = CGSize(
                    width:  cos(angle) * clamped,
                    height: sin(angle) * clamped
                )

                // linear: up = positive (screen y is inverted)
                // angular: right = positive
                let linear  = -(sin(angle) * clamped / maxOffset)
                let angular =   cos(angle) * clamped / maxOffset
                onMove(linear, angular)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    thumbOffset = .zero
                }
                onRelease()
            }
    }
}

// MARK: - Preview

#Preview {
    ControlView(
        commandService: PreviewCommandService(),
        mqttService: PreviewMQTTServiceForControl()
    )
}

private final class PreviewCommandService: CommandServiceProtocol {
    func sendMove(linear: Double, angular: Double) async throws {}
    func sendStop() async throws {}
    func sendModeChange(_ mode: RobotMode) async throws {}
    func sendEmergencyStop() async throws {}
}

private final class PreviewMQTTServiceForControl: MQTTServiceProtocol {
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        Just(.connected).eraseToAnyPublisher()
    }
    var incomingMessagesPublisher: AnyPublisher<MQTTMessage, Never> {
        Empty().eraseToAnyPublisher()
    }
    var currentState: ConnectionState { .connected }
    func connect(config: BrokerConfig) async throws {}
    func disconnect() async {}
    func publish(topic: String, payload: Data, qos: MQTTQoS, retained: Bool) async throws {}
    func subscribe(topic: String, qos: MQTTQoS) async throws {}
    func unsubscribe(topic: String) async throws {}
}
