import SwiftUI
import Foundation
import Combine
import IOKit
import IOKit.ps

import Darwin // Lay the groundwork for IOReport

// MARK: - Components

struct AppleRollingText: View {
    let text: String
    var font: Font = .system(size: 48, weight: .heavy, design: .rounded)
    var foregroundColor: Color = .white
    var lineLimit: Int? = nil
    var minimumScaleFactor: CGFloat = 1.0
    
    // Tracks the current value to compare if the number is going up or down
    @State private var previousValue: Double = 0.0
    
    // Derived state to determine if the roll should invert
    private var countsDown: Bool {
        let cleanCurrent = Double(text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) ?? 0
        return cleanCurrent < previousValue
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(foregroundColor)
            .monospacedDigit()
            // Apple Quality Lock: flips the scroll wheel physics when counting down!
            .contentTransition(.numericText(countsDown: countsDown))
            .lineLimit(lineLimit)
            .minimumScaleFactor(minimumScaleFactor)
            .fixedSize(horizontal: false, vertical: true)
            .clipped()
            .animation(.snappy(duration: 0.35, extraBounce: 0.1), value: text)
            // Silently updates our tracker background reference frame
            .onChange(of: text) { _, newValue in
                let cleanNew = Double(newValue.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) ?? 0
                previousValue = cleanNew
            }
    }
}

// MARK: - App

@available(macOS 14.0, *)
@main
struct SMC_breach: App {
    @StateObject private var powerMonitor = PowerMonitor()

    var body: some Scene {
        MenuBarExtra {
            if #available(macOS 26.0, *) {
                PowerMonitorView()
                    .environmentObject(powerMonitor)
                    .onAppear { powerMonitor.start() }
            } else {
                // Fallback on earlier versions
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: powerMonitor.menuBarIcon)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse, options: .repeating, isActive: powerMonitor.isCharging)
                AppleRollingText(
                    text: String(format: "%.1f W", powerMonitor.systemLoad),
                    font: .system(size: 14, weight: .semibold, design: .default)
                )
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Root View

@available(macOS 26.0, *)
struct PowerMonitorView: View {
    @EnvironmentObject var powerMonitor: PowerMonitor
    @State private var appeared = false
    
    // Helper struct for bar samples
    private struct BarSample {
        let height: CGFloat
        let color: Color
        let isEmpty: Bool
    }
    
    private var barSamples: [BarSample] {
        let maxBars = 12
        var values: [Double] = powerMonitor.barHistory
        
        // Add the currently forming 5-minute interval as the fluctuating right-most bar
        if !powerMonitor.currentBarSamples.isEmpty {
            let currentAvg = powerMonitor.currentBarSamples.reduce(0, +) / Double(powerMonitor.currentBarSamples.count)
            values.append(currentAvg)
        }
        
        guard !values.isEmpty else { return [] }
        
        let minSample = values.min() ?? 0
        let maxSample = values.max() ?? 1
        let range = max(maxSample - minSample, 0.01)
        let minBarHeight: CGFloat = 8
        
        let sortedIndices = values.enumerated().sorted { $0.element < $1.element }.map { $0.offset }
        let thirdCount = max(1, values.count / 3)
        
        var result: [BarSample] = []
        
        // Pad the left side with empty items until we reach an hour's worth of data
        let paddingCount = max(0, maxBars - values.count)
        for _ in 0..<paddingCount {
            result.append(BarSample(height: 0, color: .clear, isEmpty: true))
        }
        
        // Map our finalized and current actual data points
        for (i, value) in values.enumerated() {
            let normalizedHeight = CGFloat((value - minSample) / range)
            let height = max(minBarHeight, normalizedHeight * 35)
            let rank = sortedIndices.firstIndex(of: i) ?? 0
            
            let color: Color
            if rank < thirdCount {
                color = .red
            } else if rank < 2 * thirdCount {
                color = .yellow
            } else {
                color = .green
            }
            
            result.append(BarSample(height: height, color: color, isEmpty: false))
        }
        
        return result
    }
    
    @available(macOS 26.0, *)
    var body: some View {
        VStack(spacing: 24) {
            topSection
            metricsSection
            sparklineSection
            bottomActionSection
        }
        .padding(20)
        .frame(width: 340)
        .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    // 1. Crystal clear background tint (zero blur, zero frost)
                    .fill(Color.black.opacity(0.15))
                    
                    // 2. Simulated Chromatic Aberration & Splay on the extreme edges
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .cyan.opacity(0.6), location: 0.0),   // Blue dispersion splay
                                        .init(color: .orange.opacity(0.4), location: 0.2),  // Core highlight
                                        .init(color: .blue, location: 0.5),
                                        .init(color: .red.opacity(0.5), location: 1.0)     // Red dispersion splay
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5 // Sharp, crisp refractive edge
                            )
                    )
            )
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
        
        @available(macOS 26.0, *)
        private var topSection: some View {
            // 1. Changed alignment to .center for vertical centering
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(powerMonitor.isCharging ? "Charging" : (powerMonitor.isPluggedIn ? "Charging on hold" : "On Battery"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    AppleRollingText(text: "\(powerMonitor.capacity)%")
                }

                Spacer() // First spacer (between text and graph)

                // 2. Changed alignment to .center to keep the floating UI balanced
                VStack(alignment: .center, spacing: 6) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(barSamples.enumerated()), id: \.offset) { (i, bar) in
                            if bar.isEmpty {
                                Capsule()
                                    .fill(Color.clear)
                                    .frame(width: 4, height: 35)
                            } else {
                                Capsule()
                                    .fill(bar.color)
                                    .frame(width: 4, height: bar.height)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bar.height)
                            }
                        }
                    }
                    .frame(height: 35)

                    // Thin divider under the bars
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 90, height: 1)

                    HStack {
                        Text("1hr")
                            .padding(.leading, 2)
                        Spacer()
                        Text("now")
                            .padding(.trailing, 2)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 90)
                }
                
                Spacer() // Second spacer (balances the first to perfectly center horizontally)
            }
            .padding(16)
            /* .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.15)) // Subtle tint so content stays readable over light backgrounds
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.15), lineWidth: 1) // Crisp, sharp "glass" edge
                        )
                )
            */
            .glassEffect(.clear, in: .rect(cornerRadius: 16))
            
            // Control total transparency by backing it with an ultra-faint dark dimming color
            // Not needed for now - .background(.black.opacity(0.15))
            .environment(\.colorScheme, .dark)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.97)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    appeared = true
                }
            }
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
            AppleRollingText(
                text: value,
                font: .system(size: 24, weight: .bold, design: .default),
                foregroundColor: .white,
                lineLimit: 1,
                minimumScaleFactor: 0.7
            )
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
        .glassEffect(.clear, in: .rect(cornerRadius: 16))
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

// MARK: - Data Models

struct PowerMonitorData: Codable {
    var history: [Double]
    var barHistory: [Double]
    var currentBarSamples: [Double]
}

// MARK: - Power Monitor Logic

class PowerMonitor: ObservableObject {
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var batteryPower: Double = 0.0
    @Published var adapterWatts: Int = 0
    @Published var capacity: Int = 0
    @Published var systemLoad: Double = 0.0
    
    // Arrays for history visualization
    @Published var history: [Double] = [] // Full 1-second interval trend graph (Sparkline)
    @Published var barHistory: [Double] = [] // Finalized, non-moving 5-min intervals
    @Published var currentBarSamples: [Double] = [] // Current, fluctuating 5-min interval
    
    // Increase historyLimit to store 1 hour of data (4 samples/sec × 60 × 60 = 14,400 entries)
    private let historyLimit = 14400
    
    private var timer: Timer?

    // Buffers for polling
    private var batteryPowerBuffer: [Double] = []
    private var adapterWattsBuffer: [Int] = []
    private var systemLoadBuffer: [Double] = []
    private var capacityBuffer: [Int] = []
    private var isChargingBuffer: [Bool] = []
    private var isPluggedInBuffer: [Bool] = []
    private var pollCounter = 0
    
    // File URL for saving and loading history data
    private let historySaveURL: URL = {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("powerMonitorHistory.json")
    }()
    
    // Load history from disk on init
    init() {
        loadHistoryFromDisk()
    }
    
    /// Save all arrays to disk as structured JSON
    private func saveHistoryToDisk() {
        DispatchQueue.global(qos: .background).async {
            let encoder = JSONEncoder()
            let savedData = PowerMonitorData(
                history: self.history,
                barHistory: self.barHistory,
                currentBarSamples: self.currentBarSamples
            )
            
            if let data = try? encoder.encode(savedData) {
                try? data.write(to: self.historySaveURL)
            }
        }
    }
    
    /// Load history array from disk and migrate old flat arrays to chunked architecture
    private func loadHistoryFromDisk() {
        DispatchQueue.global(qos: .background).async {
            let decoder = JSONDecoder()
            guard let data = try? Data(contentsOf: self.historySaveURL) else { return }
            
            // Try loading the newly formatted struct
            if let savedData = try? decoder.decode(PowerMonitorData.self, from: data) {
                DispatchQueue.main.async {
                    self.history = savedData.history
                    self.barHistory = savedData.barHistory
                    self.currentBarSamples = savedData.currentBarSamples
                }
            }
            // Fallback for previous un-chunked history model (migration)
            else if let oldHistory = try? decoder.decode([Double].self, from: data) {
                DispatchQueue.main.async {
                    self.history = oldHistory
                    self.migrateOldHistoryToBars(oldHistory)
                }
            }
        }
    }
    
    /// Chunks up historical sliding window data cleanly into 5-minute fixed bins during migration
    private func migrateOldHistoryToBars(_ oldHistory: [Double]) {
        var chunks: [[Double]] = []
        var chunkBuffer: [Double] = []
        
        for value in oldHistory {
            chunkBuffer.append(value)
            if chunkBuffer.count >= 300 { // 300 seconds = 5 mins
                chunks.append(chunkBuffer)
                chunkBuffer = []
            }
        }
        
        self.barHistory = chunks.suffix(11).map { $0.reduce(0, +) / Double($0.count) }
        self.currentBarSamples = chunkBuffer
    }
    
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
        
        // ISTG - IOkit implementation SUCKSS, this updates too SLOW, with the next commit or pretty soon, I'm replacing this with the private IOReport framework :)
                
        // 1. Initial data fetch to populate the UI immediately
        pollAndBufferStats()
            
        // 2. Register for instant Kernel-level Power Notifications
        // This fires exactly when the OS registers a power change (plugged in, unplugged, % drop)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let loopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let ctx = context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                // Instantly update when the system broadcasts a hardware change
                monitor.pollAndBufferStats()
            }
        }, context).takeRetainedValue()
        
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)
                
        // 3. Maintain a slower 1-second timer strictly for the continuous Sparkline graph movement
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollAndBufferStats()
        }
    }

    @objc private func pollAndBufferStats() {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            guard service != 0 else { return }
            defer { IOObjectRelease(service) }

            var prop: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &prop, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                  let dict = prop?.takeUnretainedValue() as? [String: Any] else {
                return
            }

            // --- CORE STATE ---
            let isChargingVal = dict["IsCharging"] as? Bool ?? false
            let isPluggedInVal = dict["ExternalConnected"] as? Bool ?? false
            
            // --- THE 0% BUG FIX: CASCADING FALLBACKS ---
            // Dynamically probe the hardware for raw values, degrading gracefully to standard keys if on newer Apple Silicon
            let rawCurrent = (dict["AppleRawCurrentCapacity"] as? NSNumber)?.doubleValue ??
                             (dict["CurrentCapacity"] as? NSNumber)?.doubleValue ?? 0.0
            
            let rawMax = (dict["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue ??
                         (dict["NominalChargeCapacity"] as? NSNumber)?.doubleValue ??
                         (dict["MaxCapacity"] as? NSNumber)?.doubleValue ?? 1.0
            
            let trueCapacityPercentage = Int((rawCurrent / rawMax) * 100.0)

            // --- POWER MATH ---
            let rawAmps = (dict["InstantAmperage"] as? NSNumber)?.doubleValue ?? 0.0
            let volts = (dict["Voltage"] as? NSNumber)?.doubleValue ?? 0.0
            let calcPower = (rawAmps * volts) / 1_000_000.0
            
            let batteryPowerVal: Double
            if isChargingVal {
                batteryPowerVal = abs(calcPower)
            } else if rawAmps < 0 {
                batteryPowerVal = -abs(calcPower)
            } else {
                batteryPowerVal = 0.0
            }
            
            let adapterWattsVal: Int
            if let rawAdapterDetails = dict["AppleRawAdapterDetails"] as? [String: Any] {
                adapterWattsVal = (rawAdapterDetails["Watts"] as? NSNumber)?.intValue ?? 0
            } else if let adapterDetails = dict["AdapterDetails"] as? [String: Any] {
                adapterWattsVal = (adapterDetails["Watts"] as? NSNumber)?.intValue ?? 0
            } else {
                adapterWattsVal = 0
            }
            
            var systemLoadVal: Double = 0.0
            if let telemetry = dict["PowerTelemetryData"] as? [String: Any],
               let sysLoad = (telemetry["SystemLoad"] as? NSNumber)?.doubleValue {
                systemLoadVal = sysLoad / 1000.0
            }

            // --- BUFFER & UI UPDATE ---
            DispatchQueue.main.async {
                self.isChargingBuffer.append(isChargingVal)
                self.isPluggedInBuffer.append(isPluggedInVal)
                self.capacityBuffer.append(trueCapacityPercentage)
                self.batteryPowerBuffer.append(batteryPowerVal)
                self.adapterWattsBuffer.append(adapterWattsVal)
                self.systemLoadBuffer.append(systemLoadVal)
                self.pollCounter += 1

                // We lowered the buffer requirement slightly so the UI feels snappier when responding to Kernel events
                if self.pollCounter >= 2 {
                    let avgIsCharging = self.isChargingBuffer.filter { $0 }.count >= 1
                    let avgIsPluggedIn = self.isPluggedInBuffer.filter { $0 }.count >= 1
                    let avgCapacity = Int(Double(self.capacityBuffer.reduce(0,+)) / Double(self.capacityBuffer.count))
                    let avgBatteryPower = self.batteryPowerBuffer.reduce(0,+) / Double(self.batteryPowerBuffer.count)
                    let avgAdapterWatts = Int(Double(self.adapterWattsBuffer.reduce(0,+)) / Double(self.adapterWattsBuffer.count))
                    let avgSystemLoad = self.systemLoadBuffer.reduce(0,+) / Double(self.systemLoadBuffer.count)

                    self.isCharging = avgIsCharging
                    self.isPluggedIn = avgIsPluggedIn
                    self.capacity = avgCapacity
                    self.batteryPower = avgBatteryPower
                    self.adapterWatts = avgAdapterWatts
                    self.systemLoad = avgSystemLoad
                    
                    // Update graph arrays
                    self.history.append(avgSystemLoad)
                    if self.history.count > self.historyLimit {
                        self.history.removeFirst(self.history.count - self.historyLimit)
                    }
                    
                    self.currentBarSamples.append(avgSystemLoad)
                    if self.currentBarSamples.count >= 300 {
                        let finalizedAverage = self.currentBarSamples.reduce(0, +) / Double(self.currentBarSamples.count)
                        self.barHistory.append(finalizedAverage)
                        self.currentBarSamples.removeAll()
                        
                        if self.barHistory.count > 11 {
                            self.barHistory.removeFirst(self.barHistory.count - 11)
                        }
                    }
                    
                    self.saveHistoryToDisk()

                    self.isChargingBuffer.removeAll()
                    self.isPluggedInBuffer.removeAll()
                    self.capacityBuffer.removeAll()
                    self.batteryPowerBuffer.removeAll()
                    self.adapterWattsBuffer.removeAll()
                    self.systemLoadBuffer.removeAll()
                    self.pollCounter = 0
                }
            }
        }
}
