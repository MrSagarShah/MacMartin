import SwiftUI

// MARK: - Locked Feature (shown in detail area for gated tabs)

struct LockedFeatureView: View {
    @EnvironmentObject private var license: LicenseManager
    let tab: SidebarTab

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(categoryColor(tab.rawValue).opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1.0 : 0.8)

                Image(systemName: tab.icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(categoryColor(tab.rawValue).opacity(0.5))

                // Lock badge
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .offset(x: 40, y: 40)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)

            VStack(spacing: 10) {
                Text(tab.rawValue)
                    .font(.title2.bold())
                Text(tab.proDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

            Button {
                license.showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Unlock with MacMartin Pro")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                        .opacity(0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)

            // Feature preview hints
            HStack(spacing: 20) {
                featureHint(icon: "bolt.fill", text: "Fast")
                featureHint(icon: "lock.shield", text: "Secure")
                featureHint(icon: "arrow.clockwise", text: "Updates")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { appeared = true }
    }

    private func featureHint(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text)
        }
    }
}

// MARK: - Paywall Sheet

struct PaywallView: View {
    @EnvironmentObject private var license: LicenseManager
    @Environment(\.dismiss) private var dismiss
    @State private var licenseKey = ""
    @State private var errorMessage: String?
    @State private var isActivating = false
    @State private var justActivated = false

    var body: some View {
        VStack(spacing: 0) {
            // Branded header
            ZStack {
                LinearGradient(
                    colors: [MoleColors.accent.opacity(0.12), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 150)

                VStack(spacing: 12) {
                    MoleLogo(size: 60)
                        .shadow(color: MoleColors.accent.opacity(0.3), radius: 12, y: 4)
                    HStack(spacing: 6) {
                        Text("MacMartin")
                            .font(.title.bold())
                        ProBadge()
                    }
                    Text("Unlock the full Mac toolkit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            ScrollView {
                VStack(spacing: 28) {
                    // What's included
                    featureGrid

                    Divider().padding(.horizontal, 24)

                    // Activation
                    activationSection

                    // Crypto
                    cryptoSection
                }
                .padding(.vertical, 24)
            }

            Divider()

            // Footer
            HStack {
                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
                if license.tier == .pro {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(MoleColors.success)
                            .frame(width: 6, height: 6)
                        Text("Licensed")
                            .font(.caption)
                            .foregroundStyle(MoleColors.success)
                        if let email = license.licenseEmail {
                            Text("(\(email))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480, height: 620)
    }

    // MARK: - Feature Grid

    private var featureGrid: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Features")
                    .font(.headline)
                Spacer()
                HStack(spacing: 0) {
                    Text("Free")
                        .frame(width: 50)
                    Text("Pro")
                        .frame(width: 50)
                        .foregroundStyle(.orange)
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 0) {
                featureRow("Clean caches & logs", free: true, pro: true)
                Divider().padding(.leading, 12)
                featureRow("System monitoring", free: true, pro: true)
                Divider().padding(.leading, 12)
                featureRow("Disk space analyzer", free: false, pro: true)
                Divider().padding(.leading, 12)
                featureRow("App uninstaller", free: false, pro: true)
                Divider().padding(.leading, 12)
                featureRow("System optimizer", free: false, pro: true)
            }
            .cardStyle(padding: 0)
            .padding(.horizontal, 20)
        }
    }

    private func featureRow(_ name: String, free: Bool, pro: Bool) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 0) {
                checkIcon(free)
                    .frame(width: 50)
                checkIcon(pro)
                    .frame(width: 50)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
    }

    private func checkIcon(_ enabled: Bool) -> some View {
        Image(systemName: enabled ? "checkmark.circle.fill" : "minus.circle")
            .font(.system(size: 14))
            .foregroundStyle(enabled ? MoleColors.success : Color.gray.opacity(0.3))
    }

    // MARK: - Activation

    private var activationSection: some View {
        VStack(spacing: 14) {
            Label("License Key", systemImage: "key.fill")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                TextField("Paste your license key here", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.subheadline, design: .monospaced))

                Button {
                    activateLicense()
                } label: {
                    HStack(spacing: 6) {
                        if isActivating {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else if justActivated {
                            Image(systemName: "checkmark")
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        Text(justActivated ? "Activated!" : "Activate License")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(justActivated ? MoleColors.success : MoleColors.accent)
                .disabled(licenseKey.isEmpty || isActivating || justActivated)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(MoleColors.danger)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeOut(duration: 0.2), value: errorMessage)
        .animation(.easeOut(duration: 0.3), value: justActivated)
    }

    // MARK: - Crypto

    private var cryptoSection: some View {
        VStack(spacing: 12) {
            Label("Pay with Crypto", systemImage: "bitcoinsign.circle.fill")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                license.activateViaCrypto()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Text("Buy License with Crypto")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)

            Text("Accepts ETH, SOL, USDC, BTC via Coinbase Commerce. You'll receive a license key by email.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Action

    private func activateLicense() {
        isActivating = true
        errorMessage = nil

        // Small delay for perceived work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if let err = license.activate(license: licenseKey) {
                errorMessage = err
                isActivating = false
            } else {
                isActivating = false
                justActivated = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
        }
    }
}
