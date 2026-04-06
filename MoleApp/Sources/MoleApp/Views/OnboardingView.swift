import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var license: LicenseManager
    @Binding var isComplete: Bool
    @State private var currentPage = 0

    private let totalPages = 4

    var body: some View {
        ZStack {
            // Full-bleed background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.12),
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                    Color(red: 0.06, green: 0.06, blue: 0.14),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle accent orb behind content
            Circle()
                .fill(MacMartinColors.accent.opacity(0.06))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(y: -40)

            VStack(spacing: 0) {
                // Page content
                Group {
                    switch currentPage {
                    case 0: welcomePage
                    case 1: featuresPage
                    case 2: proPage
                    default: readyPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentPage)

                // Bottom navigation
                bottomBar
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentPage)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? MacMartinColors.accent : Color.white.opacity(0.15))
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.35), value: currentPage)
                }
            }

            Spacer()

            if currentPage < totalPages - 1 {
                HStack(spacing: 16) {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.3))
                    .font(.subheadline)

                    Button {
                        currentPage += 1
                    } label: {
                        HStack(spacing: 5) {
                            Text("Continue")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(MacMartinColors.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    completeOnboarding()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Get Started")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(MacMartinColors.success)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 32)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            MacMartinLogo(size: 88)
                .shadow(color: MacMartinColors.accent.opacity(0.5), radius: 30, y: 10)

            VStack(spacing: 10) {
                Text("Welcome to")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
                Text("MacMartin")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text("Clean, optimize, and monitor your Mac.\nAll in one beautiful app.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            HStack(spacing: 32) {
                statBadge(value: "11", label: "Tools", icon: "wrench.and.screwdriver")
                statBadge(value: "24/7", label: "Monitor", icon: "heart.text.square")
                statBadge(value: "1-Click", label: "Clean", icon: "sparkles")
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }

    private func statBadge(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(MacMartinColors.accent)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Page 2: Features

    private var featuresPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Everything you need")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Powerful tools, zero complexity")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                featureCard(icon: "trash", title: "Clean", desc: "Caches & junk", color: .blue)
                featureCard(icon: "heart.text.square", title: "Status", desc: "Live metrics", color: .green)
                featureCard(icon: "chart.pie", title: "Analyze", desc: "Disk usage", color: .orange)
                featureCard(icon: "xmark.app", title: "Uninstall", desc: "Remove apps", color: .red)
                featureCard(icon: "doc.on.doc", title: "Duplicates", desc: "Find copies", color: .purple)
                featureCard(icon: "eye.slash", title: "Privacy", desc: "Clear traces", color: .pink)
                featureCard(icon: "power", title: "Startup", desc: "Login items", color: .cyan)
                featureCard(icon: "arrow.triangle.2.circlepath.circle", title: "Updates", desc: "App versions", color: .teal)
                featureCard(icon: "bell.badge", title: "Alerts", desc: "Smart notify", color: .yellow)
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    private func featureCard(icon: String, title: String, desc: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.9))
            Text(desc)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Page 3: Pro Upsell

    private var proPage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.15), Color.clear],
                            center: .center, startRadius: 0, endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("MacMartin")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    ProBadge()
                }
                Text("Unlock the full toolkit")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }

            // Pro features list
            VStack(spacing: 6) {
                proRow("Disk Analyzer & Duplicate Finder")
                proRow("App Uninstaller & Update Checker")
                proRow("Privacy Sweep & Startup Manager")
                proRow("System Optimizer (14 tasks)")
            }
            .padding(.horizontal, 60)

            HStack(spacing: 16) {
                Button("Maybe Later") {
                    currentPage += 1
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.3))
                .font(.subheadline)

                Button {
                    license.showPaywall = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("Upgrade to Pro")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(colors: [.orange, Color(red: 1, green: 0.6, blue: 0.2)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
    }

    private func proRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Page 4: Ready

    private var readyPage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MacMartinColors.success.opacity(0.15), Color.clear],
                            center: .center, startRadius: 0, endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(MacMartinColors.success)
            }

            VStack(spacing: 8) {
                Text("You're all set!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("MacMartin is running. Your Mac is in good hands.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 20) {
                readyBadge(icon: "cpu", text: "Menu bar active")
                readyBadge(icon: "bell.badge", text: "Alerts enabled")
                readyBadge(icon: "shield.checkered", text: "Safe & private")
            }

            Spacer()
            Spacer()
        }
    }

    private func readyBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(MacMartinColors.accent)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
    }

    // MARK: - Action

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "macmartin_onboarding_complete")
        withAnimation(.easeOut(duration: 0.3)) {
            isComplete = true
        }
    }
}
