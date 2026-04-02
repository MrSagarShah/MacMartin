import SwiftUI

struct OptimizeView: View {
    @EnvironmentObject private var mole: MoleService
    @State private var running = false
    @State private var output: String = ""
    @State private var error: String?

    private let tasks: [(icon: String, name: String, desc: String, color: Color)] = [
        ("network", "DNS & Spotlight Check", "Verify DNS resolution and Spotlight database", .blue),
        ("folder.badge.gearshape", "Finder Cache Refresh", "Clear Finder caches and refresh views", .cyan),
        ("doc.badge.gearshape", "App State Cleanup", "Remove saved application state data", .purple),
        ("wrench.and.screwdriver", "Broken Config Repair", "Fix corrupted preference files", .orange),
        ("wifi", "Network Cache Refresh", "Flush DNS and ARP caches", .blue),
        ("cylinder.split.1x2", "Database Optimization", "Vacuum SQLite databases for performance", .green),
        ("arrow.triangle.2.circlepath", "LaunchServices Repair", "Rebuild the launch services database", .indigo),
        ("textformat", "Font Cache Rebuild", "Clear and rebuild font caches", .pink),
        ("dock.rectangle", "Dock Refresh", "Restart Dock to fix visual glitches", .teal),
        ("memorychip", "Memory Optimization", "Release unused memory pressure", .mint),
        ("antenna.radiowaves.left.and.right", "Network Stack Refresh", "Reset network configuration caches", .blue),
        ("lock.shield", "Permission Repair", "Fix disk permission issues", .yellow),
        ("wave.3.right", "Bluetooth Refresh", "Reset Bluetooth module caches", .cyan),
        ("magnifyingglass", "Spotlight Optimization", "Optimize Spotlight search index", .purple),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "gauge.with.dots.needle.33percent", title: "Optimize") {
                if running { ProgressView().scaleEffect(0.7) }
                Button {
                    runOptimize()
                } label: {
                    Label("Run All", systemImage: "play.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(MoleColors.accent)
                .disabled(running)
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(tasks.enumerated()), id: \.element.name) { i, task in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(task.color.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                Image(systemName: task.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(task.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.name)
                                    .font(.subheadline.weight(.medium))
                                Text(task.desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(MoleColors.cardBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(MoleColors.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .hoverEffect()
                        .appearAnimation(delay: Double(i) * 0.03)
                    }
                }
                .padding(16)
            }

            if !output.isEmpty {
                Divider()
                ScrollView {
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 160)
                .background(MoleColors.cardBg)
            }

            if let error {
                HStack {
                    Text(error).foregroundStyle(MoleColors.danger).font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    private func runOptimize() {
        running = true
        error = nil
        output = ""
        Task {
            do {
                let result = try await mole.runOptimize()
                output = stripAnsi(result)
            } catch {
                self.error = error.localizedDescription
            }
            running = false
        }
    }
}
