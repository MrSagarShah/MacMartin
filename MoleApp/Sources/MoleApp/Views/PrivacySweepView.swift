import AppKit
import SwiftUI

// MARK: - Privacy Category Model

struct PrivacyCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let color: Color
    var sizeBytes: Int64 = 0
    var selected: Bool = true
    var status: SweepStatus = .pending

    var sizeFormatted: String { formatBytes(bytes: sizeBytes) }
    var hasData: Bool { sizeBytes > 0 }
}

enum SweepStatus: Equatable {
    case pending, sweeping, done, failed(String)
}

// MARK: - Privacy Sweep View

struct PrivacySweepView: View {
    @State private var categories: [PrivacyCategory] = []
    @State private var phase: Phase = .idle
    @State private var sweepProgress: Double = 0
    @State private var sweepLog: [String] = []
    @State private var error: String?

    enum Phase: Equatable {
        case idle, scanning, scanned, sweeping, done
    }

    private var selectedCategories: [PrivacyCategory] {
        categories.filter { $0.selected && $0.hasData }
    }

    private var totalSelectedSize: Int64 {
        selectedCategories.reduce(0) { $0 + $1.sizeBytes }
    }

    private var maxCategorySize: Int64 {
        categories.map(\.sizeBytes).max() ?? 1
    }

    private var allSelected: Bool {
        categories.filter(\.hasData).allSatisfy(\.selected)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            switch phase {
            case .idle:
                idleView
            case .scanning:
                scanningView
            case .scanned:
                categoryList
            case .sweeping:
                sweepingView
            case .done:
                doneView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    // MARK: - Header

    private var header: some View {
        ViewHeader(icon: "eye.slash", title: "Privacy") {
            if phase == .scanned {
                Button {
                    startSweep()
                } label: {
                    Label("Sweep \(formatBytes(bytes: totalSelectedSize))", systemImage: "wind")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(MacMartinColors.danger)
                .disabled(selectedCategories.isEmpty)
            }
            if phase == .idle || phase == .done {
                Button {
                    startScan()
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(MacMartinColors.accent)
            }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MacMartinColors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "eye.slash")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(MacMartinColors.accent)
            }
            .pulseEffect()
            Text("Privacy Sweep")
                .font(.title3.bold())
            Text("Scan for privacy-sensitive data like browser history, recent files, clipboard contents, and cached traces.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            if let error {
                Text(error)
                    .foregroundStyle(MacMartinColors.danger)
                    .font(.caption)
                    .padding(8)
                    .cardStyle(padding: 8)
            }
            Spacer()
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MacMartinColors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(MacMartinColors.accent)
            }
            Text("Scanning...")
                .font(.title3.bold())
            Text("Checking privacy-sensitive locations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Category List

    private var categoryList: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                Button(allSelected ? "Deselect All" : "Select All") {
                    let newValue = !allSelected
                    for i in categories.indices {
                        if categories[i].hasData {
                            categories[i].selected = newValue
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(MacMartinColors.accent)
                .font(.subheadline.weight(.medium))

                Spacer()

                HStack(spacing: 6) {
                    Text("\(selectedCategories.count)")
                        .fontWeight(.bold)
                        .foregroundStyle(MacMartinColors.accent)
                    Text("selected")
                        .foregroundStyle(.secondary)
                    Text("|")
                        .foregroundStyle(.quaternary)
                    Text(formatBytes(bytes: totalSelectedSize))
                        .fontWeight(.semibold)
                        .foregroundStyle(totalSelectedSize > 1_073_741_824 ? MacMartinColors.danger :
                            totalSelectedSize > 104_857_600 ? MacMartinColors.warning : .primary)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(categories.indices, id: \.self) { i in
                        PrivacyCategoryCard(
                            category: $categories[i],
                            maxSize: maxCategorySize
                        )
                        .hoverEffect()
                        .appearAnimation(delay: Double(i) * 0.04)
                    }
                }
                .padding(16)

                // Warning notice
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(MacMartinColors.warning)
                        .font(.caption)
                    Text("Swept data cannot be recovered. Browser history and recent files will be permanently deleted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(MacMartinColors.warning.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MacMartinColors.warning.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Sweeping

    private var sweepingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MacMartinColors.danger.opacity(0.1))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(MacMartinColors.danger)
            }
            Text("Sweeping...")
                .font(.title3.bold())

            ProgressView(value: sweepProgress)
                .progressViewStyle(.linear)
                .tint(MacMartinColors.danger)
                .frame(maxWidth: 260)

            Text("\(selectedCategories.count) categories selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MacMartinColors.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(MacMartinColors.success)
            }
            Text("Sweep Complete")
                .font(.title3.bold())

            if !sweepLog.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(sweepLog, id: \.self) { entry in
                            HStack(spacing: 6) {
                                Image(systemName: entry.hasPrefix("[!]") ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(entry.hasPrefix("[!]") ? MacMartinColors.warning : MacMartinColors.success)
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(maxHeight: 200)
                .cardStyle(padding: 0)
                .padding(.horizontal, 20)
            }
            Spacer()
        }
    }

    // MARK: - Scan Logic

    private func startScan() {
        phase = .scanning
        error = nil
        categories = []

        Task.detached(priority: .userInitiated) {
            let scanned = Self.scanPrivacyCategories()
            await MainActor.run {
                categories = scanned
                phase = .scanned
            }
        }
    }

    nonisolated private static func scanPrivacyCategories() -> [PrivacyCategory] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        var results: [PrivacyCategory] = []

        // 1. Recent Files
        let recentPaths = [
            "\(home)/Library/Application Support/com.apple.sharedfilelist",
            "\(home)/Library/RecentDocuments",
        ]
        let recentSize = recentPaths.reduce(Int64(0)) { $0 + directorySize(atPath: $1) }
        results.append(PrivacyCategory(
            id: "recent_files",
            name: "Recent Files",
            icon: "clock.arrow.circlepath",
            description: "Recent document lists and shared file references",
            color: Color(red: 0.40, green: 0.52, blue: 1.0),
            sizeBytes: recentSize
        ))

        // 2. Browser History
        let browserPaths = [
            "\(home)/Library/Safari/History.db",
            "\(home)/Library/Safari/History.db-shm",
            "\(home)/Library/Safari/History.db-wal",
            "\(home)/Library/Application Support/Google/Chrome/Default/History",
            "\(home)/Library/Application Support/Google/Chrome/Default/History-journal",
            "\(home)/Library/Application Support/Firefox/Profiles",
        ]
        let browserSize = browserPaths.reduce(Int64(0)) { total, path in
            if path.hasSuffix("Profiles") {
                return total + firefoxHistorySize(profilesPath: path)
            }
            return total + fileSize(atPath: path)
        }
        results.append(PrivacyCategory(
            id: "browser_history",
            name: "Browser History",
            icon: "globe",
            description: "Safari, Chrome, and Firefox browsing history databases",
            color: Color(red: 1.0, green: 0.60, blue: 0.30),
            sizeBytes: browserSize
        ))

        // 3. Downloads History
        let downloadsPath = "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments.sflx"
        let downloadsSize = directorySize(atPath: downloadsPath)
        results.append(PrivacyCategory(
            id: "downloads_history",
            name: "Downloads History",
            icon: "arrow.down.circle",
            description: "Record of downloaded files and recent documents",
            color: Color(red: 0.45, green: 0.40, blue: 0.90),
            sizeBytes: downloadsSize
        ))

        // 4. Clipboard
        let clipboardHasContent = NSPasteboard.general.pasteboardItems?.isEmpty == false
        results.append(PrivacyCategory(
            id: "clipboard",
            name: "Clipboard",
            icon: "doc.on.clipboard",
            description: "Current clipboard contents (text, images, files)",
            color: Color(red: 0.30, green: 0.75, blue: 0.85),
            sizeBytes: clipboardHasContent ? estimateClipboardSize() : 0
        ))

        // 5. Trash
        let trashPath = "\(home)/.Trash"
        let trashSize = directorySize(atPath: trashPath)
        results.append(PrivacyCategory(
            id: "trash",
            name: "Trash",
            icon: "trash",
            description: "Files in the Trash that may contain sensitive data",
            color: Color(red: 0.95, green: 0.45, blue: 0.55),
            sizeBytes: trashSize
        ))

        // 6. DNS Cache
        results.append(PrivacyCategory(
            id: "dns_cache",
            name: "DNS Cache",
            icon: "network",
            description: "Cached DNS lookups revealing visited domains (requires admin)",
            color: Color(red: 0.35, green: 0.80, blue: 0.50),
            sizeBytes: 1024 // Symbolic size; DNS cache size is not directly measurable
        ))

        // 7. Thumbnail Cache
        let thumbPath = "\(home)/Library/Caches/com.apple.QuickLook.thumbnailcache"
        let thumbSize = directorySize(atPath: thumbPath)
        results.append(PrivacyCategory(
            id: "thumbnail_cache",
            name: "Thumbnail Cache",
            icon: "photo.stack",
            description: "QuickLook thumbnail previews of viewed files",
            color: Color(red: 0.65, green: 0.45, blue: 0.95),
            sizeBytes: thumbSize
        ))

        return results
    }

    // MARK: - Sweep Logic

    private func startSweep() {
        let toSweep = selectedCategories
        guard !toSweep.isEmpty else { return }

        phase = .sweeping
        sweepProgress = 0
        sweepLog = []

        Task.detached(priority: .userInitiated) {
            let total = Double(toSweep.count)

            for (index, category) in toSweep.enumerated() {
                await MainActor.run {
                    if let idx = categories.firstIndex(where: { $0.id == category.id }) {
                        categories[idx].status = .sweeping
                    }
                }

                let result = Self.sweep(category: category)

                await MainActor.run {
                    sweepLog.append(result)
                    sweepProgress = Double(index + 1) / total

                    if let idx = categories.firstIndex(where: { $0.id == category.id }) {
                        categories[idx].status = result.hasPrefix("[!]") ? .failed(result) : .done
                    }
                }
            }

            await MainActor.run {
                phase = .done
                // Estimate bytes from sweep log — extract sizes like "(123.5 MB)"
                var totalBytes: Int64 = 0
                for log in sweepLog {
                    if let range = log.range(of: "\\(([\\d.]+)\\s*(KB|MB|GB)\\)", options: .regularExpression) {
                        let match = String(log[range]).dropFirst().dropLast()
                        let parts = match.split(separator: " ")
                        if let num = Double(parts.first ?? "0") {
                            let unit = String(parts.last ?? "MB")
                            switch unit {
                            case "KB": totalBytes += Int64(num * 1024)
                            case "MB": totalBytes += Int64(num * 1024 * 1024)
                            case "GB": totalBytes += Int64(num * 1024 * 1024 * 1024)
                            default: break
                            }
                        }
                    }
                }
                if totalBytes > 0 {
                    StatsManager.shared.record(
                        source: .privacySweep,
                        bytesFreed: totalBytes,
                        itemCount: toSweep.count,
                        detail: "\(toSweep.count) categories swept"
                    )
                }
            }
        }
    }

    nonisolated private static func sweep(category: PrivacyCategory) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        switch category.id {
        case "recent_files":
            let paths = [
                "\(home)/Library/Application Support/com.apple.sharedfilelist",
                "\(home)/Library/RecentDocuments",
            ]
            var cleared: Int64 = 0
            for path in paths {
                cleared += removeContents(atPath: path)
            }
            return "Cleared recent files (\(formatBytes(bytes: cleared)))"

        case "browser_history":
            var cleared: Int64 = 0
            // Safari
            for suffix in ["History.db", "History.db-shm", "History.db-wal"] {
                let path = "\(home)/Library/Safari/\(suffix)"
                cleared += removeFile(atPath: path)
            }
            // Chrome
            for suffix in ["History", "History-journal"] {
                let path = "\(home)/Library/Application Support/Google/Chrome/Default/\(suffix)"
                cleared += removeFile(atPath: path)
            }
            // Firefox
            let profilesPath = "\(home)/Library/Application Support/Firefox/Profiles"
            if let profiles = try? fm.contentsOfDirectory(atPath: profilesPath) {
                for profile in profiles {
                    let placesDb = "\(profilesPath)/\(profile)/places.sqlite"
                    cleared += removeFile(atPath: placesDb)
                }
            }
            return "Cleared browser history (\(formatBytes(bytes: cleared)))"

        case "downloads_history":
            let path = "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments.sflx"
            let cleared = removeContents(atPath: path)
            return "Cleared downloads history (\(formatBytes(bytes: cleared)))"

        case "clipboard":
            NSPasteboard.general.clearContents()
            return "Cleared clipboard contents"

        case "trash":
            let trashPath = "\(home)/.Trash"
            let cleared = removeContents(atPath: trashPath)
            return "Emptied Trash (\(formatBytes(bytes: cleared)))"

        case "dns_cache":
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
            process.arguments = ["-flushcache"]
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    return "Flushed DNS cache"
                }
                return "[!] DNS flush exited with status \(process.terminationStatus) (may require admin privileges)"
            } catch {
                return "[!] DNS flush failed: \(error.localizedDescription)"
            }

        case "thumbnail_cache":
            let path = "\(home)/Library/Caches/com.apple.QuickLook.thumbnailcache"
            let cleared = removeContents(atPath: path)
            return "Cleared thumbnail cache (\(formatBytes(bytes: cleared)))"

        default:
            return "[!] Unknown category: \(category.name)"
        }
    }

    // MARK: - File Helpers

    private static func directorySize(atPath path: String) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }

        var isDir: ObjCBool = false
        fm.fileExists(atPath: path, isDirectory: &isDir)

        if !isDir.boolValue {
            return fileSize(atPath: path)
        }

        guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
        var total: Int64 = 0
        while let file = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? Int64
            {
                total += size
            }
        }
        return total
    }

    private static func fileSize(atPath path: String) -> Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64
        else { return 0 }
        return size
    }

    private static func firefoxHistorySize(profilesPath: String) -> Int64 {
        let fm = FileManager.default
        guard let profiles = try? fm.contentsOfDirectory(atPath: profilesPath) else { return 0 }
        var total: Int64 = 0
        for profile in profiles {
            let placesDb = (profilesPath as NSString).appendingPathComponent("\(profile)/places.sqlite")
            total += fileSize(atPath: placesDb)
        }
        return total
    }

    private static func estimateClipboardSize() -> Int64 {
        let pb = NSPasteboard.general
        guard let items = pb.pasteboardItems else { return 0 }
        var total: Int64 = 0
        for item in items {
            for type in item.types {
                if let data = item.data(forType: type) {
                    total += Int64(data.count)
                }
            }
        }
        return max(total, 1) // At least 1 byte if clipboard has content
    }

    private static func removeContents(atPath path: String) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }
        var cleared: Int64 = 0
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return 0 }
        for item in contents {
            let fullPath = (path as NSString).appendingPathComponent(item)
            let size = directorySize(atPath: fullPath)
            do {
                try fm.removeItem(atPath: fullPath)
                cleared += size
            } catch {
                // Skip items we cannot remove
            }
        }
        return cleared
    }

    private static func removeFile(atPath path: String) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }
        let size = fileSize(atPath: path)
        do {
            try fm.removeItem(atPath: path)
            return size
        } catch {
            return 0
        }
    }
}

// MARK: - Privacy Category Card

struct PrivacyCategoryCard: View {
    @Binding var category: PrivacyCategory
    let maxSize: Int64

    private var fraction: Double {
        guard maxSize > 0 else { return 0 }
        return Double(category.sizeBytes) / Double(maxSize)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                statusOverlay
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.name)
                        .fontWeight(.medium)
                    if category.id == "dns_cache" {
                        Text("sudo")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(MacMartinColors.warning)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(MacMartinColors.warning.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(category.sizeFormatted)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(sizeColor)
                }

                HStack(spacing: 8) {
                    if category.id != "clipboard" && category.id != "dns_cache" {
                        SizeBar(fraction: fraction, color: category.color)
                    }
                    Text(category.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Toggle
            Toggle(isOn: $category.selected) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .tint(category.color)
            .disabled(!category.hasData || category.status == .done)
            .scaleEffect(0.75)
            .frame(width: 40)
        }
        .padding(12)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(category.hasData ? 1.0 : 0.4)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch category.status {
        case .sweeping:
            ProgressView()
                .scaleEffect(0.6)
                .tint(category.color)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(MacMartinColors.success)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(MacMartinColors.warning)
        case .pending:
            Image(systemName: category.icon)
                .font(.system(size: 16))
                .foregroundStyle(category.color)
        }
    }

    private var sizeColor: Color {
        let bytes = category.sizeBytes
        if bytes > 1_073_741_824 { return MacMartinColors.danger }
        if bytes > 104_857_600 { return MacMartinColors.warning }
        return .primary
    }

    private var cardBackground: Color {
        if category.status == .done {
            return MacMartinColors.success.opacity(0.04)
        }
        if category.selected && category.hasData {
            return category.color.opacity(0.04)
        }
        return .clear
    }

    private var cardBorderColor: Color {
        if category.status == .done {
            return MacMartinColors.success.opacity(0.2)
        }
        if category.selected && category.hasData {
            return category.color.opacity(0.2)
        }
        return MacMartinColors.cardBorder
    }
}
