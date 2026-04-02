import SwiftUI

struct AlertsView: View {
    @EnvironmentObject private var alertManager: AlertManager
    @EnvironmentObject private var menuBarMonitor: MenuBarMonitor

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "bell.badge", title: "Alerts") {
                if !alertManager.alerts.isEmpty {
                    Button {
                        withAnimation { alertManager.clearAll() }
                    } label: {
                        Text("Clear All")
                            .font(.caption)
                            .foregroundStyle(MoleColors.subtleText)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView {
                VStack(spacing: 14) {
                    settingsSection
                        .appearAnimation(delay: 0)

                    historySection
                        .appearAnimation(delay: 0.1)
                }
                .padding(16)
            }
        }
        .onAppear {
            alertManager.start(monitor: menuBarMonitor)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Settings", systemImage: "gearshape")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Toggle(isOn: $alertManager.settings.alertsEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(alertManager.settings.alertsEnabled ? MoleColors.accent : .secondary)
                        .font(.system(size: 13))
                    Text("Enable Smart Alerts")
                        .font(.subheadline)
                }
            }
            .toggleStyle(.switch)
            .tint(MoleColors.accent)

            if alertManager.settings.alertsEnabled {
                VStack(spacing: 12) {
                    thresholdSlider(
                        label: "Disk",
                        icon: "internaldrive.fill",
                        value: $alertManager.settings.diskThreshold,
                        color: MoleColors.danger
                    )
                    thresholdSlider(
                        label: "Memory",
                        icon: "memorychip.fill",
                        value: $alertManager.settings.memoryThreshold,
                        color: MoleColors.warning
                    )
                    thresholdSlider(
                        label: "CPU",
                        icon: "cpu",
                        value: $alertManager.settings.cpuThreshold,
                        color: Color(red: 1.0, green: 0.45, blue: 0.30)
                    )
                }
                .padding(.top, 4)
            }
        }
        .cardStyle()
        .hoverEffect()
    }

    private func thresholdSlider(label: String, icon: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(value.wrappedValue))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 50...99, step: 1)
                .tint(color)
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Alert History", systemImage: "clock.arrow.circlepath")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            let active = alertManager.alerts.filter { !$0.dismissed }
            let dismissed = alertManager.alerts.filter { $0.dismissed }

            if alertManager.alerts.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(active) { alert in
                        alertRow(alert)
                    }
                    if !dismissed.isEmpty {
                        HStack {
                            Text("Dismissed")
                                .font(.caption2.bold())
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .padding(.top, 4)

                        ForEach(dismissed) { alert in
                            alertRow(alert)
                                .opacity(0.5)
                        }
                    }
                }
            }
        }
        .cardStyle()
        .hoverEffect()
    }

    private func alertRow(_ alert: SystemAlert) -> some View {
        HStack(spacing: 10) {
            Image(systemName: alert.type.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(alert.type.color)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(alert.type.color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.caption)
                    .lineLimit(2)
                Text(alert.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            if !alert.dismissed {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        alertManager.dismiss(alert)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No alerts yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Alerts will appear here when system thresholds are exceeded.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
