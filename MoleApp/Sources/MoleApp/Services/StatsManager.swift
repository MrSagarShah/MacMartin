import Foundation

/// Tracks cleanup history across all features (Clean, Privacy Sweep, Duplicates, Quick Clean).
@MainActor
final class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published var events: [CleanupEvent] = []

    private let storageKey = "macmartin_cleanup_history"

    init() {
        load()
    }

    // MARK: - Record

    func record(source: CleanupEvent.Source, bytesFreed: Int64, itemCount: Int = 0, detail: String = "") {
        let event = CleanupEvent(
            date: Date(),
            source: source,
            bytesFreed: bytesFreed,
            itemCount: itemCount,
            detail: detail
        )
        events.append(event)
        save()
    }

    // MARK: - Queries

    var totalFreed: Int64 {
        events.reduce(0) { $0 + $1.bytesFreed }
    }

    var totalEvents: Int {
        events.count
    }

    func freedThisMonth() -> Int64 {
        let cal = Calendar.current
        let now = Date()
        return events
            .filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.bytesFreed }
    }

    func freedThisWeek() -> Int64 {
        let cal = Calendar.current
        let now = Date()
        return events
            .filter { cal.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.bytesFreed }
    }

    func freedToday() -> Int64 {
        let cal = Calendar.current
        return events
            .filter { cal.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.bytesFreed }
    }

    /// Daily totals for the last N days (most recent last).
    func dailyTotals(days: Int = 30) -> [(date: Date, bytes: Int64)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: [(Date, Int64)] = []
        for i in (0..<days).reversed() {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let total = events
                .filter { cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.bytesFreed }
            result.append((day, total))
        }
        return result
    }

    func bySource() -> [(source: CleanupEvent.Source, bytes: Int64, count: Int)] {
        var dict: [CleanupEvent.Source: (Int64, Int)] = [:]
        for e in events {
            let existing = dict[e.source, default: (0, 0)]
            dict[e.source] = (existing.0 + e.bytesFreed, existing.1 + 1)
        }
        return dict.map { ($0.key, $0.value.0, $0.value.1) }
            .sorted { $0.bytes > $1.bytes }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CleanupEvent].self, from: data) else { return }
        events = decoded
    }
}

// MARK: - Model

struct CleanupEvent: Codable, Identifiable {
    let id: UUID
    let date: Date
    let source: Source
    let bytesFreed: Int64
    let itemCount: Int
    let detail: String

    init(date: Date, source: Source, bytesFreed: Int64, itemCount: Int = 0, detail: String = "") {
        self.id = UUID()
        self.date = date
        self.source = source
        self.bytesFreed = bytesFreed
        self.itemCount = itemCount
        self.detail = detail
    }

    enum Source: String, Codable, CaseIterable {
        case clean = "Clean"
        case quickClean = "Quick Clean"
        case privacySweep = "Privacy Sweep"
        case duplicates = "Duplicates"
        case maintenance = "Maintenance"

        var icon: String {
            switch self {
            case .clean: return "trash"
            case .quickClean: return "bolt"
            case .privacySweep: return "eye.slash"
            case .duplicates: return "doc.on.doc"
            case .maintenance: return "wrench.and.screwdriver"
            }
        }

        var color: String {
            switch self {
            case .clean: return "blue"
            case .quickClean: return "purple"
            case .privacySweep: return "teal"
            case .duplicates: return "orange"
            case .maintenance: return "green"
            }
        }
    }
}
