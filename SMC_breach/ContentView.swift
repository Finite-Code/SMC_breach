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
        VStack(spacing: 24) {
            topSection
            metricsSection
            sparklineSection
            bottomActionSection
        }
        .padding(20)
        .frame(width: 340)
        // Global glass background matching the image
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.2)) // Slight darkening tint
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        // Force dark mode to ensure the text and materials match the reference image
        .environment(\.colorScheme, .dark)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.97)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: Header — Status & Bar Chart

    private var topSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(powerMonitor.isCharging ? "Charging" : (powerMonitor.isPluggedIn ? "Charging on hold" : "On Battery"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(powerMonitor.capacity)%")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Spacer()

            // Mock Bar Chart matching the image's layout
            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .bottom, spacing: 4) {
                    // Simulating historic bar data
                    ForEach(0..<12, id: \.self) { i in
                        Capsule()
                            .fill(i > 7 ? Color.green : Color.yellow)
                            .frame(width: 4, height: CGFloat.random(in: 10...35))
                    }
                }
                .frame(height: 35)

                // Thin divider under the bars, matching the reference image
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 90, height: 1)

                HStack {
                    Text("1hr")
                    Spacer()
                    Text("now")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 90)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: 3-Column Metrics Row

    private var metricsSection: some View {
        HStack {
            metricColumn(title: "Battery", value: String(format: "%.0fW", powerMonitor.batteryPower))
            Spacer()
            metricColumn(title: "Power Adapter", value: String(format: "%.1f W", Double(powerMonitor.adapterWatts)))
            Spacer()
            metricColumn(title: "System Total", value: String(format: "%.1f W", powerMonitor.systemLoad))
        }
        .padding(.horizontal, 8)
    }

    private func metricColumn(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: Sparkline Card

    private var sparklineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Power Trend")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.1fW", powerMonitor.history.last ?? 0))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .monospacedDigit()
            }

            ZStack {
                SparklineArea(points: powerMonitor.history)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                SparklinePath(points: powerMonitor.history)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 40)
            .animation(.easeOut(duration: 0.35), value: powerMonitor.history)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.95)) // Solid white frosted look from the image
        )
    }

    // MARK: Bottom Actions

    private var bottomActionSection: some View {
        HStack(spacing: 10) {
            // Grouped segmented pill: "Charge to 100%" | "Charge Now"
            HStack(spacing: 0) {
                Button(action: { /* Charge to 100% Action */ }) {
                    Text("Charge to 100%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 1, height: 16)

                Button(action: { /* Charge Now Action */ }) {
                    Text("Charge Now")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.white)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))

            Spacer()

            // Circular icon buttons matching the reference image's stroked circles
            circleIconButton(systemName: "chevron.left.forwardslash.chevron.right") {
                // Open Github action
            }

            circleIconButton(systemName: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func circleIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
        .background(Circle().fill(Color.white.opacity(0.08)))
        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Shapes

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

// MARK: - Power Monitor Logic

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
