//
//  TelemetryView.swift
//  SentinelBot
//
//  Displays live sensor data from the robot:
//    • Distance card  — 270° arc gauge, 0–400 cm, colour-coded by proximity
//    • Battery card   — progress bar, percentage, voltage, charging indicator
//    • Status card    — confirmed robot mode + odometry position
//
//  A full-width alert banner slides in at the top whenever a critical
//  distance or battery threshold is crossed.
//
//  ArcGaugeView
//  ────────────
//  Built with two overlapping trimmed Circles (track + fill), rotated so
//  the arc spans from the 7 o'clock to 5 o'clock position (270° total).
//

import SwiftUI
import Combine

// MARK: - TelemetryView

struct TelemetryView: View {

    @StateObject private var viewModel: TelemetryViewModel

    init(telemetryService: TelemetryServiceProtocol, mqttService: MQTTServiceProtocol) {
        _viewModel = StateObject(wrappedValue:
            TelemetryViewModel(telemetryService: telemetryService, mqttService: mqttService)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                scrollContent
                alertBanner
            }
            .navigationTitle("Telemetry")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { connectionBadge }
            .background(Color.Theme.groupedBackground.ignoresSafeArea())
            .onAppear  { Task { await viewModel.startListening() } }
            .onDisappear { Task { await viewModel.stopListening() } }
        }
    }

    // MARK: Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                distanceCard
                batteryCard
                statusCard
            }
            .padding(.horizontal, 16)
            .padding(.top, viewModel.criticalAlert != nil ? 60 : 16)
            .padding(.bottom, 24)
            .animation(.default, value: viewModel.criticalAlert != nil)
        }
    }

    // MARK: - Alert banner

    @ViewBuilder
    private var alertBanner: some View {
        if let alert = viewModel.criticalAlert {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.Theme.danger)
                Text(alert)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Theme.danger)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Divider().background(Color.Theme.danger.opacity(0.4))
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Distance card

    private var distanceCard: some View {
        TelemetryCard(title: "Distance", systemImage: "sensor.fill") {
            if let reading = viewModel.snapshot.distance {
                VStack(spacing: 12) {
                    ArcGaugeView(
                        value: min(reading.distanceMeters / 4.0, 1.0),
                        color: reading.displayColor,
                        label: {
                            VStack(spacing: 2) {
                                Text(String(format: "%.0f", reading.distanceCM))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(reading.displayColor)
                                Text("cm")
                                    .font(.caption)
                                    .foregroundStyle(Color.Theme.secondaryText)
                            }
                        }
                    )
                    .frame(width: 180, height: 180)

                    distanceStatusPill(reading: reading)
                }
            } else {
                noDataView(icon: "sensor.fill", message: "Waiting for distance data…")
            }
        }
    }

    private func distanceStatusPill(reading: DistanceReading) -> some View {
        let label: String
        let color: Color
        if reading.isCritical {
            label = "Critical"; color = Color.Theme.danger
        } else if reading.isWarning {
            label = "Warning";  color = Color.Theme.warning
        } else {
            label = "Safe";     color = Color.Theme.success
        }
        return Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    // MARK: - Battery card

    private var batteryCard: some View {
        TelemetryCard(title: "Battery", systemImage: "battery.100") {
            if let battery = viewModel.snapshot.battery {
                VStack(spacing: 14) {
                    // Icon + percentage
                    HStack(spacing: 14) {
                        Image(systemName: batterySymbol(battery))
                            .font(.system(size: 44))
                            .foregroundStyle(battery.displayColor)
                            .symbolRenderingMode(.hierarchical)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(battery.displayPercentage)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(battery.displayColor)
                                Text("%")
                                    .font(.title3)
                                    .foregroundStyle(Color.Theme.secondaryText)
                            }
                            Text(String(format: "%.2f V", battery.voltageVolts))
                                .font(.subheadline)
                                .foregroundStyle(Color.Theme.secondaryText)
                        }

                        Spacer()

                        if battery.isCharging {
                            Label("Charging", systemImage: "bolt.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.Theme.success)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.Theme.success.opacity(0.12), in: Capsule())
                        }
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.Theme.secondaryBackground)
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(battery.displayColor)
                                .frame(width: geo.size.width * battery.percentage, height: 12)
                                .animation(.easeInOut(duration: 0.4), value: battery.percentage)
                        }
                    }
                    .frame(height: 12)
                }
            } else {
                noDataView(icon: "battery.100", message: "Waiting for battery data…")
            }
        }
    }

    private func batterySymbol(_ battery: BatteryStatus) -> String {
        if battery.isCharging { return "battery.100.bolt" }
        switch battery.percentage {
        case ..<0.10: return "battery.0"
        case ..<0.30: return "battery.25"
        case ..<0.55: return "battery.50"
        case ..<0.80: return "battery.75"
        default:      return "battery.100"
        }
    }

    // MARK: - Status card (mode + position)

    private var statusCard: some View {
        TelemetryCard(title: "Robot Status", systemImage: "cpu.fill") {
            VStack(spacing: 16) {
                // Confirmed mode
                HStack {
                    Label("Mode", systemImage: "circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.Theme.secondaryText)
                    Spacer()
                    if let mode = viewModel.snapshot.mode {
                        Label(mode.mode.displayName, systemImage: mode.mode.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.Theme.robotPrimary)
                    } else {
                        Text("—").foregroundStyle(Color.Theme.tertiaryText)
                    }
                }

                Divider()

                // Position from odometry
                if let pos = viewModel.snapshot.position {
                    VStack(spacing: 10) {
                        positionRow(label: "X", value: String(format: "%.2f m", pos.xMeters))
                        positionRow(label: "Y", value: String(format: "%.2f m", pos.yMeters))
                        positionRow(label: "Heading", value: String(format: "%.1f°", pos.headingDegrees))
                    }
                } else {
                    HStack {
                        Label("Position", systemImage: "location.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.Theme.secondaryText)
                        Spacer()
                        Text("—").foregroundStyle(Color.Theme.tertiaryText)
                    }
                }
            }
        }
    }

    private func positionRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.Theme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.Theme.primaryText)
        }
    }

    // MARK: - No data placeholder

    private func noDataView(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(Color.Theme.tertiaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.Theme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Toolbar

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

// MARK: - TelemetryCard

/// Consistent card container used by each telemetry section.
private struct TelemetryCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Color.Theme.primaryText)

            content()
        }
        .padding(16)
        .background(Color.Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - ArcGaugeView

/// A 270° arc gauge. `value` is normalised 0…1.
/// The arc runs clockwise from the 7-o'clock to 5-o'clock position.
private struct ArcGaugeView<Label: View>: View {
    let value: Double       // 0.0 ... 1.0
    let color: Color
    @ViewBuilder let label: () -> Label

    /// The arc covers 3/4 of the circle (270°).
    private let arcFraction: CGFloat = 0.75
    /// Rotation so the arc starts at 7 o'clock (135° from the +x axis).
    private let startRotation: CGFloat = 135

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0, to: arcFraction)
                .stroke(
                    Color.Theme.secondaryBackground,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(startRotation))

            // Fill
            Circle()
                .trim(from: 0, to: arcFraction * CGFloat(value.clamped(to: 0...1)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(startRotation))
                .animation(.easeInOut(duration: 0.35), value: value)

            label()
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    TelemetryView(
        telemetryService: PreviewTelemetryService(),
        mqttService: PreviewMQTTServiceForTelemetry()
    )
}

private final class PreviewTelemetryService: TelemetryServiceProtocol {
    private let snapshot = TelemetrySnapshot(
        distance: DistanceReading(distanceMeters: 0.45, timestamp: Date()),
        battery:  BatteryStatus(voltageVolts: 11.4, percentage: 0.72, isCharging: false, timestamp: Date()),
        position: Position(xMeters: 1.25, yMeters: -0.30, headingRadians: 0.52, timestamp: Date()),
        mode:     ModeStatus(mode: .manual, timestamp: Date())
    )
    var distancePublisher: AnyPublisher<DistanceReading, Never> { Empty().eraseToAnyPublisher() }
    var batteryPublisher:  AnyPublisher<BatteryStatus,   Never> { Empty().eraseToAnyPublisher() }
    var positionPublisher: AnyPublisher<Position,         Never> { Empty().eraseToAnyPublisher() }
    var modePublisher:     AnyPublisher<ModeStatus,       Never> { Empty().eraseToAnyPublisher() }
    var snapshotPublisher: AnyPublisher<TelemetrySnapshot, Never> {
        Just(snapshot).eraseToAnyPublisher()
    }
    func startListening() async throws {}
    func stopListening() async {}
}

private final class PreviewMQTTServiceForTelemetry: MQTTServiceProtocol {
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        Just(.connected).eraseToAnyPublisher()
    }
    var incomingMessagesPublisher: AnyPublisher<MQTTMessage, Never> { Empty().eraseToAnyPublisher() }
    var currentState: ConnectionState { .connected }
    func connect(config: BrokerConfig) async throws {}
    func disconnect() async {}
    func publish(topic: String, payload: Data, qos: MQTTQoS, retained: Bool) async throws {}
    func subscribe(topic: String, qos: MQTTQoS) async throws {}
    func unsubscribe(topic: String) async throws {}
}
