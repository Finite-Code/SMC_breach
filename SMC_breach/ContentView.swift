import SwiftUI
import Foundation
import Combine
import IOKit

// MARK: - App

@available(macOS 14.0, *)
@main
struct SMC_breach: App {
    @StateObject private var powerMonitor = PowerMonitor()

    var body: some Scene {
        MenuBarExtra {
            PowerMonitorView()
                .environmentObject(powerMonitor)
                .onAppear { powerMonitor.start() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: powerMonitor.menuBarIcon)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse, options: .repeating, isActive: powerMonitor.isCharging)
                Text("\(powerMonitor.capacity)%")
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Root View

@available(macOS 14.0, *)
struct PowerMonitorView: View {
    @EnvironmentObject var powerMonitor: PowerMonitor
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            statusPills
            metricsRow
            sparklineSection
        }
        .padding(18)
        .frame(width: 300)
        .background(backgroundGlow)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.97)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: Header — animated ring gauge

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 7)

                RingShape(progress: min(max(Double(powerMonitor.capacity) / 100.0, 0), 1))
                    .stroke(ringGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: powerMonitor.capacity)
                    .shadow(color: ringGlowColor.opacity(0.5), radius: 6)

                VStack(spacing: 1) {
                    if powerMonitor.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.yellow)
                            .symbolEffect(.pulse, options: .repeating, isActive: true)
                    }
                    Text("\(powerMonitor.capacity)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("percent")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
            .frame(width: 74, height: 74)
            .animation(.easeInOut(duration: 0.3), value: powerMonitor.isCharging)

            VStack(alignment: .leading, spacing: 3) {
                Text("Battery")
                    .font(.system(.title3, design: .rounded).weight(.semibold))

                Text(statusText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: statusText)
            }

            Spacer(minLength: 0)
        }
    }

    private var statusText: String {
        if powerMonitor.isCharging {
            return "Charging • \(powerMonitor.adapterWatts)W"
        } else if powerMonitor.isPluggedIn {
            return "Plugged In"
        } else {
            return "On Battery"
        }
    }

    private var ringGradient: AngularGradient {
        let colors: [Color] = powerMonitor.isCharging
            ? [.green, .mint, .green]
            : [.blue, .cyan, .blue]
        return AngularGradient(colors: colors, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
    }

    private var ringGlowColor: Color {
        powerMonitor.isCharging ? .green : .blue
    }

    // MARK: Status pills

    private var statusPills: some View {
        HStack(spacing: 8) {
            statusPill(
                icon: powerMonitor.isPluggedIn ? "powerplug.fill" : "powerplug",
                text: powerMonitor.isPluggedIn ? "Plugged In" : "Unplugged",
                tint: powerMonitor.isPluggedIn ? .green : .secondary
            )
            statusPill(
                icon: powerMonitor.isCharging ? "bolt.fill" : "bolt.slash",
                text: powerMonitor.isCharging ? "Charging" : "Idle",
                tint: powerMonitor.isCharging ? .yellow : .secondary
            )
            Spacer(minLength: 0)
        }
    }

    private func statusPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
            Text(text)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.14))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: text)
    }

    // MARK: Metric cards

    private var metricsRow: some View {
        HStack(spacing: 10) {
            metricCard(
                title: "Battery",
                value: String(format: "%+.1fW", powerMonitor.batteryPower),
                icon: powerMonitor.batteryPower >= 0 ? "bolt.fill" : "bolt.slash.fill",
                tint: powerMonitor.batteryPower >= 0 ? .green : .orange
            )
            metricCard(
                title: "Adapter",
                value: "\(powerMonitor.adapterWatts)W",
                icon: "powerplug.fill",
                tint: .blue
            )
            metricCard(
                title: "System",
                value: String(format: "%.1fW", powerMonitor.systemLoad),
                icon: "cpu",
                tint: .purple
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)

            Text(value)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(cornerRadius: 14)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: value)
    }

    // MARK: Sparkline

    private var sparklineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Power Trend")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1fW", powerMonitor.history.last ?? 0))
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            ZStack {
                SparklineArea(points: powerMonitor.history)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                SparklinePath(points: powerMonitor.history)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 42)
            .animation(.easeOut(duration: 0.35), value: powerMonitor.history)
        }
        .padding(12)
        .glassCard(cornerRadius: 14)
    }

    private var backgroundGlow: some View {
        RadialGradient(
            colors: [
                (powerMonitor.isCharging ? Color.green : Color.blue).opacity(0.10),
                .clear
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: 260
        )
        .animation(.easeInOut(duration: 0.4), value: powerMonitor.isCharging)
    }
}

// MARK: - Glass card style (Material-based; safe on any Xcode/macOS version)

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Shapes

struct RingShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * progress),
            clockwise: false
        )
        return path
    }
}

struct SparklinePath: Shape {
    var points: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let maxV = points.max() ?? 1
        let minV = points.min() ?? 0
        let range = max(maxV - minV, 0.5)
        let stepX = rect.width / CGFloat(points.count - 1)

        for (i, v) in points.enumerated() {
            let x = CGFloat(i) * stepX
            let y = rect.height - CGFloat((v - minV) / range) * rect.height
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

struct SparklineArea: Shape {
    var points: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let maxV = points.max() ?? 1
        let minV = points.min() ?? 0
        let range = max(maxV - minV, 0.5)
        let stepX = rect.width / CGFloat(points.count - 1)

        path.move(to: CGPoint(x: 0, y: rect.height))
        for (i, v) in points.enumerated() {
            let x = CGFloat(i) * stepX
            let y = rect.height - CGFloat((v - minV) / range) * rect.height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Power Monitor

class PowerMonitor: ObservableObject {
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var batteryPower: Double = 0.0
    @Published var adapterWatts: Int = 0
    @Published var capacity: Int = 0
    @Published var systemLoad: Double = 0.0
    @Published var history: [Double] = []

    private let historyLimit = 40
    private var timer: Timer?

    var menuBarIcon: String {
        if isCharging { return "battery.100.bolt" }
        switch capacity {
        case 90...100: return "battery.100"
        case 65..<90: return "battery.75"
        case 40..<65: return "battery.50"
        case 15..<40: return "battery.25"
        default: return "battery.0"
        }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
        updateStats()
    }

    private func updateStats() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var prop: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &prop, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let dict = prop?.takeUnretainedValue() as? [String: Any] else {
            return
        }

        DispatchQueue.main.async {
            self.isCharging = dict["IsCharging"] as? Bool ?? false
            self.isPluggedIn = dict["ExternalConnected"] as? Bool ?? false
            self.capacity = (dict["CurrentCapacity"] as? NSNumber)?.intValue ?? 0

            let rawAmps = (dict["InstantAmperage"] as? NSNumber)?.doubleValue ?? 0.0
            let volts = (dict["Voltage"] as? NSNumber)?.doubleValue ?? 0.0
            let calcPower = (rawAmps * volts) / 1_000_000.0

            if self.isCharging {
                self.batteryPower = abs(calcPower)
            } else if rawAmps < 0 {
                self.batteryPower = -abs(calcPower)
            } else {
                self.batteryPower = 0.0
            }

            if let adapterDetails = dict["AdapterDetails"] as? [String: Any] {
                self.adapterWatts = (adapterDetails["Watts"] as? NSNumber)?.intValue ?? 0
            } else if let rawAdapterDetails = dict["AppleRawAdapterDetails"] as? [String: Any] {
                self.adapterWatts = (rawAdapterDetails["Watts"] as? NSNumber)?.intValue ?? 0
            } else {
                self.adapterWatts = 0
            }

            if let telemetry = dict["PowerTelemetryData"] as? [String: Any],
               let sysLoad = (telemetry["SystemLoad"] as? NSNumber)?.doubleValue {
                self.systemLoad = sysLoad / 1000.0
            }

            self.history.append(self.systemLoad)
            if self.history.count > self.historyLimit {
                self.history.removeFirst(self.history.count - self.historyLimit)
            }
        }
    }
}
