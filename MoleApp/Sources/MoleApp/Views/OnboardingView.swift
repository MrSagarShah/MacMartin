import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var license: LicenseManager
    @Binding var isComplete: Bool
    @State private var currentPage = 0

    private let totalPages = 4

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.14),
                    Color(red: 0.10, green: 0.10, blue: 0.20),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    proPage.tag(2)
                    readyPage.tag(3)
                }
                .tabViewStyle(.automatic)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom bar
                HStack {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { i in
                            Circle()
                                .fill(i == currentPage ? MoleColors.accent : Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .scaleEffect(i == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    Spacer()

                    // Navigation
                    if currentPage < totalPages - 1 {
                        HStack(spacing: 12) {
                            Button("Skip") {
                                completeOnboarding()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white.opacity(0.4))
                            .font(.subheadline)

                            Button {
                                withAnimation { currentPage += 1 }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Next")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(MoleColors.accent)
                        }
                    } else {
                        Button {
                            completeOnboarding()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Get Started")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MoleColors.success)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .frame(width: 640, height: 480)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            MoleLogo(size: 80)
                .shadow(color: MoleColors.accent.opacity(0.4), radius: 20, y: 8)
                .pulseEffect()

            Text("Welcome to MacMartin")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Your Mac's best friend. Clean, optimize, and monitor\nyour system — all in one app.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            HStack(spacing: 24) {
                welcomeStat(value: "11", label: "Tools")
                welcomeStat(value: "24/7", label: "Monitoring")
                welcomeStat(value: "1-Click", label: "Cleanup")
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(40)
    }

    private func welcomeStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(MoleColors.accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Page 2: Features

    private var featuresPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Everything you need")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                featureCard(icon: "trash", title: "Smart Clean", desc: "Remove caches & junk", color: .blue)
                featureCard(icon: "heart.text.square", title: "Live Status", desc: "CPU, RAM, disk, battery", color: .green)
                featureCard(icon: "chart.pie", title: "Disk Analyzer", desc: "Find what's using space", color: .orange)
                featureCard(icon: "xmark.app", title: "Uninstaller", desc: "Remove apps completely", color: .red)
                featureCard(icon: "doc.on.doc", title: "Duplicates", desc: "Find duplicate files", color: .purple)
                featureCard(icon: "eye.slash", title: "Privacy", desc: "Clear your traces", color: .pink)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(30)
    }

    private func featureCard(icon: String, title: String, desc: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Page 3: Pro Upsell

    private var proPage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 90, height: 90)
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
            }

            Text("Unlock MacMartin Pro")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Get full access to all tools and utilities.\nFree users get Clean + Status + Alerts.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 16) {
                proFeature("Disk Analyzer")
                proFeature("Duplicate Finder")
                proFeature("Privacy Sweep")
                proFeature("Startup Manager")
            }

            HStack(spacing: 12) {
                Button("Maybe Later") {
                    withAnimation { currentPage += 1 }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.4))
                .font(.subheadline)

                Button {
                    license.showPaywall = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Upgrade Now")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(40)
    }

    private func proFeature(_ name: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
            Text(name)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Page 4: Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MoleColors.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(MoleColors.success)
            }

            Text("You're all set!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("MacMartin is ready. Check your menu bar for\nlive CPU and memory monitoring.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            HStack(spacing: 20) {
                readyHint(icon: "cpu", text: "Menu bar widget active")
                readyHint(icon: "bell.badge", text: "Smart alerts enabled")
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(40)
    }

    private func readyHint(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(MoleColors.accent)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Action

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "macmartin_onboarding_complete")
        withAnimation(.easeOut(duration: 0.3)) {
            isComplete = true
        }
    }
}
