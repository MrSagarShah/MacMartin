import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var monitor: MenuBarMonitor
    @EnvironmentObject private var mole: MoleService
    @State private var isCleaningQuick = false
    @State private var isPurgingRAM = false
    @State private var lastCleaned: String = UserDefaults.standard.string(forKey: "macmartin_last_cleaned") ?? "Never"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                MoleLogo(size: 22)
                Text("MacMartin")
                    .font(.subheadline.bold())
                Spacer()
                Text("v\(UpdateManager.currentVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Metrics
            VStack(spacing: 10) {
                metricRow(
                    icon: "cpu",
                    label: "CPU",
                    value: String(format: "%.0f%%", monitor.cpuUsage),
                    percent: monitor.cpuUsage / 100,
                    color: monitor.cpuUsage > 80 ? .red : monitor.cpuUsage > 50 ? .orange : .green
                )

                metricRow(
                    icon: "memorychip",
                    label: "Memory",
                    value: String(format: "%.1f / %.0f GB", monitor.memoryUsed, monitor.memoryTotal),
                    percent: monitor.memoryPercent / 100,
                    color: monitor.memoryPercent > 85 ? .red : monitor.memoryPercent > 70 ? .orange : .green
                )

                metricRow(
                    icon: "internaldrive",
                    label: "Disk",
                    value: "\(monitor.diskFree) free",
                    percent: monitor.diskPercent / 100,
                    color: monitor.diskPercent > 90 ? .red : monitor.diskPercent > 75 ? .orange : .green
                )
            }
            .padding(14)

            // Last cleaned
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text("Last cleaned: \(lastCleaned)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Divider()

            // Quick Actions
            VStack(spacing: 2) {
                quickAction(icon: "trash", label: isCleaningQuick ? "Cleaning..." : "Quick Clean", color: .blue) {
                    quickClean()
                }
                .disabled(isCleaningQuick)

                quickAction(icon: "memorychip", label: isPurgingRAM ? "Purging..." : "Free Up RAM", color: .purple) {
                    purgeRAM()
                }
                .disabled(isPurgingRAM)

                quickAction(icon: "arrow.clockwise", label: "Refresh", color: .secondary) {
                    monitor.poll()
                }

                Divider().padding(.vertical, 4)

                quickAction(icon: "macwindow", label: "Open MacMartin", color: MoleColors.accent) {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows {
                        if window.canBecomeMain {
                            window.makeKeyAndOrderFront(nil)
                            break
                        }
                    }
                }

                quickAction(icon: "power", label: "Quit", color: .secondary) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .frame(width: 280)
    }

    // MARK: - Components

    private func metricRow(icon: String, label: String, value: String, percent: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.6), color],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(1, geo.size.width * min(percent, 1.0)))
                        .animation(.easeOut(duration: 0.4), value: percent)
                }
            }
            .frame(height: 4)
        }
    }

    private func quickAction(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(label)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cornerRadius(5)
    }

    // MARK: - Actions

    private func quickClean() {
        isCleaningQuick = true
        Task {
            _ = try? await mole.runCleanAll()
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastCleaned = formatter.string(from: Date())
            UserDefaults.standard.set(lastCleaned, forKey: "macmartin_last_cleaned")
            isCleaningQuick = false
        }
    }

    private func purgeRAM() {
        isPurgingRAM = true
        Task {
            // macOS memory pressure relief — runs `memory_pressure` or `purge` if available
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
            process.arguments = ["-l", "warn"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try? process.run()
            process.waitUntilExit()
            monitor.poll()
            isPurgingRAM = false
        }
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    @EnvironmentObject private var monitor: MenuBarMonitor

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                    .font(.system(size: 9))
                Text(String(format: "%.0f%%", monitor.cpuUsage))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            HStack(spacing: 2) {
                Image(systemName: "memorychip")
                    .font(.system(size: 9))
                Text(String(format: "%.0f%%", monitor.memoryPercent))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            HStack(spacing: 2) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 9))
                Text(monitor.diskFree)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
    }
}
