import SwiftUI
import UserNotifications

@main
struct MoleApp: App {
    @StateObject private var moleService = MoleService()
    @StateObject private var licenseManager = LicenseManager()
    @StateObject private var updateManager = UpdateManager()
    @StateObject private var menuBarMonitor = MenuBarMonitor()
    @StateObject private var alertManager = AlertManager()

    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
                .environmentObject(moleService)
                .environmentObject(licenseManager)
                .environmentObject(updateManager)
                .environmentObject(menuBarMonitor)
                .environmentObject(alertManager)
                .frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandMenu("Navigate") {
                Button("Clean") { NotificationCenter.default.post(name: .switchTab, object: SidebarTab.clean) }
                    .keyboardShortcut("1")
                Button("Status") { NotificationCenter.default.post(name: .switchTab, object: SidebarTab.status) }
                    .keyboardShortcut("2")
                Button("Analyze") { NotificationCenter.default.post(name: .switchTab, object: SidebarTab.analyze) }
                    .keyboardShortcut("3")
                Button("Uninstall") { NotificationCenter.default.post(name: .switchTab, object: SidebarTab.uninstall) }
                    .keyboardShortcut("4")
                Button("Optimize") { NotificationCenter.default.post(name: .switchTab, object: SidebarTab.optimize) }
                    .keyboardShortcut("5")
            }
        }

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
    @State private var onboardingComplete = UserDefaults.standard.bool(forKey: "macmartin_onboarding_complete")

    var body: some View {
        ZStack {
            if !onboardingComplete {
                OnboardingView(isComplete: $onboardingComplete)
            } else {
                NavigationSplitView {
                    SidebarView(selection: $selectedTab)
                } detail: {
                    detailView
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                .sheet(isPresented: $license.showPaywall) {
                    PaywallView()
                }
                .transition(.opacity)
            }

            if updater.updateRequired {
                ForceUpdateView()
            }
        }
        .onAppear {
            updater.checkForUpdates()
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { notif in
            if let tab = notif.object as? SidebarTab {
                selectedTab = tab
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if selectedTab.isPro && license.tier == .free {
            LockedFeatureView(tab: selectedTab)
        } else {
            switch selectedTab {
            case .clean: CleanView()
            case .status: StatusView()
            case .analyze: AnalyzeView()
            case .uninstall: UninstallView()
            case .optimize: OptimizeView()
            case .duplicates: DuplicateFinderView()
            case .privacy: PrivacySweepView()
            case .startup: StartupManagerView()
            case .updates: AppUpdatesView()
            case .storage: StorageBreakdownView()
            case .alerts: AlertsView()
            case .about: AboutView()
            }
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
