import SwiftUI

@main
struct MoleApp: App {
    @StateObject private var moleService = MoleService()
    @StateObject private var licenseManager = LicenseManager()
    @StateObject private var updateManager = UpdateManager()
    @StateObject private var menuBarMonitor = MenuBarMonitor()

    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
                .environmentObject(moleService)
                .environmentObject(licenseManager)
                .environmentObject(updateManager)
                .environmentObject(menuBarMonitor)
                .frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 960, height: 640)

        // Menu bar widget
        MenuBarExtra {
            MenuBarView()
                .environmentObject(menuBarMonitor)
                .environmentObject(moleService)
        } label: {
            MenuBarLabel()
                .environmentObject(menuBarMonitor)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject private var license: LicenseManager
    @EnvironmentObject private var updater: UpdateManager
    @State private var selectedTab: SidebarTab = .clean

    var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView(selection: $selectedTab)
            } detail: {
                detailView
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
            .sheet(isPresented: $license.showPaywall) {
                PaywallView()
            }

            if updater.updateRequired {
                ForceUpdateView()
            }
        }
        .onAppear {
            updater.checkForUpdates()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .clean:
            CleanView()
        case .status:
            StatusView()
        case .analyze:
            if license.tier == .pro {
                AnalyzeView()
            } else {
                LockedFeatureView(tab: .analyze)
            }
        case .uninstall:
            if license.tier == .pro {
                UninstallView()
            } else {
                LockedFeatureView(tab: .uninstall)
            }
        case .optimize:
            if license.tier == .pro {
                OptimizeView()
            } else {
                LockedFeatureView(tab: .optimize)
            }
        case .about:
            AboutView()
        }
    }
}

// MARK: - Force Update Overlay

struct ForceUpdateView: View {
    @EnvironmentObject private var updater: UpdateManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                MoleLogo(size: 64)

                Text("Update Required")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text(updater.updateMessage)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)

                VStack(spacing: 8) {
                    Text("Current: v\(UpdateManager.currentVersion)")
                        .foregroundStyle(.white.opacity(0.4))
                    if !updater.latestVersion.isEmpty {
                        Text("Latest: v\(updater.latestVersion)")
                            .foregroundStyle(MoleColors.success)
                    }
                }
                .font(.caption)

                Button {
                    updater.openDownload()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download Update")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(MoleColors.accent)
            }
            .padding(40)
        }
    }
}
