import Foundation
import AppKit

/// Lightweight system metrics poller for the menu bar.
/// Uses sysctl/host_statistics directly — no CLI dependency.
@MainActor
class MenuBarMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var memoryUsed: Double = 0
    @Published var memoryTotal: Double = 0
    @Published var memoryPercent: Double = 0
    @Published var diskPercent: Double = 0
    @Published var diskFree: String = ""

    private var timer: Timer?
    private var prevCPUInfo: host_cpu_load_info?

    init() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func poll() {
        cpuUsage = getCPUUsage()
        let mem = getMemoryInfo()
        memoryUsed = mem.used
        memoryTotal = mem.total
        memoryPercent = mem.total > 0 ? (mem.used / mem.total) * 100 : 0
        let disk = getDiskInfo()
        diskPercent = disk.total > 0 ? (disk.used / disk.total) * 100 : 0
        diskFree = formatGB(disk.total - disk.used)
    }

    // MARK: - CPU

    private func getCPUUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = Double(cpuInfo.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1)
        let idle = Double(cpuInfo.cpu_ticks.2)
        let nice = Double(cpuInfo.cpu_ticks.3)

        if let prev = prevCPUInfo {
            let dUser = user - Double(prev.cpu_ticks.0)
            let dSystem = system - Double(prev.cpu_ticks.1)
            let dIdle = idle - Double(prev.cpu_ticks.2)
            let dNice = nice - Double(prev.cpu_ticks.3)
            let total = dUser + dSystem + dIdle + dNice
            prevCPUInfo = cpuInfo
            return total > 0 ? ((dUser + dSystem + dNice) / total) * 100 : 0
        }
        prevCPUInfo = cpuInfo
        let total = user + system + idle + nice
        return total > 0 ? ((user + system + nice) / total) * 100 : 0
    }

    // MARK: - Memory

    private func getMemoryInfo() -> (used: Double, total: Double) {
        let total = Double(Foundation.ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, total) }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let used = (active + wired + compressed) / (1024 * 1024 * 1024)

        return (used, total)
    }

    // MARK: - Disk

    private func getDiskInfo() -> (used: Double, total: Double) {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let totalBytes = attrs[.systemSize] as? Int64,
              let freeBytes = attrs[.systemFreeSize] as? Int64 else {
            return (0, 0)
        }
        let total = Double(totalBytes) / (1024 * 1024 * 1024)
        let free = Double(freeBytes) / (1024 * 1024 * 1024)
        return (total - free, total)
    }

    private func formatGB(_ gb: Double) -> String {
        String(format: "%.0f GB", gb)
    }
}
