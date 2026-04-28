import Foundation
import AVFoundation
import AppKit
import Carbon.HIToolbox
import Combine

extension ISO8601DateFormatter {
    static let short: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withTime, .withColonSeparatorInTime]
        return f
    }()
}

@MainActor
final class DictationService: ObservableObject {
    enum Status: Equatable {
        case idle
        case listening
        case transcribing
        case pasted
        case error(String)
    }

    enum Permission: Equatable { case unknown, granted, denied }

    @Published var status: Status = .idle
    @Published var lastTranscription: String = ""
    @Published var micPermission: Permission = .unknown
    @Published var accessibilityGranted: Bool = false
    @Published var modelStatus: WhisperEngine.State = .idle
    @Published var diagnostics: [String] = []
    @Published var lastSampleCount: Int = 0
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
            if enabled {
                registerHotkey()
                whisper.ensureLoaded()
                if showOverlay { overlay.show() }
            } else {
                unregisterHotkey()
                overlay.hide()
            }
        }
    }
    @Published var showOverlay: Bool {
        didSet {
            UserDefaults.standard.set(showOverlay, forKey: Self.overlayKey)
            if enabled && showOverlay { overlay.show() } else { overlay.hide() }
        }
    }

    let whisper = WhisperEngine()
    private let overlay = DictationOverlayWindow()
    private var modelObserver: AnyCancellable?

    private static let enabledKey = "macmartin.dictation.enabled"
    private static let overlayKey = "macmartin.dictation.overlay"
    private static let signature: OSType = 0x4D434D4E // 'MCMN'

    private var hotkeyRef: EventHotKeyRef?
    private var pressedHandler: EventHandlerRef?
    private var autoStopTimer: Timer?

    private let audioEngine = AVAudioEngine()
    private var audioConverter: AVAudioConverter?
    private var capturedSamples: [Float] = []
    private var previousApp: NSRunningApplication?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    init() {
        self.enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if UserDefaults.standard.object(forKey: Self.overlayKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.overlayKey)
        }
        self.showOverlay = UserDefaults.standard.bool(forKey: Self.overlayKey)

        refreshPermissions()
        overlay.attach(self)

        // Mirror whisper engine state for UI.
        modelObserver = whisper.$state.sink { [weak self] newState in
            Task { @MainActor in self?.modelStatus = newState }
        }

        if enabled {
            whisper.ensureLoaded()
            registerHotkey()
            if showOverlay { overlay.show() }
        }
    }

    // MARK: - Permissions

    func refreshPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: micPermission = .granted
        case .denied, .restricted: micPermission = .denied
        default: micPermission = .unknown
        }
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            Task { @MainActor in self.refreshPermissions() }
        }
    }

    func promptAccessibility() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshPermissions()
        }
    }

    func openAccessibilityPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Hotkey (⌃⌥D)

    var hotkeyLabel: String { "⌃⌥D" }

    private func registerHotkey() {
        unregisterHotkey()

        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let modifiers = UInt32(controlKey | optionKey)
        let keyCode = UInt32(kVK_ANSI_D)

        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        guard regStatus == noErr, let ref = ref else {
            status = .error("Hotkey registration failed (\(regStatus))")
            return
        }
        hotkeyRef = ref

        let context = Unmanaged.passUnretained(self).toOpaque()

        var pressedSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            guard let ctx = ctx else { return noErr }
            let svc = Unmanaged<DictationService>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in svc.toggleRecording() }
            return noErr
        }, 1, &pressedSpec, context, &pressedHandler)
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let h = pressedHandler {
            RemoveEventHandler(h)
            pressedHandler = nil
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        if status == .listening { stopAndTranscribe() } else { startRecording() }
    }

    func startRecording() {
        guard status != .listening, status != .transcribing else { return }

        guard micPermission == .granted else {
            status = .error("Microphone permission required")
            return
        }
        guard case .ready = whisper.state else {
            // Trigger load if not yet started; user can press again once ready.
            whisper.ensureLoaded()
            status = .error("Model not ready yet")
            return
        }

        // Remember which app is focused so we can paste back into it.
        let ourBundle = Bundle.main.bundleIdentifier
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != ourBundle {
            previousApp = front
        }

        capturedSamples.removeAll(keepingCapacity: true)

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            status = .error("No audio input available")
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            status = .error("Could not create audio converter")
            return
        }
        audioConverter = converter

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer, with: converter)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            status = .error("Audio start failed: \(error.localizedDescription)")
            return
        }

        status = .listening
        log("recording started; saved focus = \(previousApp?.localizedName ?? "nil")")
        autoStopTimer?.invalidate()
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stopAndTranscribe() }
        }
    }

    func stopAndTranscribe() {
        guard status == .listening else { return }
        autoStopTimer?.invalidate()
        autoStopTimer = nil

        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)

        status = .transcribing
        let samples = capturedSamples
        capturedSamples.removeAll(keepingCapacity: true)
        lastSampleCount = samples.count
        log("captured \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / 16000.0))s); transcribing")

        Task { [weak self] in
            guard let self = self else { return }
            let text = await self.whisper.transcribe(samples: samples)
            await MainActor.run {
                self.log("whisper returned: \(text == nil ? "<nil>" : "\"\(text!)\"")")
                self.finalizeTranscription(text ?? "")
            }
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1024)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return }

        var fed = false
        var convError: NSError?
        converter.convert(to: outBuffer, error: &convError) { _, statusOut in
            if fed {
                statusOut.pointee = .noDataNow
                return nil
            }
            fed = true
            statusOut.pointee = .haveData
            return buffer
        }

        guard convError == nil,
              let channel = outBuffer.floatChannelData?[0] else { return }
        let count = Int(outBuffer.frameLength)
        guard count > 0 else { return }

        let pointer = UnsafeBufferPointer(start: channel, count: count)
        let chunk = Array(pointer)
        Task { @MainActor [weak self] in
            self?.capturedSamples.append(contentsOf: chunk)
        }
    }

    private func finalizeTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = .error("Empty transcription")
            log("empty transcription; check audio levels")
            return
        }
        lastTranscription = trimmed
        if accessibilityGranted {
            log("pasting into \(previousApp?.localizedName ?? "frontmost")")
            paste(trimmed)
            status = .pasted
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if self?.status == .pasted { self?.status = .idle }
            }
        } else {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(trimmed, forType: .string)
            status = .error("Pasted to clipboard (Accessibility not granted)")
            log("AX not granted; copied to clipboard")
        }
    }

    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter.short.string(from: Date())
        let line = "\(ts) \(msg)"
        diagnostics.append(line)
        if diagnostics.count > 20 { diagnostics.removeFirst(diagnostics.count - 20) }
        NSLog("[Dictation] %@", msg)
    }

    // MARK: - Text injection

    private func paste(_ text: String) {
        let pb = NSPasteboard.general
        let savedString = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        // Re-focus the app that was frontmost when recording started.
        let target = previousApp
        target?.activate(options: [])

        // Give the OS a moment for activation + pasteboard commit, then post ⌘V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let src = CGEventSource(stateID: .combinedSessionState)
            let v = CGKeyCode(kVK_ANSI_V)
            if let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true) {
                down.flags = .maskCommand
                down.post(tap: .cghidEventTap)
            }
            usleep(15_000)
            if let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false) {
                up.flags = .maskCommand
                up.post(tap: .cghidEventTap)
            }

            if let saved = savedString {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(saved, forType: .string)
                }
            }
        }
    }
}

