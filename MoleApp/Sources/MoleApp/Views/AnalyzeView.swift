import SwiftUI

struct AnalyzeView: View {
    @EnvironmentObject private var mole: MacMartinService
    @State private var result: AnalyzeResult?
    @State private var currentPath: String = NSHomeDirectory()
    @State private var pathHistory: [String] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "chart.pie", title: "Analyze") {
                if loading { ProgressView().scaleEffect(0.7) }
            }

            // Path bar
            HStack(spacing: 8) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(pathHistory.isEmpty ? Color.gray : MacMartinColors.accent)
                .disabled(pathHistory.isEmpty)

                TextField("Path", text: $currentPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.subheadline, design: .monospaced))
                    .onSubmit { analyze() }

                Button("Analyze") { analyze() }
                    .buttonStyle(.borderedProminent)
                    .tint(MacMartinColors.accent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()

            if let result {
                VStack(spacing: 0) {
                    HStack {
                        Text("Total: **\(formatBytes(bytes: result.totalSize))**")
                        Text("| \(result.totalFiles) files")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .font(.caption)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { i, entry in
                                DiskEntryRow(
                                    entry: entry,
                                    maxSize: sortedEntries.first?.size ?? 1
                                ) {
                                    if entry.isDir {
                                        navigateTo(entry.path)
                                    }
                                }
                                .appearAnimation(delay: Double(i) * 0.02)
                            }
                        }
                        .padding(12)
                    }
                }
            } else if let error {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(MacMartinColors.warning)
                    Text(error).foregroundStyle(.secondary).font(.caption)
                    Spacer()
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(MacMartinColors.accent.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "chart.pie")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(MacMartinColors.accent)
                    }
                    Text("Enter a path and click Analyze")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .onAppear { analyze() }
    }

    private var sortedEntries: [DiskEntry] {
        (result?.entries ?? []).sorted { $0.size > $1.size }
    }

    private func analyze() {
        loading = true
        error = nil
        Task {
            do {
                result = try await mole.analyzeDirectory(currentPath)
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func navigateTo(_ path: String) {
        pathHistory.append(currentPath)
        currentPath = path
        analyze()
    }

    private func goBack() {
        guard let prev = pathHistory.popLast() else { return }
        currentPath = prev
        analyze()
    }
}

struct DiskEntryRow: View {
    let entry: DiskEntry
    let maxSize: Int64
    let onDoubleTap: () -> Void

    private var fraction: Double {
        guard maxSize > 0 else { return 0 }
        return Double(entry.size) / Double(maxSize)
    }

    private var color: Color {
        if fraction > 0.5 { return MacMartinColors.danger }
        if fraction > 0.2 { return MacMartinColors.warning }
        return MacMartinColors.accent
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.isDir ? "folder.fill" : "doc")
                .foregroundStyle(entry.isDir ? .blue : .secondary)
                .frame(width: 18)

            Text(entry.name)
                .lineLimit(1)
                .font(.subheadline)

            Spacer()

            SizeBar(fraction: fraction, color: color)
                .frame(width: 80)

            Text(entry.sizeFormatted)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onDoubleTap() }
        .cornerRadius(6)
    }
}
