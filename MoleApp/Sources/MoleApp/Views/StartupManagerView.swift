import SwiftUI
import Foundation

// MARK: - Model

struct StartupItem: Identifiable {
    let id: String
    let name: String
    let path: String
    let source: String  // "Login Item", "Launch Agent", "Launch Daemon"
    var enabled: Bool
    let isSystem: Bool   // true if in /Library (not user-level)
}

// MARK: - View

struct StartupManagerView: View {
    @EnvironmentObject private var mole: MacMartinService
    @State private var items: [StartupItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var togglingIds: Set<String> = []
    @State private var searchText = ""
    @State private var refreshRotation = 0.0

    private var filteredItems: [StartupItem] {
        if searchText.isEmpty { return items }
        let query = searchText.lowercased()
        return items.filter {
            $0.name.lowercased().contains(query) || $0.path.lowercased().contains(query)
        }
    }

    private var loginItems: [StartupItem] {
        filteredItems.filter { $0.source == "Login Item" }
    }

    private var launchAgents: [StartupItem] {
        filteredItems.filter { $0.source == "Launch Agent" }
    }

    private var launchDaemons: [StartupItem] {
        filteredItems.filter { $0.source == "Launch Daemon" }
    }

    private var enabledCount: Int {
        items.filter(\.enabled).count
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "power", title: "Startup") {
                HStack(spacing: 8) {
                    Text("\(enabledCount) active")
                        .font(.caption)
                        .foregroundStyle(MacMartinColors.subtleText)

                    Button {
                        refreshRotation += 360
                        loadItems()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(refreshRotation))
                            .animation(.easeInOut(duration: 0.5), value: refreshRotation)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(loading)
                }
            }

            if loading && items.isEmpty {
                loadingView
            } else if let error, items.isEmpty {
                errorView(error)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        searchBar
                            .appearAnimation(delay: 0)

                        if !loginItems.isEmpty {
                            sectionCard(
                                title: "Login Items",
                                icon: "person.crop.circle",
                                color: MacMartinColors.accent,
                                items: loginItems,
                                baseDelay: 0.05
                            )
                        }

                        if !launchAgents.isEmpty {
                            sectionCard(
                                title: "Launch Agents",
                                icon: "gearshape.2",
                                color: MacMartinColors.warning,
                                items: launchAgents,
                                baseDelay: 0.1
                            )
                        }

                        if !launchDaemons.isEmpty {
                            sectionCard(
                                title: "Launch Daemons",
                                icon: "lock.shield",
                                color: MacMartinColors.danger,
                                items: launchDaemons,
                                baseDelay: 0.15
                            )
                        }

                        if filteredItems.isEmpty && !searchText.isEmpty {
                            emptySearchView
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadItems() }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MacMartinColors.subtleText)
                .font(.system(size: 13))
            TextField("Filter startup items...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
        }
        .padding(10)
        .background(MacMartinColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MacMartinColors.cardBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Section Card

    private func sectionCard(
        title: String,
        icon: String,
        color: Color,
        items: [StartupItem],
        baseDelay: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(items.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MacMartinColors.subtleText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(MacMartinColors.cardBg)
                    .clipShape(Capsule())
            }

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                itemRow(item, color: color)
                    .hoverEffect()
                    .appearAnimation(delay: baseDelay + Double(index) * 0.03)

                if index < items.count - 1 {
                    Divider().opacity(0.3)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Item Row

    private func itemRow(_ item: StartupItem, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: item.source == "Login Item" ? "app" : "terminal")
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if item.isSystem {
                        Text("System")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(MacMartinColors.warning)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(MacMartinColors.warning.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(item.source)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MacMartinColors.subtleText)

            if togglingIds.contains(item.id) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 36)
            } else {
                Toggle("", isOn: bindingFor(item))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .tint(MacMartinColors.success)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Loading & Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Scanning startup items...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(MacMartinColors.warning)
            Text("Failed to load startup items")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            Button("Retry") { loadItems() }
                .buttonStyle(.borderedProminent)
                .tint(MacMartinColors.accent)
            Spacer()
        }
        .padding()
    }

    private var emptySearchView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(MacMartinColors.subtleText)
            Text("No items matching \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Toggle Binding

    private func bindingFor(_ item: StartupItem) -> Binding<Bool> {
        Binding<Bool>(
            get: { item.enabled },
            set: { newValue in
                toggleItem(item, enable: newValue)
            }
        )
    }

    // MARK: - Data Loading

    private func loadItems() {
        loading = true
        error = nil
        Task {
            do {
                var scanned: [StartupItem] = []

                async let agents = scanLaunchDirectory(
                    NSHomeDirectory() + "/Library/LaunchAgents",
                    source: "Launch Agent",
                    isSystem: false
                )
                async let systemAgents = scanLaunchDirectory(
                    "/Library/LaunchAgents",
                    source: "Launch Agent",
                    isSystem: true
                )
                async let daemons = scanLaunchDirectory(
                    "/Library/LaunchDaemons",
                    source: "Launch Daemon",
                    isSystem: true
                )
                async let loginItemNames = fetchGUILoginItems()

                let agentResults = await agents
                let systemAgentResults = await systemAgents
                let daemonResults = await daemons
                let guiItems = await loginItemNames

                scanned.append(contentsOf: agentResults)
                scanned.append(contentsOf: systemAgentResults)
                scanned.append(contentsOf: daemonResults)

                for name in guiItems {
                    let loginItem = StartupItem(
                        id: "loginitem-\(name)",
                        name: name,
                        path: "GUI Login Item",
                        source: "Login Item",
                        enabled: true,
                        isSystem: false
                    )
                    scanned.append(loginItem)
                }

                scanned.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                items = scanned
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    // MARK: - Plist Scanning

    private func scanLaunchDirectory(
        _ directoryPath: String,
        source: String,
        isSystem: Bool
    ) async -> [StartupItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fm = FileManager.default
                var results: [StartupItem] = []

                guard let contents = try? fm.contentsOfDirectory(atPath: directoryPath) else {
                    continuation.resume(returning: [])
                    return
                }

                for file in contents where file.hasSuffix(".plist") {
                    let fullPath = (directoryPath as NSString).appendingPathComponent(file)

                    guard let data = fm.contents(atPath: fullPath),
                          let plist = try? PropertyListSerialization.propertyList(
                              from: data, options: [], format: nil
                          ) as? [String: Any] else {
                        continue
                    }

                    let label = plist["Label"] as? String ?? file.replacingOccurrences(of: ".plist", with: "")
                    let programArgs = plist["ProgramArguments"] as? [String]
                    let program = plist["Program"] as? String
                    let binaryPath = programArgs?.first ?? program ?? fullPath
                    let runAtLoad = plist["RunAtLoad"] as? Bool ?? false
                    let disabled = plist["Disabled"] as? Bool ?? false

                    let displayName = extractDisplayName(from: label)

                    let item = StartupItem(
                        id: fullPath,
                        name: displayName,
                        path: binaryPath,
                        source: source,
                        enabled: runAtLoad && !disabled,
                        isSystem: isSystem
                    )
                    results.append(item)
                }

                continuation.resume(returning: results)
            }
        }
    }

    private func extractDisplayName(from label: String) -> String {
        // "com.apple.bird" -> "Bird", "org.mozilla.firefox" -> "Firefox"
        let parts = label.components(separatedBy: ".")
        guard let last = parts.last, !last.isEmpty else { return label }
        // Capitalize the first letter
        return last.prefix(1).uppercased() + last.dropFirst()
    }

    // MARK: - GUI Login Items

    private func fetchGUILoginItems() async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = [
                    "-e",
                    "tell application \"System Events\" to get the name of every login item",
                ]
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = (String(data: data, encoding: .utf8) ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !output.isEmpty, process.terminationStatus == 0 else {
                        continuation.resume(returning: [])
                        return
                    }

                    // osascript returns comma-separated list
                    let names = output
                        .components(separatedBy: ", ")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    continuation.resume(returning: names)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Toggle Enable/Disable

    private func toggleItem(_ item: StartupItem, enable: Bool) {
        guard !togglingIds.contains(item.id) else { return }
        togglingIds.insert(item.id)

        Task {
            let success: Bool

            if item.source == "Login Item" {
                // GUI login items cannot be toggled via launchctl
                success = false
            } else {
                success = await toggleLaunchItem(
                    plistPath: item.id,
                    enable: enable,
                    isSystem: item.isSystem
                )
            }

            if success {
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].enabled = enable
                }
            }

            togglingIds.remove(item.id)
        }
    }

    private func toggleLaunchItem(
        plistPath: String,
        enable: Bool,
        isSystem: Bool
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let domain = isSystem ? "system" : "gui/\(getuid())"
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/launchctl")

                if enable {
                    process.arguments = ["bootstrap", domain, plistPath]
                } else {
                    process.arguments = ["bootout", domain, plistPath]
                }

                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
