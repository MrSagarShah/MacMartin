import SwiftUI
import AppKit

@MainActor
final class DictationOverlayWindow {
    private var panel: NSPanel?
    private weak var service: DictationService?

    func attach(_ service: DictationService) {
        self.service = service
    }

    func show() {
        if panel != nil { panel?.orderFront(nil); return }
        guard let service = service else { return }

        let size = NSSize(width: 220, height: 56)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true

        let host = NSHostingView(rootView: DictationOverlayView().environmentObject(service))
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host

        if let saved = Self.savedOrigin() {
            panel.setFrameOrigin(saved)
        } else if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.minY + 40
            )
            panel.setFrameOrigin(origin)
        }

        panel.orderFrontRegardless()
        self.panel = panel

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak panel] _ in
            guard let origin = panel?.frame.origin else { return }
            Task { @MainActor in Self.saveOrigin(origin) }
        }
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Persisted position

    private static let originXKey = "macmartin.dictation.overlayX"
    private static let originYKey = "macmartin.dictation.overlayY"

    private static func saveOrigin(_ point: NSPoint) {
        let d = UserDefaults.standard
        d.set(Double(point.x), forKey: originXKey)
        d.set(Double(point.y), forKey: originYKey)
    }

    private static func savedOrigin() -> NSPoint? {
        let d = UserDefaults.standard
        guard d.object(forKey: originXKey) != nil, d.object(forKey: originYKey) != nil else { return nil }
        return NSPoint(x: d.double(forKey: originXKey), y: d.double(forKey: originYKey))
    }
}

struct DictationOverlayView: View {
    @EnvironmentObject private var service: DictationService
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            iconWell
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subline)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .onTapGesture(count: 2) {
            service.toggleRecording()
        }
        .help("Hold \(service.hotkeyLabel) anywhere. Double-click to toggle.")
        .frame(width: 220, height: 56)
    }

    private var iconWell: some View {
        ZStack {
            Circle()
                .fill(iconBgColor)
                .frame(width: 32, height: 32)
                .scaleEffect(pulse && service.status == .listening ? 1.18 : 1.0)
                .opacity(pulse && service.status == .listening ? 0.55 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)

            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .onAppear { pulse = true }
    }

    private var headline: String {
        switch service.status {
        case .idle: return service.enabled ? "Ready" : "Disabled"
        case .listening: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .pasted: return "Pasted"
        case .error: return "Error"
        }
    }

    private var subline: String {
        switch service.status {
        case .listening: return "Press \(service.hotkeyLabel) to stop"
        case .transcribing: return "Almost there"
        case .pasted: return service.lastTranscription.isEmpty ? "Done" : trimmed(service.lastTranscription)
        case .error(let msg): return trimmed(msg)
        case .idle: return "Press \(service.hotkeyLabel) to dictate"
        }
    }

    private func trimmed(_ s: String) -> String {
        s.count > 40 ? String(s.prefix(38)) + "…" : s
    }

    private var iconName: String {
        switch service.status {
        case .listening: return "waveform"
        case .transcribing: return "ellipsis"
        case .pasted: return "checkmark"
        case .error: return "exclamationmark.triangle.fill"
        case .idle: return "mic.fill"
        }
    }

    private var iconBgColor: Color {
        switch service.status {
        case .listening: return Color.red.opacity(0.85)
        case .transcribing: return Color.orange.opacity(0.85)
        case .pasted: return Color.green.opacity(0.85)
        case .error: return Color.red.opacity(0.6)
        case .idle: return Color(red: 0.40, green: 0.52, blue: 1.0).opacity(0.85)
        }
    }

    private var borderColor: Color {
        switch service.status {
        case .listening: return Color.red.opacity(0.45)
        case .error: return Color.red.opacity(0.35)
        default: return Color.white.opacity(0.08)
        }
    }
}
