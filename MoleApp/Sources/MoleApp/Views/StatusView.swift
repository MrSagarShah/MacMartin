import SwiftUI

struct StatusView: View {
    @EnvironmentObject private var mole: MacMartinService
    @State private var metrics: StatusMetrics?
    @State private var loading = false
    @State private var error: String?
    @State private var timer: Timer?
    @State private var refreshRotation = 0.0

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "heart.text.square", title: "Status") {
                Button {
                    refreshRotation += 360
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(refreshRotation))
                        .animation(.easeInOut(duration: 0.5), value: refreshRotation)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if let metrics {
                ScrollView {
                    VStack(spacing: 14) {
                        healthCard(metrics)
                            .appearAnimation(delay: 0)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                        ], spacing: 12) {
                            cpuCard(metrics.cpu)
                                .appearAnimation(delay: 0.05)
                            memoryCard(metrics.memory)
                                .appearAnimation(delay: 0.1)
                            if let disks = metrics.disks {
                                ForEach(Array(disks.enumerated()), id: \.element.mount) { i, disk in
                                    diskCard(disk)
                                        .appearAnimation(delay: 0.15 + Double(i) * 0.05)
                                }
                            }
                            if let thermal = metrics.thermal {
                                thermalCard(thermal)
                                    .appearAnimation(delay: 0.2)
                            }
                            if let batteries = metrics.batteries, !batteries.isEmpty {
                                batteryCard(batteries[0])
                                    .appearAnimation(delay: 0.25)
                            }
                            if let procs = metrics.topProcesses, !procs.isEmpty {
                                processCard(procs)
                                    .appearAnimation(delay: 0.3)
                            }
                        }
                    }
                    .padding(16)
                }
            } else if let error {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(MacMartinColors.warning)
                    Text("Failed to load metrics")
                        .font(.headline)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 350)
                    Button("Retry") { refresh() }
                        .buttonStyle(.borderedProminent)
                        .tint(MacMartinColors.accent)
                    Spacer()
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(MacMartinColors.accent)
                    Text("Loading metrics...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .onAppear { refresh(); startAutoRefresh() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Health

    private func healthCard(_ m: StatusMetrics) -> some View {
        HStack(spacing: 20) {
            RingGauge(
                value: Double(m.healthScore) / 100,
                size: 90, lineWidth: 8,
                color: healthColor(m.healthScore),
                label: "\(m.healthScore)",
                sublabel: "Health"
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(m.host)
                    .font(.headline)
                Text(m.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Label(m.uptime, systemImage: "clock")
                    Label("\(m.procs) procs", systemImage: "cpu")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(m.healthScoreMsg)
                    .font(.caption)
                    .foregroundStyle(healthColor(m.healthScore))
                    .lineLimit(2)
            }
            Spacer()
        }
        .cardStyle()
    }

    // MARK: - Cards

    private func cpuCard(_ cpu: CPUStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("CPU", systemImage: "cpu")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                RingGauge(
                    value: cpu.usage / 100,
                    size: 52, lineWidth: 5,
                    color: cpu.usage > 80 ? MacMartinColors.danger : cpu.usage > 50 ? MacMartinColors.warning : MacMartinColors.success,
                    label: String(format: "%.0f%%", cpu.usage)
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(cpu.coreCount) cores")
                        .font(.caption)
                    HStack(spacing: 3) {
                        Text("Load")
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.1f", cpu.load1))
                            .foregroundStyle(cpu.load1 > Double(cpu.coreCount) ? MacMartinColors.danger : .primary)
                    }
                    .font(.caption2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .hoverEffect()
    }

    private func memoryCard(_ mem: MemoryStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Memory", systemImage: "memorychip")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                RingGauge(
                    value: mem.usedPercent / 100,
                    size: 52, lineWidth: 5,
                    color: mem.usedPercent > 85 ? MacMartinColors.danger : mem.usedPercent > 70 ? MacMartinColors.warning : MacMartinColors.success,
                    label: String(format: "%.0f%%", mem.usedPercent)
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(formatBytes(bytes: Int64(mem.used))) / \(formatBytes(bytes: Int64(mem.total)))")
                        .font(.caption)
                    HStack(spacing: 3) {
                        Text("Pressure")
                            .foregroundStyle(.tertiary)
                        Text(mem.pressure)
                            .foregroundStyle(mem.pressure == "normal" ? MacMartinColors.success : MacMartinColors.warning)
                    }
                    .font(.caption2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .hoverEffect()
    }

    private func diskCard(_ disk: DiskStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Disk \(disk.mount)", systemImage: "internaldrive")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                RingGauge(
                    value: disk.usedPercent / 100,
                    size: 52, lineWidth: 5,
                    color: disk.usedPercent > 90 ? MacMartinColors.danger : disk.usedPercent > 75 ? MacMartinColors.warning : MacMartinColors.success,
                    label: String(format: "%.0f%%", disk.usedPercent)
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(formatBytes(bytes: Int64(disk.used))) / \(formatBytes(bytes: Int64(disk.total)))")
                        .font(.caption)
                    Text(disk.device)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .hoverEffect()
    }

    private func thermalCard(_ t: ThermalStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Thermal", systemImage: "thermometer.medium")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f\u{00B0}", t.cpuTemp))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(t.cpuTemp > 90 ? MacMartinColors.danger : t.cpuTemp > 70 ? MacMartinColors.warning : .primary)
                    Text("CPU").font(.caption2).foregroundStyle(.tertiary)
                }
                if t.gpuTemp > 0 {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f\u{00B0}", t.gpuTemp))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text("GPU").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if t.systemPower > 0 {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1fW", t.systemPower))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text("Power").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .hoverEffect()
    }

    private func batteryCard(_ b: BatteryStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Battery", systemImage: "battery.100percent")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                RingGauge(
                    value: b.percent / 100,
                    size: 52, lineWidth: 5,
                    color: b.percent < 20 ? MacMartinColors.danger : b.percent < 50 ? MacMartinColors.warning : MacMartinColors.success,
                    label: String(format: "%.0f%%", b.percent)
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(b.status)
                        .font(.caption)
                    if let health = b.health {
                        HStack(spacing: 3) {
                            Text("Health")
                                .foregroundStyle(.tertiary)
                            Text(health)
                                .foregroundStyle(health.contains("Normal") ? MacMartinColors.success : MacMartinColors.warning)
                        }
                        .font(.caption2)
                    }
                    if let cycles = b.cycleCount {
                        Text("\(cycles) cycles")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .hoverEffect()
    }

    private func processCard(_ procs: [MacMartinProcessInfo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Top Processes", systemImage: "list.bullet")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(procs.prefix(5)) { p in
                HStack {
                    Text(p.name)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1f%%", p.cpu))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(p.cpu > 50 ? MacMartinColors.danger : p.cpu > 20 ? MacMartinColors.warning : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .hoverEffect()
    }

    // MARK: - Helpers

    private func healthColor(_ score: Int) -> Color {
        if score >= 80 { return MacMartinColors.success }
        if score >= 60 { return MacMartinColors.warning }
        return MacMartinColors.danger
    }

    private func refresh() {
        loading = true
        Task {
            do {
                metrics = try await mole.getStatus()
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            refresh()
        }
    }
}
