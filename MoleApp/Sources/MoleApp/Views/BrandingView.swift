import SwiftUI

struct MacMartinLogo: View {
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [MacMartinColors.accent, Color(red: 0.2, green: 0.35, blue: 0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

struct SidebarHeader: View {
    @EnvironmentObject private var license: LicenseManager

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                MacMartinLogo(size: 34)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("MacMartin")
                            .font(.headline)
                        if license.tier == .pro {
                            ProBadge()
                        }
                    }
                    Text("Mac System Toolkit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if license.tier == .free {
                Button {
                    license.showPaywall = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("Upgrade to MacMartin Pro")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .opacity(0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
