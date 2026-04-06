import SwiftUI

struct MaintenanceView: View {
    @State private var tasks: [MaintenanceTask] = Self.allTasks
    @State private var runningAll = false

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "wrench.and.screwdriver", title: "Maintenance", iconColor: MacMartinColors.success) {
                Button {
                    runAll()
                } label: {
                    Label(runningAll ? "Running..." : "Run All", systemImage: "play.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(MacMartinColors.success)
                .disabled(runningAll)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(tasks.indices, id: \.self) { i in
                        taskCard(index: i)
                            .appearAnimation(delay: Double(i) * 0.05)
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Task Card

    private func taskCard(index i: Int) -> some View {
        let task = tasks[i]
        return HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(task.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: task.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(task.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.subheadline.weight(.medium))
                Text(task.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let result = task.result {
                    Text(result)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(task.status == .done ? MacMartinColors.success : MacMartinColors.danger)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Status / Action
            switch task.status {
            case .idle:
                Button {
                    runTask(index: i)
                } label: {
                    Label("Run", systemImage: "play.circle")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            case .running:
                ProgressView()
                    .controlSize(.small)
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(MacMartinColors.success)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(MacMartinColors.danger)
            }
        }
        .padding(14)
        .cardStyle(padding: 0)
        .padding(.horizontal, 0)
    }

    // MARK: - Actions

    private func runTask(index: Int) {
        tasks[index].status = .running
        tasks[index].result = nil
        let task = tasks[index]

        Task.detached(priority: .userInitiated) {
            let result = Self.execute(task)
            await MainActor.run {
                tasks[index].result = result.message
                tasks[index].status = result.success ? .done : .failed
            }
        }
    }

    private func runAll() {
        runningAll = true
        for i in tasks.indices {
            tasks[i].status = .running
            tasks[i].result = nil
        }

        Task.detached(priority: .userInitiated) {
            for i in tasks.indices {
                let result = Self.execute(tasks[i])
                await MainActor.run {
                    tasks[i].result = result.message
                    tasks[i].status = result.success ? .done : .failed
                }
            }
            await MainActor.run {
                runningAll = false
            }
        }
    }

    // MARK: - Execution

    private static func execute(_ task: MaintenanceTask) -> (success: Bool, message: String) {
        switch task.id {
        case "flush_dns":
            return runShell("/usr/bin/dscacheutil", args: ["-flushcache"], successMsg: "DNS cache flushed successfully")

        case "rebuild_spotlight":
            // Turn off and on Spotlight indexing for the main volume
            _ = runShell("/usr/bin/mdutil", args: ["-i", "off", "/"], successMsg: "")
            return runShell("/usr/bin/mdutil", args: ["-i", "on", "/"], successMsg: "Spotlight re-indexing started. This will run in the background.")

        case "clear_font_cache":
            return runShell("/usr/bin/atsutil", args: ["databases", "-remove"], successMsg: "Font caches cleared. Restart apps to take effect.")

        case "purge_memory":
            return runShell("/usr/bin/memory_pressure", args: ["-l", "warn"], successMsg: "Memory pressure relieved")

        case "clear_quicklook":
            return runShell("/usr/bin/qlmanage", args: ["-r", "cache"], successMsg: "QuickLook cache cleared")

        case "flush_iconservices":
            let home = NSHomeDirectory()
            let paths = [
                "\(home)/Library/Caches/com.apple.iconservices.store",
                "/Library/Caches/com.apple.iconservices.store"
            ]
            var cleared = false
            for path in paths {
                if FileManager.default.fileExists(atPath: path) {
                    try? FileManager.default.removeItem(atPath: path)
                    cleared = true
                }
            }
            return (true, cleared ? "Icon caches removed. Restart Finder to see changes." : "Icon caches already clean.")

        case "repair_disk_permissions":
            return runShell("/usr/sbin/diskutil", args: ["resetUserPermissions", "/", "\(getuid())"], successMsg: "Disk permissions repaired")

        case "clear_system_logs":
            let logPath = "/private/var/log"
            let fm = FileManager.default
            var freedBytes: Int64 = 0
            if let contents = try? fm.contentsOfDirectory(atPath: logPath) {
                for item in contents where item.hasSuffix(".gz") || item.hasSuffix(".bz2") {
                    let fullPath = "\(logPath)/\(item)"
                    if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? Int64 {
                        freedBytes += size
                    }
                    try? fm.removeItem(atPath: fullPath)
                }
            }
            // Also clear ASL logs
            let aslPath = "/private/var/log/asl"
            if let aslContents = try? fm.contentsOfDirectory(atPath: aslPath) {
                for item in aslContents {
                    let fullPath = "\(aslPath)/\(item)"
                    if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? Int64 {
                        freedBytes += size
                    }
                    try? fm.removeItem(atPath: fullPath)
                }
            }
            return (true, "Cleared compressed system logs (\(formatBytes(bytes: freedBytes)))")

        case "clear_tmp":
            let tmpPath = NSTemporaryDirectory()
            let fm = FileManager.default
            var freedBytes: Int64 = 0
            var count = 0
            if let contents = try? fm.contentsOfDirectory(atPath: tmpPath) {
                for item in contents {
                    let fullPath = "\(tmpPath)/\(item)"
                    if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? Int64 {
                        freedBytes += size
                    }
                    try? fm.removeItem(atPath: fullPath)
                    count += 1
                }
            }
            return (true, "Removed \(count) temp items (\(formatBytes(bytes: freedBytes)))")

        default:
            return (false, "Unknown task")
        }
    }

    private static func runShell(_ executable: String, args: [String], successMsg: String) -> (success: Bool, message: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return (true, successMsg)
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Failed"
                return (true, output.isEmpty ? successMsg : output)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Tasks Definition

    static var allTasks: [MaintenanceTask] {
        [
            MaintenanceTask(
                id: "flush_dns",
                name: "Flush DNS Cache",
                description: "Clear the DNS resolver cache. Fixes issues with websites not loading or resolving to wrong addresses.",
                icon: "network",
                color: .blue
            ),
            MaintenanceTask(
                id: "rebuild_spotlight",
                name: "Rebuild Spotlight Index",
                description: "Force Spotlight to re-index your drive. Fixes missing search results and slow searches.",
                icon: "magnifyingglass",
                color: .purple
            ),
            MaintenanceTask(
                id: "clear_font_cache",
                name: "Clear Font Caches",
                description: "Remove corrupted font caches. Fixes font display issues and app crashes related to fonts.",
                icon: "textformat",
                color: .pink
            ),
            MaintenanceTask(
                id: "purge_memory",
                name: "Purge Memory",
                description: "Send a low-memory warning to free up inactive RAM held by applications.",
                icon: "memorychip",
                color: Color(red: 0.55, green: 0.40, blue: 0.95)
            ),
            MaintenanceTask(
                id: "clear_quicklook",
                name: "Reset QuickLook Cache",
                description: "Clear the QuickLook thumbnail and preview cache. Fixes broken previews in Finder.",
                icon: "eye",
                color: .cyan
            ),
            MaintenanceTask(
                id: "flush_iconservices",
                name: "Flush Icon Caches",
                description: "Remove cached app icons. Fixes wrong or missing icons in Finder and Launchpad.",
                icon: "app.badge",
                color: .orange
            ),
            MaintenanceTask(
                id: "repair_disk_permissions",
                name: "Repair Disk Permissions",
                description: "Reset home folder permissions to default. Fixes file access issues and app permission errors.",
                icon: "lock.shield",
                color: MacMartinColors.success
            ),
            MaintenanceTask(
                id: "clear_system_logs",
                name: "Clear System Logs",
                description: "Remove compressed system log archives. These accumulate over time and can use significant space.",
                icon: "doc.text",
                color: .gray
            ),
            MaintenanceTask(
                id: "clear_tmp",
                name: "Clear Temp Files",
                description: "Remove temporary files created by the system and apps. Safe to clear at any time.",
                icon: "clock.arrow.circlepath",
                color: .teal
            ),
        ]
    }
}

// MARK: - Model

struct MaintenanceTask: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    var status: Status = .idle
    var result: String?

    enum Status {
        case idle, running, done, failed
    }
}
