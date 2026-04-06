import Foundation
import SwiftUI
import UserNotifications

// MARK: - Models

struct SystemAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let message: String
    let timestamp: Date
    var dismissed: Bool = false
}

enum AlertType: String, Codable {
    case disk, memory, cpu, battery

    var icon: String {
        switch self {
        case .disk: return "internaldrive.fill"
        case .memory: return "memorychip.fill"
        case .cpu: return "cpu"
        case .battery: return "battery.25percent"
        }
    }

    var color: Color {
        switch self {
        case .disk: return MacMartinColors.danger
        case .memory: return MacMartinColors.warning
        case .cpu: return Color(red: 1.0, green: 0.45, blue: 0.30)
        case .battery: return Color(red: 0.95, green: 0.60, blue: 0.20)
        }
    }
}

struct AlertSettings: Codable {
    var diskThreshold: Double = 90
    var memoryThreshold: Double = 85
    var cpuThreshold: Double = 90
    var alertsEnabled: Bool = true
}

// MARK: - Alert Manager

@MainActor
class AlertManager: ObservableObject {
    @Published var alerts: [SystemAlert] = []
    @Published var settings: AlertSettings {
        didSet { saveSettings() }
    }

    private weak var monitor: MenuBarMonitor?
    private var timer: Timer?

    /// Tracks consecutive high-CPU poll results for sustained-CPU alerting.
    private var highCPUStreak: Int = 0

    /// Cooldowns: avoid re-firing the same alert type within 5 minutes.
    private var lastAlertTime: [AlertType: Date] = [:]
    private let cooldown: TimeInterval = 300

    // MARK: - Lifecycle

    init() {
        self.settings = Self.loadSettings()
        requestNotificationPermission()
    }

    deinit {
        timer?.invalidate()
    }

    /// Call once after the monitor is available (e.g. from onAppear).
    func start(monitor: MenuBarMonitor) {
        guard self.monitor == nil else { return }
        self.monitor = monitor
        // Perform an initial check, then poll every 30 seconds.
        checkThresholds()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkThresholds() }
        }
    }

    // MARK: - Threshold Checks

    private func checkThresholds() {
        guard settings.alertsEnabled, let monitor else { return }

        // Disk
        if monitor.diskPercent >= settings.diskThreshold {
            fireIfCooled(.disk, message: "Disk usage is at \(Int(monitor.diskPercent))% — only \(monitor.diskFree) free.")
        }

        // Memory
        if monitor.memoryPercent >= settings.memoryThreshold {
            let usedGB = String(format: "%.1f", monitor.memoryUsed)
            let totalGB = String(format: "%.1f", monitor.memoryTotal)
            fireIfCooled(.memory, message: "Memory pressure is high: \(usedGB) / \(totalGB) GB (\(Int(monitor.memoryPercent))%).")
        }

        // CPU — sustained (3+ consecutive checks above threshold)
        if monitor.cpuUsage >= settings.cpuThreshold {
            highCPUStreak += 1
        } else {
            highCPUStreak = 0
        }
        if highCPUStreak >= 3 {
            fireIfCooled(.cpu, message: "CPU has been above \(Int(settings.cpuThreshold))% for over 90 seconds (\(Int(monitor.cpuUsage))%).")
        }
    }

    /// Battery check — called externally when `StatusMetrics` is available,
    /// since battery health is not on `MenuBarMonitor`.
    func checkBatteryHealth(_ healthString: String?) {
        guard settings.alertsEnabled,
              let health = healthString,
              health.localizedCaseInsensitiveContains("Service") else { return }
        fireIfCooled(.battery, message: "Battery health reports \"\(health)\" — consider servicing.")
    }

    // MARK: - Firing

    private func fireIfCooled(_ type: AlertType, message: String) {
        if let last = lastAlertTime[type], Date().timeIntervalSince(last) < cooldown { return }
        lastAlertTime[type] = Date()

        let alert = SystemAlert(type: type, message: message, timestamp: Date())
        alerts.insert(alert, at: 0)

        sendNotification(title: "\(type.rawValue.capitalized) Alert", body: message)
    }

    func dismiss(_ alert: SystemAlert) {
        guard let idx = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[idx].dismissed = true
    }

    func clearAll() {
        alerts.removeAll()
    }

    // MARK: - macOS Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    private static let settingsKey = "AlertSettings"

    private static func loadSettings() -> AlertSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(AlertSettings.self, from: data) else {
            return AlertSettings()
        }
        return decoded
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.settingsKey)
    }
}
