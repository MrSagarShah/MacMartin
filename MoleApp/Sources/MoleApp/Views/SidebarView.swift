import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarTab
    @EnvironmentObject private var license: LicenseManager

    var body: some View {
        List(SidebarTab.allCases, selection: $selection) { tab in
            HStack {
                Label(tab.rawValue, systemImage: tab.icon)
                Spacer()
                if tab.isPro && license.tier == .free {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .tag(tab)
            .font(.subheadline)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        .safeAreaInset(edge: .top) {
            SidebarHeader()
                .padding(.bottom, 4)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Divider()
                Text("MacMartin v\(UpdateManager.currentVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
            }
        }
    }
}
