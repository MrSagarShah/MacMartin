import SwiftUI
import AppKit

struct LargeFileFinderView: View {
    @State private var files: [LargeFile] = []
    @State private var scanning = false
    @State private var scanPath = "~"
    @State private var minSizeMB: Double = 100
    @State private var progress = ""
    @State private var selectedFiles: Set<String> = []

    var totalSelectedSize: Int64 {
        files.filter { selectedFiles.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "doc.badge.arrow.up", title: "Large Files", iconColor: .orange) {
                if !files.isEmpty {
                    Text("\(files.count) files found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Controls
            controlBar

            if scanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Scanning for large files...")
                        .font(.subheadline.bold())
                    Text(progress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if files.isEmpty {
                emptyState
            } else {
                fileList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls

    private var controlBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Path selector
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(scanPath)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button("Browse") {
                        choosePath()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(MoleColors.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoleColors.cardBorder, lineWidth: 0.5))

                // Min size
                HStack(spacing: 4) {
                    Text("Min:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $minSizeMB) {
                        Text("50 MB").tag(50.0)
                        Text("100 MB").tag(100.0)
                        Text("250 MB").tag(250.0)
                        Text("500 MB").tag(500.0)
                        Text("1 GB").tag(1024.0)
                    }
                    .frame(width: 90)
                }

                Button {
                    startScan()
                } label: {
                    Label(scanning ? "Scanning..." : "Scan", systemImage: "magnifyingglass")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(scanning)
            }

            if !selectedFiles.isEmpty {
                HStack {
                    Text("\(selectedFiles.count) selected (\(formatBytes(bytes: totalSelectedSize)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        moveToTrash()
                    } label: {
                        Label("Move to Trash", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MoleColors.danger)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.orange)
            }
            .pulseEffect()
            Text("Find Large Files")
                .font(.title3.bold())
            Text("Scan a folder to find the biggest files eating your disk space.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            Spacer()
        }
    }

    // MARK: - File List

    private var fileList: some View {
        VStack(spacing: 0) {
            Divider()

            // Header
            HStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { selectedFiles.count == files.count },
                    set: { selectAll in
                        selectedFiles = selectAll ? Set(files.map(\.id)) : []
                    }
                )) { EmptyView() }
                .toggleStyle(.checkbox)
                .frame(width: 30)

                Text("File")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Type")
                    .frame(width: 60, alignment: .center)
                Text("Size")
                    .frame(width: 90, alignment: .trailing)
                Text("")
                    .frame(width: 40)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(files) { file in
                        fileRow(file)
                        Divider().opacity(0.3).padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    private func fileRow(_ file: LargeFile) -> some View {
        HStack(spacing: 0) {
            Toggle(isOn: Binding(
                get: { selectedFiles.contains(file.id) },
                set: { selected in
                    if selected { selectedFiles.insert(file.id) }
                    else { selectedFiles.remove(file.id) }
                }
            )) { EmptyView() }
            .toggleStyle(.checkbox)
            .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(file.directory)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(file.ext.uppercased())
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(MoleColors.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .frame(width: 60, alignment: .center)

            Text(formatBytes(bytes: file.sizeBytes))
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(file.sizeBytes > 1_073_741_824 ? .red : file.sizeBytes > 524_288_000 ? .orange : .primary)
                .frame(width: 90, alignment: .trailing)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
            } label: {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(MoleColors.accent)
            }
            .buttonStyle(.plain)
            .frame(width: 40)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(selectedFiles.contains(file.id) ? Color.orange.opacity(0.05) : Color.clear)
    }

    // MARK: - Actions

    private func choosePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: (scanPath as NSString).expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            scanPath = url.path
        }
    }

    private func startScan() {
        scanning = true
        files = []
        selectedFiles = []
        let path = (scanPath as NSString).expandingTildeInPath
        let minBytes = Int64(minSizeMB * 1024 * 1024)

        Task.detached(priority: .userInitiated) {
            let found = Self.scanLargeFiles(path: path, minBytes: minBytes) { dir in
                Task { @MainActor in
                    progress = dir
                }
            }
            await MainActor.run {
                files = found.sorted { $0.sizeBytes > $1.sizeBytes }
                scanning = false
                progress = ""
            }
        }
    }

    private func moveToTrash() {
        let toDelete = files.filter { selectedFiles.contains($0.id) }
        var freedBytes: Int64 = 0
        let fm = FileManager.default
        for file in toDelete {
            do {
                try fm.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                freedBytes += file.sizeBytes
            } catch {
                // Skip files we can't trash
            }
        }
        files.removeAll { selectedFiles.contains($0.id) }

        // Record stats
        if freedBytes > 0 {
            StatsManager.shared.record(
                source: .clean,
                bytesFreed: freedBytes,
                itemCount: toDelete.count,
                detail: "Large files"
            )
        }
        selectedFiles = []
    }

    // MARK: - Scanner

    private static func scanLargeFiles(path: String, minBytes: Int64, progress: @escaping (String) -> Void) -> [LargeFile] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [LargeFile] = []
        var count = 0

        for case let url as URL in enumerator {
            count += 1
            if count % 500 == 0 {
                progress(url.deletingLastPathComponent().lastPathComponent)
            }

            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  Int64(size) >= minBytes else { continue }

            results.append(LargeFile(
                name: url.lastPathComponent,
                path: url.path,
                directory: url.deletingLastPathComponent().path,
                ext: url.pathExtension,
                sizeBytes: Int64(size)
            ))
        }

        return results
    }
}

// MARK: - Model

struct LargeFile: Identifiable {
    let name: String
    let path: String
    let directory: String
    let ext: String
    let sizeBytes: Int64

    var id: String { path }
}
