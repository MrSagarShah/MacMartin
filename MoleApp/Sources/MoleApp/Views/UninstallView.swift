import SwiftUI

struct UninstallView: View {
    @EnvironmentObject private var mole: MacMartinService
    @State private var apps: [InstalledApp] = []
    @State private var loading = false
    @State private var searchText = ""
    @State private var error: String?

    var filteredApps: [InstalledApp] {
        if searchText.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var selectedApps: [InstalledApp] {
        apps.filter(\.selected)
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "xmark.app", title: "Uninstall") {
                if !apps.isEmpty {
                    Text("\(apps.count) apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !selectedApps.isEmpty {
                    Text("\(selectedApps.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        // TODO: uninstall
                    } label: {
                        Label("Uninstall", systemImage: "trash")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacMartinColors.danger)
                }
                if apps.isEmpty {
                    Button {
                        loadApps()
                    } label: {
                        Label("Load Apps", systemImage: "arrow.clockwise")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacMartinColors.accent)
                }
            }

            if !apps.isEmpty {
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

            if loading {
                VStack {
                    Spacer()
                    ProgressView("Loading installed apps...")
                    Spacer()
                }
            } else if apps.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(MacMartinColors.accent.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "app.badge")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(MacMartinColors.accent)
                    }
                    Text("Load your installed apps to get started")
                        .foregroundStyle(.secondary)
                    if let error {
                        Text(error).foregroundStyle(MacMartinColors.danger).font(.caption)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredApps, id: \.path) { app in
                            AppRow(app: app) { newValue in
                                if let idx = apps.firstIndex(where: { $0.path == app.path }) {
                                    apps[idx].selected = newValue
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .onAppear {
            if apps.isEmpty { loadApps() }
        }
    }

    private func loadApps() {
        loading = true
        error = nil
        Task {
            do {
                apps = try await mole.listApps()
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

struct AppRow: View {
    let app: InstalledApp
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { app.selected },
                set: { onToggle($0) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .fontWeight(.medium)
                    .font(.subheadline)
                Text(app.bundleId)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(app.sizeHuman)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(app.lastUsed)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(app.selected ? MacMartinColors.accent.opacity(0.06) : Color.clear)
        .cornerRadius(8)
    }
}
