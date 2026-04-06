import SwiftUI
import AppKit

struct RAMBoosterView: View {
    @State private var processes: [AppProcessInfo] = []
    @State private var loading = true
    @State private var search = ""
    @State private var sortBy: SortField = .memory
    @State private var isPurging = false
    @State private var memoryInfo: MemoryInfo?

    enum SortField { case memory, cpu, name }

    var filteredProcesses: [AppProcessInfo] {
        var list = processes
        if !search.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        switch sortBy {
        case .memory: list.sort { $0.memoryMB > $1.memoryMB }
        case .cpu: list.sort { $0.cpuPercent > $1.cpuPercent }
        case .name: list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return list
    }

    var totalRAMUsed: Double {
        processes.reduce(0) { $0 + $1.memoryMB }
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "memorychip", title: "RAM Booster", iconColor: .purple) {
                Button {
                    purgeRAM()
                } label: {
                    Label(isPurging ? "Purging..." : "Free Up RAM", systemImage: "wind")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(isPurging)

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
                    Text("Scanning processes...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    // Memory summary
                    if let mem = memoryInfo {
                        memorySummary(mem)
                    }

                    // Search & sort
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            TextField("Search processes...", text: $search)
                                .textFieldStyle(.plain)
                                .font(.subheadline)
                        }
                        .padding(8)
                        .background(MacMartinColors.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MacMartinColors.cardBorder, lineWidth: 0.5))

                        Picker("Sort", selection: $sortBy) {
                            Text("Memory").tag(SortField.memory)
                            Text("CPU").tag(SortField.cpu)
                            Text("Name").tag(SortField.name)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    Divider()

                    // Process header
                    HStack(spacing: 0) {
                        Text("Process")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("PID")
                            .frame(width: 60, alignment: .trailing)
                        Text("CPU")
                            .frame(width: 70, alignment: .trailing)
                        Text("Memory")
                            .frame(width: 90, alignment: .trailing)
                        Text("")
                            .frame(width: 60)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)

                    Divider()

                    // Process list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredProcesses) { proc in
                                processRow(proc)
                                Divider().opacity(0.3).padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { refresh() }
    }

    // MARK: - Memory Summary

    private func memorySummary(_ mem: MemoryInfo) -> some View {
        HStack(spacing: 16) {
            memChip(label: "Used", value: String(format: "%.1f GB", mem.usedGB), color: .red, fraction: mem.usedGB / mem.totalGB)
            memChip(label: "Cached", value: String(format: "%.1f GB", mem.cachedGB), color: .orange, fraction: mem.cachedGB / mem.totalGB)
            memChip(label: "Free", value: String(format: "%.1f GB", mem.freeGB), color: MacMartinColors.success, fraction: mem.freeGB / mem.totalGB)
            memChip(label: "Total", value: String(format: "%.0f GB", mem.totalGB), color: MacMartinColors.accent, fraction: 1.0)

            Spacer()

            // Pressure indicator
            VStack(spacing: 4) {
                Text("Pressure")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(mem.pressure)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(pressureColor(mem.pressure))
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(MacMartinColors.headerGradient)
    }

    private func memChip(label: String, value: String, color: Color, fraction: Double) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.6))
                        .frame(width: max(1, geo.size.width * min(fraction, 1.0)))
                }
            }
            .frame(width: 80, height: 4)
        }
    }

    // MARK: - Process Row

    private func processRow(_ proc: AppProcessInfo) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: proc.isSystem ? "gearshape" : "app")
                    .font(.system(size: 10))
                    .foregroundStyle(proc.isSystem ? .secondary : MacMartinColors.accent)
                    .frame(width: 16)
                Text(proc.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(proc.pid)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            Text(String(format: "%.1f%%", proc.cpuPercent))
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(proc.cpuPercent > 50 ? .red : proc.cpuPercent > 20 ? .orange : .secondary)
                .frame(width: 70, alignment: .trailing)

            Text(formatMB(proc.memoryMB))
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(proc.memoryMB > 500 ? .red : proc.memoryMB > 200 ? .orange : .primary)
                .frame(width: 90, alignment: .trailing)

            Button {
                killProcess(proc.pid)
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(MacMartinColors.danger.opacity(0.7))
            }
            .buttonStyle(.plain)
            .frame(width: 60)
            .help("Kill \(proc.name)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func refresh() {
        loading = true
        Task.detached(priority: .userInitiated) {
            let procs = ramFetchProcesses()
            let mem = ramFetchMemoryInfo()
            await MainActor.run {
                processes = procs
                memoryInfo = mem
                loading = false
            }
        }
    }

    private func killProcess(_ pid: Int) {
        Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/kill")
            proc.arguments = ["-9", "\(pid)"]
            try? proc.run()
            proc.waitUntilExit()
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run { refresh() }
        }
    }

    private func purgeRAM() {
        isPurging = true
        Task.detached(priority: .userInitiated) {
            // memory_pressure sends a simulated low-memory event to reclaim pages
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
            process.arguments = ["-l", "critical"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try? process.run()

            // Kill after 10 seconds if still running — it can hang
            let proc = process
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                if proc.isRunning { proc.terminate() }
            }
            process.waitUntilExit()

            await MainActor.run {
                isPurging = false
                refresh()
            }
        }
    }

    // MARK: - Helpers

    private func formatMB(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    private func pressureColor(_ pressure: String) -> Color {
        switch pressure {
        case "Normal": return MacMartinColors.success
        case "Warning": return .orange
        case "Critical": return .red
        default: return .secondary
        }
    }
}

// MARK: - Models

struct AppProcessInfo: Identifiable {
    let pid: Int
    let name: String
    let cpuPercent: Double
    let memoryMB: Double
    let isSystem: Bool

    var id: Int { pid }
}

struct MemoryInfo {
    let totalGB: Double
    let usedGB: Double
    let freeGB: Double
    let cachedGB: Double
    let pressure: String
}

// MARK: - Data Fetching (nonisolated — runs off main thread)

private func ramFetchProcesses() -> [AppProcessInfo] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-eo", "pid,pcpu,rss,comm"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try? process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return [] }

    let systemProcesses = Set(["kernel_task", "launchd", "WindowServer", "loginwindow", "SystemUIServer", "mds", "mds_stores", "opendirectoryd", "fseventsd", "coreauthd"])

    var results: [AppProcessInfo] = []
    for line in output.components(separatedBy: "\n").dropFirst() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard parts.count >= 4 else { continue }

        let pid = Int(parts[0]) ?? 0
        guard pid > 0 else { continue }
        let cpuPct = Double(parts[1]) ?? 0
        let rssKB = Double(parts[2]) ?? 0
        let memMB = rssKB / 1024.0
        let command = String(parts[3])
        let name = URL(fileURLWithPath: command).lastPathComponent

        guard memMB > 5 || cpuPct > 0.5 else { continue }

        results.append(AppProcessInfo(
            pid: pid,
            name: name,
            cpuPercent: cpuPct,
            memoryMB: memMB,
            isSystem: systemProcesses.contains(name)
        ))
    }

    return results.sorted { $0.memoryMB > $1.memoryMB }
}

private func ramFetchMemoryInfo() -> MemoryInfo {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try? process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    func extractPages(_ key: String) -> Double {
        let pattern = "\(key):\\s+(\\d+)"
        guard let range = output.range(of: pattern, options: .regularExpression) else { return 0 }
        let match = String(output[range])
        guard let numRange = match.rangeOfCharacter(from: .decimalDigits) else { return 0 }
        let numStr = match[numRange.lowerBound...].prefix(while: { $0.isNumber })
        return Double(numStr) ?? 0
    }

    let pageSize: Double = 16384
    let active = extractPages("Pages active") * pageSize
    let inactive = extractPages("Pages inactive") * pageSize
    let speculative = extractPages("Pages speculative") * pageSize
    let wired = extractPages("Pages wired down") * pageSize
    let compressed = extractPages("Pages occupied by compressor") * pageSize
    let cached = (inactive + speculative) / (1024 * 1024 * 1024)

    let totalBytes = Double(Foundation.ProcessInfo.processInfo.physicalMemory)
    let totalGB = totalBytes / (1024 * 1024 * 1024)
    let usedGB = (active + wired + compressed) / (1024 * 1024 * 1024)
    let freeGB = totalGB - usedGB - cached

    // Determine pressure via sysctl
    let pressureProc = Process()
    pressureProc.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
    pressureProc.arguments = ["kern.memorystatus_vm_pressure_level"]
    let pressurePipe = Pipe()
    pressureProc.standardOutput = pressurePipe
    try? pressureProc.run()
    pressureProc.waitUntilExit()
    let pressureData = pressurePipe.fileHandleForReading.readDataToEndOfFile()
    let pressureOut = String(data: pressureData, encoding: .utf8) ?? ""
    let pressureLevel = Int(pressureOut.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0") ?? 0

    let pressure: String
    switch pressureLevel {
    case 0: pressure = "Normal"
    case 1: pressure = "Warning"
    case 2: pressure = "Critical"
    default: pressure = "Unknown"
    }

    return MemoryInfo(
        totalGB: totalGB,
        usedGB: max(usedGB, 0),
        freeGB: max(freeGB, 0),
        cachedGB: max(cached, 0),
        pressure: pressure
    )
}
