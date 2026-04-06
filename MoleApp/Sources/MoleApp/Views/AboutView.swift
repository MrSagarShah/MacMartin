import SwiftUI
import AppKit

struct AboutView: View {
    @EnvironmentObject private var license: LicenseManager
    @State private var email = ""
    @State private var subscribed = false
    @State private var subscribing = false

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader(icon: "info.circle", title: "About") {
                EmptyView()
            }

            ScrollView {
                VStack(spacing: 32) {
                    // Brand card
                    brandCard

                    // Newsletter / email signup
                    emailSignup

                    // Links
                    linksSection

                    // Open source acknowledgements (MIT)
                    acknowledgements

                    // App info
                    appInfo
                }
                .padding(24)
            }
        }
    }

    // MARK: - Brand

    private var brandCard: some View {
        VStack(spacing: 16) {
            MacMartinLogo(size: 72)
                .shadow(color: MacMartinColors.accent.opacity(0.3), radius: 16, y: 6)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text("MacMartin")
                        .font(.title.bold())
                    if license.tier == .pro {
                        ProBadge()
                    }
                }
                Text("Mac System Toolkit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Built by")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                if let url = URL(string: "https://krakelabsindia.com/") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Krakel Labs India")
                        .font(.headline)
                        .foregroundStyle(MacMartinColors.accent)
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Email Signup

    private var emailSignup: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Stay in the loop")
                    .font(.headline)
                Text("Get updates, tips, and early access to new features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if subscribed {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MacMartinColors.success)
                    Text("You're on the list!")
                        .fontWeight(.medium)
                }
                .padding(.vertical, 8)
                .transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 8) {
                    TextField("your@email.com", text: $email)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        subscribe()
                    } label: {
                        HStack(spacing: 4) {
                            if subscribing {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("Subscribe")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacMartinColors.accent)
                    .disabled(email.isEmpty || !email.contains("@") || subscribing)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .animation(.easeOut(duration: 0.3), value: subscribed)
    }

    // MARK: - Links

    private var linksSection: some View {
        VStack(spacing: 4) {
            linkRow(icon: "globe", title: "Website", subtitle: "krakelabsindia.com", url: "https://krakelabsindia.com/")
            linkRow(icon: "envelope", title: "Contact", subtitle: "hello@krakelabsindia.com", url: "mailto:hello@krakelabsindia.com")
        }
        .cardStyle(padding: 4)
    }

    private func linkRow(icon: String, title: String, subtitle: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(MacMartinColors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Open Source Acknowledgements

    private var acknowledgements: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 13))
                    .foregroundStyle(MacMartinColors.accent)
                Text("Open Source Licenses")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("MacMartin is built on the open-source Mole engine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Copyright (c) 2025 tw93")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Licensed under the MIT License.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - App Info

    private var appInfo: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                infoItem("Version", value: UpdateManager.currentVersion)
                infoItem("License", value: license.tier == .pro ? "Pro" : "Free")
                infoItem("Platform", value: "macOS 14+")
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }

    private func infoItem(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundStyle(.quaternary)
            Text(value)
        }
    }

    // MARK: - Actions

    private func subscribe() {
        subscribing = true

        // Save email locally. For a real backend, POST to your API here.
        // Example: POST https://krakelabsindia.com/api/subscribe?email=...
        UserDefaults.standard.set(email, forKey: "mole_subscriber_email")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            subscribing = false
            subscribed = true
        }
    }
}
