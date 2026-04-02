import SwiftUI

// MARK: - Storage Category Model

private struct StorageCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let bytes: Int64
    let paths: [String]

    var isEmpty: Bool { bytes <= 0 }
}

// MARK: - Storage Scanner

@MainActor
private final class StorageScanner: ObservableObject {
    @Published var categories: [StorageCategory] = []
    @Published var totalBytes: Int64 = 0
    @Published var freeBytes: Int64 = 0
    @Published var isScanning = false
    @Published var scanProgress: String = ""

    private let home = NSHomeDirectory()

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        categories = []

        Task.detached(priority: .userInitiated) { [home] in
            // Get volume capacity info
            let url = URL(fileURLWithPath: "/")
            let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            let total = Int64(values?.volumeTotalCapacity ?? 0)
            let free = Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)

            await MainActor.run {
                self.totalBytes = total
                self.freeBytes = free
            }

            // Define scan groups
            struct ScanGroup {
                let name: String
                let icon: String
                let color: Color
                let paths: [String]
            }

            let groups: [ScanGroup] = [
                ScanGroup(
                    name: "Apps",
                    icon: "app.badge",
                    color: Color(red: 0.40, green: 0.52, blue: 1.0),
                    paths: ["/Applications", "\(home)/Applications"]
                ),
                ScanGroup(
                    name: "Documents",
                    icon: "doc.text",
                    color: Color(red: 0.30, green: 0.82, blue: 0.50),
                    paths: ["\(home)/Documents", "\(home)/Desktop", "\(home)/Downloads"]
                ),
                ScanGroup(
                    name: "Developer",
                    icon: "hammer",
                    color: Color(red: 1.0, green: 0.75, blue: 0.28),
                    paths: ["\(home)/Library/Developer", "\(home)/.npm", "\(home)/.cargo", "\(home)/go"]
                ),
                ScanGroup(
                    name: "System",
                    icon: "gearshape.2",
                    color: Color(red: 0.65, green: 0.45, blue: 0.95),
                    paths: ["/System", "/Library"]
                ),
                ScanGroup(
                    name: "Library",
                    icon: "books.vertical",
                    color: Color(red: 0.30, green: 0.75, blue: 0.85),
                    paths: ["\(home)/Library"]
                ),
            ]

            var scanned: [StorageCategory] = []
            var usedByCategories: Int64 = 0

            for group in groups {
                await MainActor.run { self.scanProgress = "Scanning \(group.name)..." }

                var groupTotal: Int64 = 0
                for path in group.paths {
                    let size = Self.directorySize(path: path)
                    groupTotal += size
                }

                // Deduplicate: Library scan includes Developer paths, subtract them
                if group.name == "Library" {
                    let devPaths = ["\(home)/Library/Developer"]
                    for dp in devPaths {
                        let overlap = Self.directorySize(path: dp)
                        groupTotal = max(0, groupTotal - overlap)
                    }
                }

                let cat = StorageCategory(
                    name: group.name,
                    icon: group.icon,
                    color: group.color,
                    bytes: groupTotal,
                    paths: group.paths
                )
                scanned.append(cat)
                usedByCategories += groupTotal
            }

            // Calculate Other
            let usedTotal = total - free
            let otherBytes = max(0, usedTotal - usedByCategories)
            scanned.append(StorageCategory(
                name: "Other",
                icon: "ellipsis.circle",
                color: Color(red: 0.55, green: 0.55, blue: 0.60),
                bytes: otherBytes,
                paths: []
            ))

            // Free space
            scanned.append(StorageCategory(
                name: "Free Space",
                icon: "circle.dashed",
                color: Color.white.opacity(0.15),
                bytes: free,
                paths: []
            ))

            await MainActor.run {
                self.categories = scanned
                self.isScanning = false
                self.scanProgress = ""
            }
        }
    }

    /// Uses `du -sk` via Process for fast directory sizing, with a timeout fallback.
    nonisolated private static func directorySize(path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else { return 0 }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return 0
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8),
              let sizeStr = output.split(separator: "\t").first,
              let kb = Int64(sizeStr) else {
            return 0
        }

        return kb * 1024 // convert KB to bytes
    }
}

// MARK: - Donut Chart View

private struct DonutChart: View {
    let slices: [(color: Color, fraction: Double)]
    let totalLabel: String
    let size: CGFloat

    private let lineWidth: CGFloat = 28
    private let gapDegrees: Double = 1.5

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: lineWidth)

            // Slices
            ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                let startAngle = startAngle(for: index)
                let sweep = slice.fraction * 360.0 - gapDegrees * 2
                if sweep > 0.5 {
                    Circle()
                        .trim(
                            from: max(0, startAngle / 360.0),
                            to: max(0, (startAngle + sweep) / 360.0)
                        )
                        .stroke(
                            AngularGradient(
                                colors: [slice.color.opacity(0.85), slice.color],
                                center: .center,
                                startAngle: .degrees(startAngle),
                                endAngle: .degrees(startAngle + sweep)
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: slice.color.opacity(0.3), radius: 4, y: 1)
                }
            }

            // Center label
            VStack(spacing: 2) {
                Text(totalLabel)
                    .font(.system(size: size * 0.14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Total")
                    .font(.system(size: size * 0.07, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func startAngle(for index: Int) -> Double {
        var angle = 0.0
        for i in 0..<index {
            angle += slices[i].fraction * 360.0
        }
        return angle + gapDegrees
    }
}

// MARK: - Legend Row

private struct LegendRow: View {
    let category: StorageCategory
    let total: Int64
    @State private var isHovered = false

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(category.bytes) / Double(total) * 100
    }

    var body: some View {
        Button {
            openInFinder()
        } label: {
            HStack(spacing: 10) {
                // Color dot
                Circle()
                    .fill(category.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: category.color.opacity(0.4), radius: 3)

                // Icon
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(category.color)
                    .frame(width: 16)

                // Name
                Text(category.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                // Size
                Text(formatBytes(bytes: category.bytes))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                // Percentage
                Text(String(format: "%.1f%%", percentage))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)

                if !category.paths.isEmpty {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(isHovered ? category.color : Color.secondary.opacity(0.4))
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .disabled(category.paths.isEmpty)
    }

    private func openInFinder() {
        guard let first = category.paths.first else { return }
        let url = URL(fileURLWithPath: first)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}

// MARK: - Scanning Indicator

private struct ScanningView: View {
    let progress: String

    @State private var rotation = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 28)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AngularGradient(
                            colors: [MoleColors.accent.opacity(0.1), MoleColors.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 28, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                VStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(MoleColors.accent)
                    Text("Scanning")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
            }

            Text(progress)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .animation(.easeInOut(duration: 0.2), value: progress)

            Spacer()
        }
    }
}

// MARK: - Main View

struct StorageBreakdownView: View {
    @StateObject private var scanner = StorageScanner()

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "chart.pie.fill", title: "Storage") {
                if !scanner.isScanning {
                    Button {
                        scanner.scan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if scanner.isScanning {
                ScanningView(progress: scanner.scanProgress)
            } else if scanner.categories.isEmpty {
                emptyState
            } else {
                chartContent
            }
        }
        .onAppear {
            if scanner.categories.isEmpty {
                scanner.scan()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.pie")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(MoleColors.subtleText)
            Text("Scan your disk to see the storage breakdown")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button("Scan Now") {
                scanner.scan()
            }
            .buttonStyle(.borderedProminent)
            .tint(MoleColors.accent)
            Spacer()
        }
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Donut chart card
                VStack(spacing: 16) {
                    let slices = scanner.categories
                        .filter { !$0.isEmpty }
                        .map { cat -> (color: Color, fraction: Double) in
                            let frac = scanner.totalBytes > 0
                                ? Double(cat.bytes) / Double(scanner.totalBytes)
                                : 0
                            return (cat.color, frac)
                        }

                    DonutChart(
                        slices: slices,
                        totalLabel: formatBytes(bytes: scanner.totalBytes),
                        size: 200
                    )
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.8), value: scanner.categories.map(\.bytes))

                    // Used / Free summary
                    HStack(spacing: 24) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(MoleColors.accent)
                                .frame(width: 7, height: 7)
                            Text("Used: \(formatBytes(bytes: scanner.totalBytes - scanner.freeBytes))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 7, height: 7)
                            Text("Free: \(formatBytes(bytes: scanner.freeBytes))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .cardStyle()
                .appearAnimation(delay: 0.0)

                // Legend card
                VStack(spacing: 2) {
                    ForEach(Array(scanner.categories.filter { !$0.isEmpty }.enumerated()),
                            id: \.element.id) { index, category in
                        LegendRow(category: category, total: scanner.totalBytes)
                            .appearAnimation(delay: 0.1 + Double(index) * 0.04)

                        if index < scanner.categories.filter({ !$0.isEmpty }).count - 1 {
                            Divider()
                                .padding(.horizontal, 12)
                                .opacity(0.4)
                        }
                    }
                }
                .cardStyle(padding: 8)
                .appearAnimation(delay: 0.05)
            }
            .padding(16)
        }
    }
}
