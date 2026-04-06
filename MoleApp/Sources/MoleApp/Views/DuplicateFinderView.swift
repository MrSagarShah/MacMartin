import CryptoKit
import SwiftUI

// MARK: - Models

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    let fileSize: Int64
    var files: [DuplicateFile]
}

struct DuplicateFile: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    var selected: Bool = false
}

// MARK: - Scanner

@MainActor
final class DuplicateScannerModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning(String)
        case hashing(String)
        case done
        case deleting
        case deleted(Int, Int64)
    }

    @Published var phase: Phase = .idle
    @Published var groups: [DuplicateGroup] = []
    @Published var progress: Double = 0
    @Published var error: String?

    var totalSelectedCount: Int {
        groups.reduce(0) { $0 + $1.files.filter(\.selected).count }
    }

    var totalSelectedBytes: Int64 {
        groups.reduce(Int64(0)) { sum, group in
            sum + Int64(group.files.filter(\.selected).count) * group.fileSize
        }
    }

    var totalWastedBytes: Int64 {
        groups.reduce(Int64(0)) { sum, group in
            sum + Int64(group.files.count - 1) * group.fileSize
        }
    }

    // MARK: - Scan

    func scan(directory: String) {
        groups = []
        error = nil
        progress = 0

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let url = URL(fileURLWithPath: directory)
                let fm = FileManager.default

                // Phase 1: Enumerate all files
                await self?.setPhase(.scanning("Enumerating files..."))

                guard let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    await self?.setError("Cannot access directory")
                    return
                }

                var fileSizeMap: [Int64: [URL]] = [:]
                var fileCount = 0

                for case let fileURL as URL in enumerator {
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    guard resourceValues?.isRegularFile == true else { continue }
                    guard let size = resourceValues?.fileSize, size > 0 else { continue }

                    let sizeKey = Int64(size)
                    fileSizeMap[sizeKey, default: []].append(fileURL)
                    fileCount += 1

                    if fileCount % 500 == 0 {
                        await self?.setPhase(.scanning("Scanned \(fileCount) files..."))
                    }
                }

                // Filter to only sizes with multiple files
                let candidates = fileSizeMap.filter { $0.value.count > 1 }
                let totalGroups = candidates.count

                if totalGroups == 0 {
                    await self?.finishWithNoResults()
                    return
                }

                // Phase 2: Hash files in same-size groups
                await self?.setPhase(.hashing("Hashing 0/\(totalGroups) groups..."))

                var duplicateGroups: [DuplicateGroup] = []
                var processed = 0

                for (fileSize, urls) in candidates {
                    // First pass: hash first 4KB for quick comparison
                    var partialHashMap: [String: [URL]] = [:]
                    for fileURL in urls {
                        if let hash = Self.hashFile(url: fileURL, limit: 4096) {
                            partialHashMap[hash, default: []].append(fileURL)
                        }
                    }

                    // Second pass: full hash only for files with matching partial hashes
                    let partialCandidates = partialHashMap.filter { $0.value.count > 1 }
                    for (_, matchingURLs) in partialCandidates {
                        var fullHashMap: [String: [URL]] = [:]
                        for fileURL in matchingURLs {
                            if let hash = Self.hashFile(url: fileURL, limit: nil) {
                                fullHashMap[hash, default: []].append(fileURL)
                            }
                        }

                        for (hash, duplicateURLs) in fullHashMap where duplicateURLs.count > 1 {
                            let files = duplicateURLs.map { url in
                                DuplicateFile(
                                    path: url.path,
                                    name: url.lastPathComponent
                                )
                            }
                            duplicateGroups.append(DuplicateGroup(
                                hash: String(hash.prefix(12)),
                                fileSize: fileSize,
                                files: files
                            ))
                        }
                    }

                    processed += 1
                    let p = Double(processed) / Double(totalGroups)
                    await self?.updateProgress(p, message: "Hashing \(processed)/\(totalGroups) groups...")
                }

                // Sort by wasted space descending
                duplicateGroups.sort { g1, g2 in
                    (Int64(g1.files.count - 1) * g1.fileSize) > (Int64(g2.files.count - 1) * g2.fileSize)
                }

                await self?.finishScan(groups: duplicateGroups)
            } catch {
                await self?.setError(error.localizedDescription)
            }
        }
    }

    // MARK: - Delete

    func deleteSelected() {
        let toDelete = groups.flatMap { $0.files.filter(\.selected) }
        guard !toDelete.isEmpty else { return }

        phase = .deleting
        let count = toDelete.count
        let bytes = totalSelectedBytes

        Task.detached(priority: .userInitiated) { [weak self] in
            let fm = FileManager.default
            for file in toDelete {
                try? fm.removeItem(atPath: file.path)
            }

            await MainActor.run {
                // Remove deleted files from groups, then remove empty groups
                self?.groups = (self?.groups ?? []).compactMap { group in
                    var g = group
                    g.files.removeAll { $0.selected }
                    return g.files.count > 1 ? g : nil
                }
                self?.phase = .deleted(count, bytes)

                StatsManager.shared.record(
                    source: .duplicates,
                    bytesFreed: bytes,
                    itemCount: count,
                    detail: "\(count) duplicate files"
                )
            }
        }
    }

    // MARK: - Auto-select

    func autoSelectAll() {
        for i in groups.indices {
            for j in groups[i].files.indices {
                groups[i].files[j].selected = j > 0
            }
        }
    }

    func deselectAll() {
        for i in groups.indices {
            for j in groups[i].files.indices {
                groups[i].files[j].selected = false
            }
        }
    }

    // MARK: - Helpers

    private nonisolated static func hashFile(url: URL, limit: Int?) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        let chunkSize = 65_536

        if let limit {
            if let data = try? handle.read(upToCount: limit) {
                hasher.update(data: data)
            }
        } else {
            while autoreleasepool(invoking: {
                guard let data = try? handle.read(upToCount: chunkSize), !data.isEmpty else { return false }
                hasher.update(data: data)
                return true
            }) {}
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func setPhase(_ phase: Phase) {
        self.phase = phase
    }

    private func setError(_ message: String) {
        error = message
        phase = .idle
    }

    private func updateProgress(_ value: Double, message: String) {
        progress = value
        phase = .hashing(message)
    }

    private func finishWithNoResults() {
        groups = []
        phase = .done
    }

    private func finishScan(groups: [DuplicateGroup]) {
        self.groups = groups
        progress = 1.0
        phase = .done
    }
}

// MARK: - View

struct DuplicateFinderView: View {
    @StateObject private var scanner = DuplicateScannerModel()
    @State private var directoryPath: String = ""
    @State private var expandedGroups: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            pathPicker

            switch scanner.phase {
            case .idle:
                idleView
            case .scanning(let message):
                progressView(message: message, indeterminate: true)
            case .hashing(let message):
                progressView(message: message, indeterminate: false)
            case .done:
                if scanner.groups.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            case .deleting:
                deletingView
            case .deleted(let count, let bytes):
                deletedView(count: count, bytes: bytes)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: scanner.phase)
    }

    // MARK: - Header

    private var header: some View {
        ViewHeader(icon: "doc.on.doc", title: "Duplicates") {
            if scanner.phase == .done && !scanner.groups.isEmpty {
                Button {
                    scanner.deleteSelected()
                } label: {
                    Label(
                        "Delete Selected (\(scanner.totalSelectedCount) files, \(formatBytes(bytes: scanner.totalSelectedBytes)))",
                        systemImage: "trash"
                    )
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(MoleColors.danger)
                .disabled(scanner.totalSelectedCount == 0)
            }
        }
    }

    // MARK: - Path Picker

    private var pathPicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(MoleColors.accent)
                    TextField("Choose a folder to scan...", text: $directoryPath)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MoleColors.cardBorder, lineWidth: 0.5)
                )

                Button("Browse") {
                    browseDirectory()
                }
                .buttonStyle(.bordered)

                Button {
                    scanner.scan(directory: directoryPath)
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(MoleColors.accent)
                .disabled(directoryPath.isEmpty || isScanning)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if let error = scanner.error {
                Text(error)
                    .foregroundStyle(MoleColors.danger)
                    .font(.caption)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            Divider()
        }
    }

    private var isScanning: Bool {
        switch scanner.phase {
        case .scanning, .hashing: return true
        default: return false
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MoleColors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(MoleColors.accent)
            }
            .pulseEffect()
            Text("Find Duplicate Files")
                .font(.title3.bold())
            Text("Choose a folder and scan to find duplicate files.\nCompares by content hash, not just file name.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Spacer()
        }
    }

    // MARK: - Progress

    private func progressView(message: String, indeterminate: Bool) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MoleColors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                if indeterminate {
                    ProgressView()
                        .scaleEffect(1.8)
                        .tint(MoleColors.accent)
                } else {
                    RingGauge(
                        value: scanner.progress,
                        size: 80,
                        lineWidth: 6,
                        color: MoleColors.accent,
                        label: "\(Int(scanner.progress * 100))%"
                    )
                }
            }
            Text("Scanning for Duplicates")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !indeterminate {
                ProgressView(value: scanner.progress)
                    .tint(MoleColors.accent)
                    .frame(maxWidth: 300)
            }
            Spacer()
        }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MoleColors.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(MoleColors.success)
            }
            Text("No Duplicates Found")
                .font(.title3.bold())
            Text("The selected folder has no duplicate files.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                Button("Auto-select All") {
                    scanner.autoSelectAll()
                }
                .buttonStyle(.plain)
                .foregroundStyle(MoleColors.accent)
                .font(.subheadline.weight(.medium))

                if scanner.totalSelectedCount > 0 {
                    Button("Deselect All") {
                        scanner.deselectAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.subheadline.weight(.medium))
                    .padding(.leading, 8)
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("\(scanner.groups.count)")
                        .fontWeight(.bold)
                        .foregroundStyle(MoleColors.accent)
                    Text("groups")
                        .foregroundStyle(.secondary)
                    Text("|")
                        .foregroundStyle(.quaternary)
                    Text("~\(formatBytes(bytes: scanner.totalWastedBytes)) wasted")
                        .fontWeight(.semibold)
                        .foregroundStyle(MoleColors.warning)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(scanner.groups.enumerated()), id: \.element.id) { index, group in
                        DuplicateGroupCard(
                            group: Binding(
                                get: { scanner.groups[index] },
                                set: { scanner.groups[index] = $0 }
                            ),
                            isExpanded: expandedGroups.contains(group.id),
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedGroups.contains(group.id) {
                                        expandedGroups.remove(group.id)
                                    } else {
                                        expandedGroups.insert(group.id)
                                    }
                                }
                            }
                        )
                        .hoverEffect()
                        .appearAnimation(delay: Double(index) * 0.03)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Deleting

    private var deletingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MoleColors.danger.opacity(0.1))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(MoleColors.danger)
            }
            Text("Deleting...")
                .font(.title3.bold())
            Text("Removing selected duplicate files")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Deleted

    private func deletedView(count: Int, bytes: Int64) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MoleColors.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(MoleColors.success)
            }
            Text("Deletion Complete")
                .font(.title3.bold())
            Text("Removed \(count) files, freed \(formatBytes(bytes: bytes))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !scanner.groups.isEmpty {
                Text("\(scanner.groups.count) duplicate groups remaining")
                    .font(.caption)
                    .foregroundStyle(MoleColors.warning)

                Button {
                    scanner.phase = .done
                } label: {
                    Label("Review Remaining", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
            }

            Button {
                scanner.scan(directory: directoryPath)
            } label: {
                Label("Scan Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .tint(MoleColors.accent)

            Spacer()
        }
    }

    // MARK: - Actions

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to scan for duplicate files"
        panel.prompt = "Scan"

        if panel.runModal() == .OK, let url = panel.url {
            directoryPath = url.path
        }
    }
}

// MARK: - Duplicate Group Card

struct DuplicateGroupCard: View {
    @Binding var group: DuplicateGroup
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    private var selectedCount: Int {
        group.files.filter(\.selected).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(MoleColors.accent.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(MoleColors.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.files.first?.name ?? "Unknown")
                            .fontWeight(.medium)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(formatBytes(bytes: group.fileSize))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(group.files.count) copies")
                                .font(.caption)
                                .foregroundStyle(MoleColors.warning)
                        }
                    }

                    Spacer()

                    if selectedCount > 0 {
                        Text("\(selectedCount) selected")
                            .font(.caption)
                            .foregroundStyle(MoleColors.danger)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(MoleColors.danger.opacity(0.12))
                            )
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(12)

            // Expanded file list
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(spacing: 0) {
                    // Auto-select button
                    HStack {
                        Button("Keep first, select rest") {
                            for i in group.files.indices {
                                group.files[i].selected = i > 0
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MoleColors.accent)
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Deselect all") {
                            for i in group.files.indices {
                                group.files[i].selected = false
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    ForEach(group.files.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            Toggle(isOn: $group.files[index].selected) {
                                EmptyView()
                            }
                            .toggleStyle(.checkbox)
                            .scaleEffect(0.85)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(group.files[index].name)
                                    .font(.subheadline)
                                    .fontWeight(index == 0 ? .medium : .regular)
                                Text(group.files[index].path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            if index == 0 && !group.files[index].selected {
                                Text("KEEP")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(MoleColors.success)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(MoleColors.success.opacity(0.12))
                                    )
                            }

                            if group.files[index].selected {
                                Text("DELETE")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(MoleColors.danger)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(MoleColors.danger.opacity(0.12))
                                    )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            group.files[index].selected
                                ? MoleColors.danger.opacity(0.04)
                                : Color.clear
                        )

                        if index < group.files.count - 1 {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selectedCount > 0 ? MoleColors.danger.opacity(0.02) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    selectedCount > 0 ? MoleColors.danger.opacity(0.15) : MoleColors.cardBorder,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
