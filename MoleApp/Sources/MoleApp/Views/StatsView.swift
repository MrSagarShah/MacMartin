import SwiftUI

struct StatsView: View {
    @StateObject private var stats = StatsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "chart.bar", title: "History & Stats", iconColor: Color(red: 0.55, green: 0.40, blue: 0.95)) {}

            if stats.events.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        summaryCards
                        chartSection
                        sourceBreakdown
                        recentActivity
                    }
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "chart.bar")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.purple)
            }
            .pulseEffect()
            Text("No cleanup history yet")
                .font(.title3.bold())
            Text("Run a cleanup, privacy sweep, or duplicate removal to start tracking your freed space.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            Spacer()
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Today",
                value: formatBytes(bytes: stats.freedToday()),
                icon: "sun.max",
                color: .orange
            )
            statCard(
                title: "This Week",
                value: formatBytes(bytes: stats.freedThisWeek()),
                icon: "calendar",
                color: MacMartinColors.accent
            )
            statCard(
                title: "This Month",
                value: formatBytes(bytes: stats.freedThisMonth()),
                icon: "calendar.badge.clock",
                color: .purple
            )
            statCard(
                title: "All Time",
                value: formatBytes(bytes: stats.totalFreed),
                icon: "infinity",
                color: MacMartinColors.success
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text("\(eventsIn(title)) cleanups")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle(padding: 12)
    }

    private func eventsIn(_ period: String) -> Int {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case "Today":
            return stats.events.filter { cal.isDateInToday($0.date) }.count
        case "This Week":
            return stats.events.filter { cal.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }.count
        case "This Month":
            return stats.events.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }.count
        default:
            return stats.totalEvents
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 30 Days")
                .font(.subheadline.bold())

            let dailyData = stats.dailyTotals(days: 30)
            let maxBytes = dailyData.map(\.bytes).max() ?? 1

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(dailyData.enumerated()), id: \.offset) { _, entry in
                    let height = maxBytes > 0 ? CGFloat(entry.bytes) / CGFloat(maxBytes) : 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            entry.bytes > 0
                                ? LinearGradient(colors: [.purple.opacity(0.5), .purple], startPoint: .bottom, endPoint: .top)
                                : LinearGradient(colors: [Color.white.opacity(0.03), Color.white.opacity(0.03)], startPoint: .bottom, endPoint: .top)
                        )
                        .frame(maxWidth: .infinity, minHeight: 2)
                        .frame(height: max(2, 120 * height))
                }
            }
            .frame(height: 120)

            // X-axis labels
            HStack {
                Text("30d ago")
                Spacer()
                Text("Today")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    // MARK: - Source Breakdown

    private var sourceBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Source")
                .font(.subheadline.bold())

            let sources = stats.bySource()
            let maxSourceBytes = sources.first?.bytes ?? 1

            ForEach(sources, id: \.source) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.source.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(sourceColor(item.source))
                        .frame(width: 20)

                    Text(item.source.rawValue)
                        .font(.subheadline)
                        .frame(width: 100, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(sourceColor(item.source).opacity(0.1))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(sourceColor(item.source).opacity(0.6))
                                .frame(width: max(2, geo.size.width * CGFloat(item.bytes) / CGFloat(maxSourceBytes)))
                        }
                    }
                    .frame(height: 8)

                    Text(formatBytes(bytes: item.bytes))
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .frame(width: 70, alignment: .trailing)

                    Text("\(item.count)x")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(stats.totalEvents) total")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            let recent = stats.events.suffix(20).reversed()
            ForEach(Array(recent)) { event in
                HStack(spacing: 10) {
                    Image(systemName: event.source.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(sourceColor(event.source))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(event.source.rawValue)
                                .font(.subheadline.weight(.medium))
                            if !event.detail.isEmpty {
                                Text(event.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Text(relativeDate(event.date))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text(formatBytes(bytes: event.bytesFreed))
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(MacMartinColors.success)
                }
                .padding(.vertical, 4)

                if event.id != recent.last?.id {
                    Divider().opacity(0.3)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func sourceColor(_ source: CleanupEvent.Source) -> Color {
        switch source {
        case .clean: return MacMartinColors.accent
        case .quickClean: return .purple
        case .privacySweep: return Color(red: 0.30, green: 0.75, blue: 0.85)
        case .duplicates: return .orange
        case .maintenance: return MacMartinColors.success
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
