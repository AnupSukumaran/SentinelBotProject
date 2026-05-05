//
//  TelemetryView.swift
//  SentinelBot
//
//  Displays live sensor data from the robot:
//    • Distance card  — 270° arc gauge, 0–400 cm, colour-coded by proximity
//    • Battery card   — progress bar, percentage, voltage, charging indicator
//    • Status card    — confirmed robot mode + odometry position
//    • Map card       — Canvas-based odometry trail with heading indicator
//
//  A full-width alert banner slides in at the top whenever a critical
//  distance or battery threshold is crossed.
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
                positionMapCard
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Distance \(Int(reading.distanceCM)) centimetres")
                    .accessibilityValue(reading.isCritical ? "Critical" : reading.isWarning ? "Warning" : "Safe")

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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Battery level")
                    .accessibilityValue("\(battery.displayPercentage) percent\(battery.isCharging ? ", charging" : "")")
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

    // MARK: - Position map card

    private var positionMapCard: some View {
        TelemetryCard(title: "Position Track", systemImage: "location.north.fill") {
            if viewModel.positionHistory.isEmpty {
                noDataView(icon: "location.slash.fill", message: "Waiting for position data…")
            } else {
                PositionMapView(history: viewModel.positionHistory)
                    .accessibilityLabel("Robot odometry map")
                    .accessibilityHint("Shows the path the robot has travelled since launch")
            }
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

private struct ArcGaugeView<Label: View>: View {
    let value: Double
    let color: Color
    @ViewBuilder let label: () -> Label

    private let arcFraction: CGFloat = 0.75
    private let startRotation: CGFloat = 135

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: arcFraction)
                .stroke(Color.Theme.secondaryBackground, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(startRotation))
            Circle()
                .trim(from: 0, to: arcFraction * CGFloat(value.clamped(to: 0...1)))
                .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
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

// MARK: - PositionMapView

/// Canvas-based odometry trail. Draws a 1 m grid, the robot's position
/// history as a line, and the current position as a filled circle with a
/// heading indicator. Auto-scales to fit all recorded positions.
private struct PositionMapView: View {
    let history: [Position]

    var body: some View {
        Canvas { context, size in
            let t = MapTransform.fitting(positions: history, in: size)

            // 1 m grid
            var gridPath = Path()
            for i in -20...20 {
                let d = Double(i)
                gridPath.move(to: t.pt(d, -30)); gridPath.addLine(to: t.pt(d, 30))
                gridPath.move(to: t.pt(-30, d)); gridPath.addLine(to: t.pt(30, d))
            }
            context.stroke(gridPath, with: .color(.primary.opacity(0.05)), lineWidth: 0.5)

            // Axis lines
            var axisPath = Path()
            axisPath.move(to: t.pt(-30, 0)); axisPath.addLine(to: t.pt(30, 0))
            axisPath.move(to: t.pt(0, -30)); axisPath.addLine(to: t.pt(0, 30))
            context.stroke(axisPath, with: .color(.primary.opacity(0.12)), lineWidth: 1)

            // Origin dot
            let origin = t.pt(0, 0)
            context.fill(
                Path(ellipseIn: CGRect(x: origin.x - 3, y: origin.y - 3, width: 6, height: 6)),
                with: .color(.secondary.opacity(0.5))
            )

            // Trail
            if history.count >= 2 {
                var trail = Path()
                trail.move(to: t.pt(history[0].xMeters, history[0].yMeters))
                for pos in history.dropFirst() {
                    trail.addLine(to: t.pt(pos.xMeters, pos.yMeters))
                }
                context.stroke(trail, with: .color(Color.Theme.robotPrimary.opacity(0.55)), lineWidth: 2)
            }

            // Robot body + heading
            if let current = history.last {
                let pt = t.pt(current.xMeters, current.yMeters)
                let r: CGFloat = 8
                context.fill(
                    Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                    with: .color(Color.Theme.robotPrimary)
                )
                // Heading line: heading=0 faces +x; canvas flips y so sin is negated
                let angle = current.headingRadians
                let len: CGFloat = 18
                var headPath = Path()
                headPath.move(to: pt)
                headPath.addLine(to: CGPoint(
                    x: pt.x + cos(angle) * len,
                    y: pt.y - sin(angle) * len
                ))
                context.stroke(headPath, with: .color(.white),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - MapTransform

/// Converts world coordinates (metres, +y = North) to Canvas coordinates
/// (+y = down). Auto-fits all positions with padding.
private struct MapTransform {
    let ox: CGFloat     // canvas x at world (0, 0)
    let oy: CGFloat     // canvas y at world (0, 0)
    let scale: CGFloat  // pixels per metre

    func pt(_ worldX: Double, _ worldY: Double) -> CGPoint {
        CGPoint(x: ox + CGFloat(worldX) * scale,
                y: oy - CGFloat(worldY) * scale)
    }

    static func fitting(positions: [Position], in size: CGSize, padding: CGFloat = 28) -> MapTransform {
        let pts = positions.isEmpty
            ? [Position(xMeters: -1, yMeters: -1, headingRadians: 0, timestamp: Date()),
               Position(xMeters:  1, yMeters:  1, headingRadians: 0, timestamp: Date())]
            : positions

        let xs    = pts.map(\.xMeters)
        let ys    = pts.map(\.yMeters)
        let spanX = max(xs.max()! - xs.min()!, 2.0)
        let spanY = max(ys.max()! - ys.min()!, 2.0)
        let midX  = (xs.max()! + xs.min()!) / 2
        let midY  = (ys.max()! + ys.min()!) / 2

        let drawW  = Double(size.width  - padding * 2)
        let drawH  = Double(size.height - padding * 2)
        let scale  = CGFloat(min(drawW / spanX, drawH / spanY))

        return MapTransform(
            ox: size.width  / 2 - CGFloat(midX) * scale,
            oy: size.height / 2 + CGFloat(midY) * scale,
            scale: scale
        )
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
