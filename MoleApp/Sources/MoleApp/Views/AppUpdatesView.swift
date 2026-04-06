import SwiftUI
import AppKit

// MARK: - Models

struct AppUpdateInfo: Identifiable {
    let id: String // bundle path
    let name: String
    let bundleId: String
    let currentVersion: String
    let iconPath: String?
    var latestVersion: String?
    var updateAvailable: Bool = false
    var source: AppSource = .unknown
}

enum AppSource: String {
    case appStore = "App Store"
    case homebrew = "Homebrew"
    case unknown = "Manual"
}

// MARK: - Update Checker

@MainActor
final class AppUpdateChecker: ObservableObject {
    @Published var apps: [AppUpdateInfo] = []
    @Published var scanning = false
    @Published var scanProgress = 0
    @Published var scanTotal = 0
    @Published var error: String?

    private var homebrewOutdated: Set<String> = []

    func checkForUpdates() {
        scanning = true
        scanProgress = 0
        scanTotal = 0
        apps = []
        error = nil

        Task.detached { [weak self] in
            do {
                let discovered = await self?.discoverApps() ?? []
                await MainActor.run {
                    self?.scanTotal = discovered.count
                }

                let outdated = await self?.fetchHomebrewOutdated() ?? []
                await MainActor.run {
                    self?.homebrewOutdated = outdated
                }

                var results: [AppUpdateInfo] = []

                for (index, var app) in discovered.enumerated() {
                    app = await self?.checkUpdate(for: app) ?? app
                    results.append(app)
                    await MainActor.run {
                        self?.scanProgress = index + 1
                    }
                }

                let sorted = results.sorted { a, b in
                    if a.updateAvailable != b.updateAvailable {
                        return a.updateAvailable
                    }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }

                await MainActor.run {
                    self?.apps = sorted
                    self?.scanning = false
                }
            }
        }
    }

    // MARK: - Discovery

    private func discoverApps() -> [AppUpdateInfo] {
        let fm = FileManager.default
        var appPaths: [String] = []

        let directories = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
        ]

        for dir in directories {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                appPaths.append((dir as NSString).appendingPathComponent(item))
            }
        }

        var results: [AppUpdateInfo] = []

        for path in appPaths {
            let plistPath = (path as NSString).appendingPathComponent("Contents/Info.plist")
            guard let plist = NSDictionary(contentsOfFile: plistPath) else { continue }

            let name = (plist["CFBundleDisplayName"] as? String)
                ?? (plist["CFBundleName"] as? String)
                ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            let bundleId = plist["CFBundleIdentifier"] as? String ?? ""
            let version = plist["CFBundleShortVersionString"] as? String ?? "Unknown"

            let app = AppUpdateInfo(
                id: path,
                name: name,
                bundleId: bundleId,
                currentVersion: version,
                iconPath: path
            )
            results.append(app)
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Homebrew Outdated

    private func fetchHomebrewOutdated() -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "brew outdated --cask 2>/dev/null"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let names = output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return Set(names.map { $0.lowercased() })
        } catch {
            return []
        }
    }

    // MARK: - Individual Update Check

    private func checkUpdate(for app: AppUpdateInfo) async -> AppUpdateInfo {
        var updated = app

        // Check if it is an App Store app via receipt
        let receiptPath = (app.id as NSString).appendingPathComponent("Contents/_MASReceipt/receipt")
        let isAppStore = FileManager.default.fileExists(atPath: receiptPath)

        if isAppStore {
            updated.source = .appStore
            if let storeVersion = await fetchAppStoreVersion(bundleId: app.bundleId) {
                updated.latestVersion = storeVersion
                updated.updateAvailable = compareVersions(current: app.currentVersion, latest: storeVersion)
            }
        } else {
            // Check Homebrew
            let caskName = app.name
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            if homebrewOutdated.contains(caskName) {
                updated.source = .homebrew
                updated.updateAvailable = true
                updated.latestVersion = "Update available"
            } else {
                // Try to see if it is a known Homebrew cask
                let isCask = checkIfHomebrewCask(name: caskName)
                if isCask {
                    updated.source = .homebrew
                }
            }
        }

        return updated
    }

    // MARK: - App Store Lookup

    private func fetchAppStoreVersion(bundleId: String) async -> String? {
        guard !bundleId.isEmpty,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=us")
        else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let version = first["version"] as? String
            {
                return version
            }
        } catch {
            // Silently skip failures
        }
        return nil
    }

    // MARK: - Homebrew Cask Check

    private func checkIfHomebrewCask(name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "brew list --cask 2>/dev/null | grep -q '^\(name)$'"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Version Comparison

    private func compareVersions(current: String, latest: String) -> Bool {
        let currentParts = current.components(separatedBy: ".").compactMap { Int($0) }
        let latestParts = latest.components(separatedBy: ".").compactMap { Int($0) }
        let maxLen = max(currentParts.count, latestParts.count)

        for i in 0..<maxLen {
            let c = i < currentParts.count ? currentParts[i] : 0
            let l = i < latestParts.count ? latestParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }

    // MARK: - Brew Upgrade

    func upgradeAllHomebrew() {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "brew upgrade --cask 2>&1"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()

            await MainActor.run { [weak self] in
                self?.checkForUpdates()
            }
        }
    }
}

// MARK: - View

struct AppUpdatesView: View {
    @StateObject private var checker = AppUpdateChecker()
    @State private var searchText = ""

    private var updatesAvailable: [AppUpdateInfo] {
        filtered.filter(\.updateAvailable)
    }

    private var upToDate: [AppUpdateInfo] {
        filtered.filter { !$0.updateAvailable && $0.latestVersion != nil }
    }

    private var unknown: [AppUpdateInfo] {
        filtered.filter { !$0.updateAvailable && $0.latestVersion == nil }
    }

    private var filtered: [AppUpdateInfo] {
        if searchText.isEmpty { return checker.apps }
        return checker.apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var homebrewUpdatesExist: Bool {
        updatesAvailable.contains { $0.source == .homebrew }
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "arrow.triangle.2.circlepath.circle", title: "Updates") {
                if checker.scanning {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("\(checker.scanProgress)/\(checker.scanTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    if !checker.apps.isEmpty {
                        Text("\(checker.apps.count) apps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if homebrewUpdatesExist {
                        Button {
                            checker.upgradeAllHomebrew()
                        } label: {
                            Label("Update All (Brew)", systemImage: "arrow.down.circle")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MacMartinColors.warning)
                    }
                    Button {
                        checker.checkForUpdates()
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacMartinColors.accent)
                    .disabled(checker.scanning)
                }
            }

            if !checker.apps.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField("Search apps...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(MacMartinColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(MacMartinColors.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            Divider()

            if checker.scanning && checker.apps.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView(value: Double(checker.scanProgress), total: max(Double(checker.scanTotal), 1))
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 280)
                        .tint(MacMartinColors.accent)
                    Text("Scanning \(checker.scanProgress) of \(checker.scanTotal) apps...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                }
                .padding()
            } else if checker.apps.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(MacMartinColors.accent.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "arrow.triangle.2.circlepath.circle")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(MacMartinColors.accent)
                    }
                    Text("Click \"Check for Updates\" to scan your apps")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if let error = checker.error {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(MacMartinColors.warning)
                    Text(error).foregroundStyle(.secondary).font(.caption)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if !updatesAvailable.isEmpty {
                            sectionHeader(
                                title: "Updates Available",
                                count: updatesAvailable.count,
                                color: MacMartinColors.warning
                            )

                            ForEach(Array(updatesAvailable.enumerated()), id: \.element.id) { i, app in
                                AppUpdateRow(app: app, highlighted: true)
                                    .appearAnimation(delay: Double(i) * 0.03)
                            }
                        }

                        if !upToDate.isEmpty {
                            sectionHeader(
                                title: "Up to Date",
                                count: upToDate.count,
                                color: MacMartinColors.success
                            )

                            ForEach(Array(upToDate.enumerated()), id: \.element.id) { i, app in
                                AppUpdateRow(app: app, highlighted: false)
                                    .appearAnimation(delay: Double(i) * 0.02)
                            }
                        }

                        if !unknown.isEmpty {
                            sectionHeader(
                                title: "Unknown",
                                count: unknown.count,
                                color: MacMartinColors.subtleText
                            )

                            ForEach(Array(unknown.enumerated()), id: \.element.id) { i, app in
                                AppUpdateRow(app: app, highlighted: false)
                                    .appearAnimation(delay: Double(i) * 0.015)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func sectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}

// MARK: - App Row

struct AppUpdateRow: View {
    let app: AppUpdateInfo
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            appIcon
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(app.bundleId)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Source badge
            Text(app.source.rawValue)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(sourceBadgeColor.opacity(0.15))
                .foregroundStyle(sourceBadgeColor)
                .clipShape(Capsule())

            // Versions
            VStack(alignment: .trailing, spacing: 2) {
                Text(app.currentVersion)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let latest = app.latestVersion {
                    Text(latest)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(app.updateAvailable ? MacMartinColors.warning : MacMartinColors.success)
                }
            }
            .frame(minWidth: 70, alignment: .trailing)

            // Status icon
            if app.updateAvailable {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(MacMartinColors.warning)
                    .font(.body)
            } else if app.latestVersion != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MacMartinColors.success)
                    .font(.body)
            } else {
                Image(systemName: "minus.circle")
                    .foregroundStyle(MacMartinColors.subtleText)
                    .font(.body)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(highlighted ? MacMartinColors.warning.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .cornerRadius(8)
        .hoverEffect()
    }

    @ViewBuilder
    private var appIcon: some View {
        if let iconPath = app.iconPath {
            let icon = NSWorkspace.shared.icon(forFile: iconPath)
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private var sourceBadgeColor: Color {
        switch app.source {
        case .appStore: return MacMartinColors.accent
        case .homebrew: return MacMartinColors.success
        case .unknown: return MacMartinColors.subtleText
        }
    }
}
