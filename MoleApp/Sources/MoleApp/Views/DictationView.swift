import SwiftUI

struct DictationView: View {
    @EnvironmentObject private var dictation: DictationService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusCard
                permissionsCard
                diagnosticsCard
                howItWorksCard
            }
            .padding(20)
        }
        .background(Color.black.opacity(0.001))
        .onAppear { dictation.refreshPermissions() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(MacMartinColors.accentGradient)
                Text("Dictation")
                    .font(.title2.bold())
            }
            Text("Press \(dictation.hotkeyLabel) anywhere on macOS to start dictating. Press again to stop and paste.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Toggle("Enable dictation", isOn: $dictation.enabled)
                    .toggleStyle(.switch)
                Spacer()
                statusBadge
            }
            Toggle("Show floating button", isOn: $dictation.showOverlay)
                .toggleStyle(.switch)
                .disabled(!dictation.enabled)

            HStack(spacing: 10) {
                pulseIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.subheadline.weight(.medium))
                    Text("Hotkey: \(dictation.hotkeyLabel) (press to start, press again to stop)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(dictation.status == .listening ? "Stop" : "Test") {
                    dictation.toggleRecording()
                }
                .disabled(!dictation.enabled || !canRecord)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Last transcription")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dictation.lastTranscription.isEmpty ? "(none yet)" : dictation.lastTranscription)
                    .font(.callout)
                    .foregroundStyle(dictation.lastTranscription.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(MacMartinColors.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
            }
        }
        .cardStyle()
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Diagnostics").font(.headline)
                Spacer()
                Text("samples: \(dictation.lastSampleCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if dictation.diagnostics.isEmpty {
                        Text("No events yet — press \(dictation.hotkeyLabel) to dictate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(dictation.diagnostics.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .frame(maxHeight: 140)
            .padding(8)
            .background(MacMartinColors.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .cardStyle()
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Permissions").font(.headline)
                Spacer()
                Button {
                    dictation.refreshPermissions()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            permissionRow(
                title: "Microphone",
                detail: "Capture audio while you dictate.",
                state: dictation.micPermission,
                action: { dictation.requestPermissions() }
            )
            permissionRow(
                title: "Accessibility",
                detail: "Required to paste text into the focused app.",
                state: dictation.accessibilityGranted ? .granted : .denied,
                action: { dictation.promptAccessibility() },
                secondary: ("Open Settings", { dictation.openAccessibilityPane() })
            )

            modelStateRow
        }
        .cardStyle()
    }

    @ViewBuilder
    private var modelStateRow: some View {
        switch dictation.modelStatus {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading whisper model…").font(.caption).foregroundStyle(.secondary)
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text("Downloading whisper model… \(Int(progress * 100))%")
                    .font(.caption).foregroundStyle(.secondary)
                ProgressView(value: progress).progressViewStyle(.linear)
            }
        case .ready:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(MacMartinColors.success)
                Text("Whisper model ready (\(WhisperEngine.modelName), on-device).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .transcribing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Transcribing…").font(.caption).foregroundStyle(.secondary)
            }
        case .error(let msg):
            Text(msg).font(.caption).foregroundStyle(MacMartinColors.warning)
        }
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How it works")
                .font(.headline)
            bullet("Press \(dictation.hotkeyLabel) anywhere on macOS to start.")
            bullet("Speak naturally; transcription happens on-device.")
            bullet("Press \(dictation.hotkeyLabel) again to stop — text pastes into the focused field.")
            bullet("Auto-stops after 60 seconds. Without Accessibility, text goes to clipboard.")
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private var canRecord: Bool {
        if case .ready = dictation.modelStatus {
            return dictation.micPermission == .granted
        }
        return false
    }

    private var statusText: String {
        switch dictation.status {
        case .idle: return dictation.enabled ? "Ready" : "Disabled"
        case .listening: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .pasted: return "Pasted"
        case .error(let msg): return msg
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch dictation.status {
        case .listening:
            badge("Listening", color: MacMartinColors.danger)
        case .transcribing:
            badge("Transcribing", color: MacMartinColors.warning)
        case .pasted:
            badge("Pasted", color: MacMartinColors.success)
        case .error:
            badge("Error", color: MacMartinColors.danger)
        case .idle:
            EmptyView()
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var pulseIcon: some View {
        let isActive = dictation.status == .listening
        ZStack {
            Circle()
                .fill(isActive ? MacMartinColors.danger.opacity(0.25) : MacMartinColors.accent.opacity(0.18))
                .frame(width: 32, height: 32)
            Image(systemName: isActive ? "waveform" : "mic")
                .foregroundStyle(isActive ? MacMartinColors.danger : MacMartinColors.accent)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            Text(text).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func permissionRow(
        title: String,
        detail: String,
        state: DictationService.Permission,
        action: @escaping () -> Void,
        secondary: (String, () -> Void)? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(state == .granted ? MacMartinColors.success : MacMartinColors.warning)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if state != .granted {
                if let secondary = secondary {
                    Button(secondary.0) { secondary.1() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Button("Grant") { action() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(MacMartinColors.accent)
            }
        }
    }
}
