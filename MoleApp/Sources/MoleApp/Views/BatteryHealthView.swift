import SwiftUI
import IOKit.ps

struct BatteryHealthView: View {
    @State private var info: BatteryInfo?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "battery.100.bolt", title: "Battery Health", iconColor: MacMartinColors.success) {
                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            if loading {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Reading battery data...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if let error {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "powerplug")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No Battery Found")
                        .font(.title3.bold())
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if let info {
                ScrollView {
                    VStack(spacing: 16) {
                        mainGauge(info)
                        detailCards(info)
                        healthTips(info)
                    }
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { refresh() }
    }

    // MARK: - Main Gauge

    private func mainGauge(_ info: BatteryInfo) -> some View {
        HStack(spacing: 30) {
            // Charge level ring
            RingGauge(
                value: info.chargePercent / 100,
                size: 130,
                lineWidth: 12,
                color: chargeColor(info.chargePercent),
                label: "\(Int(info.chargePercent))%",
                sublabel: info.isCharging ? "Charging" : "Battery"
            )

            // Health ring
            RingGauge(
                value: info.healthPercent / 100,
                size: 130,
                lineWidth: 12,
                color: healthColor(info.healthPercent),
                label: "\(Int(info.healthPercent))%",
                sublabel: "Health"
            )

            // Status info
            VStack(alignment: .leading, spacing: 12) {
                statusRow(icon: "bolt.fill", label: "Status", value: info.isCharging ? "Charging" : "On Battery", color: info.isCharging ? .green : .orange)

                if let timeLeft = info.timeRemaining {
                    statusRow(icon: "clock", label: info.isCharging ? "Until Full" : "Remaining", value: timeLeft, color: .secondary)
                }

                statusRow(icon: "thermometer.medium", label: "Temperature", value: String(format: "%.1f\u{00B0}C", info.temperature), color: info.temperature > 35 ? .red : .secondary)

                statusRow(icon: "arrow.2.circlepath", label: "Cycles", value: "\(info.cycleCount)", color: info.cycleCount > 800 ? .orange : .secondary)

                statusRow(icon: "calendar", label: "Condition", value: info.condition, color: conditionColor(info.condition))
            }
        }
        .cardStyle()
    }

    private func statusRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .medium))
        }
    }

    // MARK: - Detail Cards

    private func detailCards(_ info: BatteryInfo) -> some View {
        HStack(spacing: 12) {
            detailCard(
                icon: "bolt.batteryblock",
                title: "Design Capacity",
                value: "\(info.designCapacity) mAh",
                color: .blue
            )
            detailCard(
                icon: "battery.75percent",
                title: "Current Max",
                value: "\(info.maxCapacity) mAh",
                color: info.healthPercent > 80 ? .green : .orange
            )
            detailCard(
                icon: "minus.plus.batteryblock",
                title: "Cycle Count",
                value: "\(info.cycleCount) / 1000",
                color: info.cycleCount > 800 ? .orange : .green
            )
            detailCard(
                icon: "power.circle",
                title: "Voltage",
                value: String(format: "%.2f V", info.voltage),
                color: .purple
            )
        }
    }

    private func detailCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle(padding: 10)
    }

    // MARK: - Health Tips

    private func healthTips(_ info: BatteryInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Battery Tips")
                .font(.subheadline.bold())

            if info.healthPercent < 80 {
                tipRow(icon: "exclamationmark.triangle", text: "Battery health is below 80%. Consider a replacement.", color: .orange)
            }
            if info.cycleCount > 800 {
                tipRow(icon: "arrow.2.circlepath", text: "High cycle count (\(info.cycleCount)). Battery is aging.", color: .orange)
            }
            if info.temperature > 35 {
                tipRow(icon: "thermometer.sun", text: "Battery is warm. Avoid heavy usage while charging.", color: .red)
            }
            if info.healthPercent >= 80 && info.cycleCount <= 800 {
                tipRow(icon: "checkmark.seal", text: "Battery is in good condition. Keep it between 20-80% for longevity.", color: MacMartinColors.success)
            }
            tipRow(icon: "lightbulb", text: "Avoid extreme temperatures and keep macOS updated for best battery life.", color: .yellow)
        }
        .cardStyle()
    }

    private func tipRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16, alignment: .top)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Colors

    private func chargeColor(_ pct: Double) -> Color {
        pct > 50 ? .green : pct > 20 ? .orange : .red
    }

    private func healthColor(_ pct: Double) -> Color {
        pct > 80 ? .green : pct > 50 ? .orange : .red
    }

    private func conditionColor(_ condition: String) -> Color {
        switch condition {
        case "Normal": return MacMartinColors.success
        case "Replace Soon": return .orange
        case "Replace Now", "Service Battery": return .red
        default: return .secondary
        }
    }

    // MARK: - Data Loading

    private func refresh() {
        loading = true
        error = nil
        Task.detached(priority: .userInitiated) {
            let result = Self.readBattery()
            await MainActor.run {
                switch result {
                case .success(let info):
                    self.info = info
                    self.error = nil
                case .failure(let err):
                    self.error = err.localizedDescription
                }
                loading = false
            }
        }
    }

    private static func readBattery() -> Result<BatteryInfo, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-c", "AppleSmartBattery", "-w0"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(error)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            return .failure(NSError(domain: "BatteryHealth", code: 1, userInfo: [NSLocalizedDescriptionKey: "This Mac may not have a battery."]))
        }

        func extract(_ key: String) -> String? {
            let pattern = "\"\(key)\"\\s*=\\s*(.+)"
            guard let range = output.range(of: pattern, options: .regularExpression) else { return nil }
            let match = String(output[range])
            guard let eqRange = match.range(of: "= ") else { return nil }
            return String(match[eqRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let designCap = Int(extract("DesignCapacity") ?? "") ?? 0
        let maxCap = Int(extract("MaxCapacity") ?? "") ?? 0
        let currentCap = Int(extract("CurrentCapacity") ?? "") ?? 0
        let cycleCount = Int(extract("CycleCount") ?? "") ?? 0
        let isCharging = extract("IsCharging") == "Yes"
        let voltage = Double(extract("Voltage") ?? "0") ?? 0
        let temperature = Double(extract("Temperature") ?? "0") ?? 0

        // Temperature is in centidegrees
        let tempC = temperature / 100.0

        let healthPct = designCap > 0 ? (Double(maxCap) / Double(designCap)) * 100 : 100
        let chargePct = maxCap > 0 ? (Double(currentCap) / Double(maxCap)) * 100 : 0

        let timeToEmpty = Int(extract("AvgTimeToEmpty") ?? "0") ?? 0
        let timeToFull = Int(extract("TimeToFullCharge") ?? "0") ?? 0
        let timeVal = isCharging ? timeToFull : timeToEmpty
        let timeStr: String? = (timeVal > 0 && timeVal < 6000)
            ? "\(timeVal / 60)h \(timeVal % 60)m"
            : nil

        // Condition
        let condition: String
        if healthPct > 80 {
            condition = "Normal"
        } else if healthPct > 60 {
            condition = "Replace Soon"
        } else {
            condition = "Service Battery"
        }

        let info = BatteryInfo(
            chargePercent: min(chargePct, 100),
            healthPercent: min(healthPct, 100),
            isCharging: isCharging,
            cycleCount: cycleCount,
            designCapacity: designCap,
            maxCapacity: maxCap,
            currentCapacity: currentCap,
            voltage: voltage / 1000.0,
            temperature: tempC,
            condition: condition,
            timeRemaining: timeStr
        )

        return .success(info)
    }
}

// MARK: - Model

struct BatteryInfo {
    let chargePercent: Double
    let healthPercent: Double
    let isCharging: Bool
    let cycleCount: Int
    let designCapacity: Int
    let maxCapacity: Int
    let currentCapacity: Int
    let voltage: Double
    let temperature: Double
    let condition: String
    let timeRemaining: String?
}
