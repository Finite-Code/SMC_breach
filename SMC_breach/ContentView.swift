import SwiftUI
import Foundation
import Combine
import IOKit

@available(macOS 13.0, *)
@main
struct SMC_breach: App {
    @StateObject private var powerMonitor = PowerMonitor()

    var body: some Scene {
        MenuBarExtra("SMC_breach", systemImage: "battery.100.bolt") {
            PowerMonitorView()
                .environmentObject(powerMonitor)
                .padding()
                .frame(minWidth: 250)
                .onAppear {
                    powerMonitor.start()
                }
        }
    }
}

struct PowerMonitorView: View {
    @EnvironmentObject var powerMonitor: PowerMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                Text("Battery Status")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                HStack {
                    Image(systemName: powerMonitor.isCharging ? "battery.100.bolt" : "battery.100")
                        .foregroundColor(powerMonitor.isCharging ? .green : .secondary)
                    Text(powerMonitor.isCharging ? "Charging" : "Not Charging")
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: powerMonitor.isPluggedIn ? "powerplug.fill" : "powerplug")
                        .foregroundColor(powerMonitor.isPluggedIn ? .green : .secondary)
                    Text(powerMonitor.isPluggedIn ? "Plugged In" : "Unplugged")
                        .font(.subheadline)
                }
            }
            
            Divider()
            
            Group {
                Text("Power Details")
                    .font(.headline)
                    .padding(.bottom, 4)

                HStack {
                    Image(systemName: powerMonitor.batteryPower >= 0 ? "bolt.fill" : "bolt.slash.fill")
                        .foregroundColor(powerMonitor.batteryPower >= 0 ? .green : .red)
                    Text("Battery Power: ")
                        .fontWeight(.semibold)
                    Text(String(format: "%+.2f W", powerMonitor.batteryPower))
                        .monospacedDigit()
                }

                HStack {
                    Image(systemName: "plug.fill")
                        .foregroundColor(powerMonitor.adapterWatts > 0 ? .green : .secondary)
                    Text("Adapter Wattage: ")
                        .fontWeight(.semibold)
                    Text("\(powerMonitor.adapterWatts) W")
                        .monospacedDigit()
                }

                HStack {
                    Image(systemName: "battery.100")
                        .foregroundColor(.blue)
                    Text("Capacity: ")
                        .fontWeight(.semibold)
                    Text("\(powerMonitor.capacity)%")
                        .monospacedDigit()
                }
            }
            
            Divider()
            
            Group {
                Text("System Load")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.orange)
                    Text("Hardware Load: ")
                        .fontWeight(.semibold)
                    Text(String(format: "%.2f W", powerMonitor.systemLoad))
                        .monospacedDigit()
                }
            }
        }
    }
    
    private func formatUptime(_ uptime: Double) -> String {
        let totalSeconds = Int(uptime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
    }
}


class PowerMonitor: ObservableObject {
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var batteryPower: Double = 0.0
    @Published var adapterWatts: Int = 0
    @Published var capacity: Int = 0
    @Published var systemLoad: Double = 0.0
    
    private var timer: Timer?
    
    func start() {
        // Corrected: Call updateStats() on every tick instead of setting uptime
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
            // 1. Fixed Keys
            self.isCharging = dict["IsCharging"] as? Bool ?? false
            self.isPluggedIn = dict["ExternalConnected"] as? Bool ?? false
            
            // 2. Fixed Type Casting using NSNumber
            self.capacity = (dict["CurrentCapacity"] as? NSNumber)?.intValue ?? 0
            
            let rnAmps = (dict["InstantAmperage"] as? NSNumber)?.doubleValue ?? 0.0
            let volts = (dict["Voltage"] as? NSNumber)?.doubleValue ?? 0.0
            
            let calcPower = (rnAmps * volts) / 1_000_000.0
            
            if self.isCharging {
                self.batteryPower = abs(calcPower)
            } else if rnAmps < 0 {
                self.batteryPower = -abs(calcPower)
            } else {
                self.batteryPower = 0.0
            }
            
            // 3. Fixed AppleRawAdapterDetails string key
            if let adapterDetails = dict["AdapterDetails"] as? [String: Any] {
                self.adapterWatts = (adapterDetails["Watts"] as? NSNumber)?.intValue ?? 0
            } else if let rawAdapterDetails = dict["AppleRawAdapterDetails"] as? [String: Any] {
                self.adapterWatts = (rawAdapterDetails["Watts"] as? NSNumber)?.intValue ?? 0
            } else {
                self.adapterWatts = 0
            }
            
            // 4. Extracting actual System Load (Hardware Logic Board Power)
            if let telemetry = dict["PowerTelemetryData"] as? [String: Any],
               let sysLoad = (telemetry["SystemLoad"] as? NSNumber)?.doubleValue {
                self.systemLoad = sysLoad / 1000.0 // Convert milliwatts to watts
            }
        }
    }
}
