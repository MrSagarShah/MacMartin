import Foundation

// MARK: - Notifications

extension Notification.Name {
    static let switchTab = Notification.Name("macmartin.switchTab")
}

// MARK: - Sidebar

enum SidebarTab: String, CaseIterable, Identifiable {
    case clean = "Clean"
    case status = "Status"
    case analyze = "Analyze"
    case uninstall = "Uninstall"
    case optimize = "Optimize"
    case largeFiles = "Large Files"
    case duplicates = "Duplicates"
    case privacy = "Privacy"
    case startup = "Startup"
    case updates = "Updates"
    case ram = "RAM Booster"
    case battery = "Battery"
    case maintenance = "Maintenance"
    case storage = "Storage"
    case dictation = "Dictation"
    case alerts = "Alerts"
    case stats = "History"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .clean: return "trash"
        case .status: return "heart.text.square"
        case .analyze: return "chart.pie"
        case .uninstall: return "xmark.app"
        case .optimize: return "gauge.with.dots.needle.33percent"
        case .largeFiles: return "doc.badge.arrow.up"
        case .duplicates: return "doc.on.doc"
        case .privacy: return "eye.slash"
        case .startup: return "power"
        case .updates: return "arrow.triangle.2.circlepath.circle"
        case .ram: return "memorychip"
        case .battery: return "battery.100.bolt"
        case .maintenance: return "wrench.and.screwdriver"
        case .storage: return "chart.pie.fill"
        case .dictation: return "mic.fill"
        case .alerts: return "bell.badge"
        case .stats: return "chart.bar"
        case .about: return "info.circle"
        }
    }

    var isPro: Bool {
        switch self {
        case .analyze, .uninstall, .optimize, .duplicates, .privacy, .startup, .updates: return true
        case .clean, .status, .largeFiles, .ram, .battery, .maintenance, .storage, .dictation, .alerts, .stats, .about: return false
        }
    }

    var proDescription: String {
        switch self {
        case .clean: return "Remove caches, logs, and temporary files"
        case .status: return "Monitor system health in real time"
        case .analyze: return "Explore disk usage and find large files"
        case .uninstall: return "Completely remove apps and their leftovers"
        case .optimize: return "Tune system performance with 14 optimizations"
        case .largeFiles: return "Find the biggest files eating your disk space"
        case .duplicates: return "Find and remove duplicate files wasting space"
        case .privacy: return "Clear browser history, recent files, and traces"
        case .startup: return "Control what launches when you log in"
        case .updates: return "Check installed apps for available updates"
        case .ram: return "See what's eating memory and free up RAM"
        case .battery: return "Battery health, cycle count, and condition"
        case .maintenance: return "Flush DNS, rebuild Spotlight, repair permissions"
        case .storage: return "Visual breakdown of what's using your disk"
        case .dictation: return "Hold a hotkey to dictate anywhere on macOS"
        case .alerts: return "Get notified when system resources are critical"
        case .stats: return "Track your cleanups and space freed over time"
        case .about: return "About Krakel Labs"
        }
    }

    /// Group tabs into sidebar sections.
    var section: String {
        switch self {
        case .clean, .status, .stats: return "Essentials"
        case .analyze, .uninstall, .optimize, .largeFiles: return "Tools"
        case .duplicates, .privacy, .startup, .updates: return "Utilities"
        case .ram, .battery, .maintenance: return "System"
        case .dictation: return "Productivity"
        case .storage, .alerts, .about: return "More"
        }
    }

    static var sections: [(String, [SidebarTab])] {
        let order = ["Essentials", "Tools", "Utilities", "System", "Productivity", "More"]
        return order.compactMap { section in
            let tabs = allCases.filter { $0.section == section }
            return tabs.isEmpty ? nil : (section, tabs)
        }
    }
}

// MARK: - Clean

struct CleanScanResult: Codable {
    let architecture: String
    let freeSpace: String
    let categories: [CleanCategory]
    let totalSizeKb: Int

    enum CodingKeys: String, CodingKey {
        case architecture
        case freeSpace = "free_space"
        case categories
        case totalSizeKb = "total_size_kb"
    }
}

struct CleanCategory: Codable, Identifiable {
    let name: String
    let sizeKb: Int
    let items: Int
    var selected: Bool = true

    var id: String { name }

    var sizeFormatted: String { formatBytes(kb: sizeKb) }

    enum CodingKeys: String, CodingKey {
        case name
        case sizeKb = "size_kb"
        case items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        sizeKb = try c.decode(Int.self, forKey: .sizeKb)
        items = try c.decode(Int.self, forKey: .items)
        selected = sizeKb > 0
    }

    init(name: String, sizeKb: Int, items: Int, selected: Bool = true) {
        self.name = name
        self.sizeKb = sizeKb
        self.items = items
        self.selected = selected
    }
}

// MARK: - Status

struct StatusMetrics: Codable {
    let collectedAt: String
    let host: String
    let platform: String
    let uptime: String
    let uptimeSeconds: UInt64
    let procs: UInt64
    let healthScore: Int
    let healthScoreMsg: String
    let cpu: CPUStatus
    let gpu: [GPUStatus]?
    let memory: MemoryStatus
    let disks: [DiskStatus]?
    let batteries: [BatteryStatus]?
    let thermal: ThermalStatus?
    let topProcesses: [MacMartinProcessInfo]?

    enum CodingKeys: String, CodingKey {
        case collectedAt = "collected_at"
        case host, platform, uptime
        case uptimeSeconds = "uptime_seconds"
        case procs
        case healthScore = "health_score"
        case healthScoreMsg = "health_score_msg"
        case cpu, gpu, memory, disks, batteries, thermal
        case topProcesses = "top_processes"
    }
}

struct CPUStatus: Codable {
    let usage: Double
    let load1: Double
    let load5: Double
    let load15: Double
    let coreCount: Int

    enum CodingKeys: String, CodingKey {
        case usage, load1, load5, load15
        case coreCount = "core_count"
    }
}

struct GPUStatus: Codable {
    let name: String
    let usage: Double?
    let memoryUsed: UInt64?
    let memoryTotal: UInt64?

    enum CodingKeys: String, CodingKey {
        case name, usage
        case memoryUsed = "memory_used"
        case memoryTotal = "memory_total"
    }
}

struct MemoryStatus: Codable {
    let used: UInt64
    let total: UInt64
    let usedPercent: Double
    let cached: UInt64
    let pressure: String

    enum CodingKeys: String, CodingKey {
        case used, total
        case usedPercent = "used_percent"
        case cached, pressure
    }
}

struct DiskStatus: Codable {
    let mount: String
    let device: String
    let used: UInt64
    let total: UInt64
    let usedPercent: Double

    enum CodingKeys: String, CodingKey {
        case mount, device, used, total
        case usedPercent = "used_percent"
    }
}

struct BatteryStatus: Codable {
    let percent: Double
    let status: String
    let timeLeft: String?
    let health: String?
    let cycleCount: Int?
    let capacity: Int?

    enum CodingKeys: String, CodingKey {
        case percent, status
        case timeLeft = "time_left"
        case health
        case cycleCount = "cycle_count"
        case capacity
    }
}

struct ThermalStatus: Codable {
    let cpuTemp: Double
    let gpuTemp: Double
    let fanSpeed: ThermalFanSpeed
    let systemPower: Double

    enum CodingKeys: String, CodingKey {
        case cpuTemp = "cpu_temp"
        case gpuTemp = "gpu_temp"
        case fanSpeed = "fan_speed"
        case systemPower = "system_power"
    }
}

/// fan_speed can be a single int (0 on fanless Macs) or an array of ints.
enum ThermalFanSpeed: Codable {
    case single(Int)
    case multiple([Int])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([Int].self) {
            self = .multiple(arr)
        } else if let val = try? container.decode(Int.self) {
            self = .single(val)
        } else {
            self = .single(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let v): try container.encode(v)
        case .multiple(let a): try container.encode(a)
        }
    }
}

struct MacMartinProcessInfo: Codable, Identifiable {
    let pid: Int
    let name: String
    let cpu: Double
    let memory: Double

    // Ignore extra fields (ppid, command) gracefully.
    var id: Int { pid }

    enum CodingKeys: String, CodingKey {
        case pid, name, cpu, memory
    }
}

// MARK: - Analyze

struct AnalyzeResult: Codable {
    let path: String
    let entries: [DiskEntry]
    let totalSize: Int64
    let totalFiles: Int64

    enum CodingKeys: String, CodingKey {
        case path, entries
        case totalSize = "total_size"
        case totalFiles = "total_files"
    }
}

struct DiskEntry: Codable, Identifiable {
    let name: String
    let path: String
    let size: Int64
    let isDir: Bool

    var id: String { path }
    var sizeFormatted: String { formatBytes(bytes: size) }

    enum CodingKeys: String, CodingKey {
        case name, path, size
        case isDir = "is_dir"
    }
}

// MARK: - Optimize

struct OptimizationTask: Identifiable {
    let id: String
    let name: String
    let description: String
    let action: String
    var status: TaskStatus = .pending

    enum TaskStatus {
        case pending, running, done, failed
    }
}

// MARK: - Uninstall

struct InstalledApp: Identifiable {
    let path: String
    let name: String
    let bundleId: String
    let sizeHuman: String
    let sizeKb: Int
    let lastUsed: String
    var selected: Bool = false

    var id: String { path }
}

// MARK: - Helpers

func formatBytes(kb: Int) -> String {
    let bytes = Double(kb) * 1024
    return formatBytes(bytes: Int64(bytes))
}

func formatBytes(bytes: Int64) -> String {
    let gb = Double(bytes) / (1024 * 1024 * 1024)
    if gb >= 1.0 {
        return String(format: "%.1f GB", gb)
    }
    let mb = Double(bytes) / (1024 * 1024)
    if mb >= 1.0 {
        return String(format: "%.1f MB", mb)
    }
    let kb = Double(bytes) / 1024
    return String(format: "%.0f KB", kb)
}
