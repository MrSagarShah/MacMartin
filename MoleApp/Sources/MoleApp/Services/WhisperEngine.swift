import Foundation
import WhisperKit

@MainActor
final class WhisperEngine: ObservableObject {
    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case loading
        case ready
        case transcribing
        case error(String)
    }

    @Published var state: State = .idle

    static let modelName = "openai_whisper-base.en"

    private var pipeline: WhisperKit?
    private var loadTask: Task<Void, Never>?

    func ensureLoaded() {
        if pipeline != nil { state = .ready; return }
        if loadTask != nil { return }

        loadTask = Task { [weak self] in
            guard let self = self else { return }
            await self.setState(.loading)
            do {
                let modelFolder = try await self.resolveOrDownloadModel()
                let config = WhisperKitConfig(
                    modelFolder: modelFolder.path,
                    verbose: false,
                    logLevel: .none,
                    prewarm: true,
                    load: true,
                    download: false
                )
                let kit = try await WhisperKit(config)
                await MainActor.run {
                    self.pipeline = kit
                    self.state = .ready
                    self.loadTask = nil
                }
            } catch {
                await MainActor.run {
                    self.state = .error("Model load failed: \(error.localizedDescription)")
                    self.loadTask = nil
                }
            }
        }
    }

    func transcribe(samples: [Float]) async -> String? {
        guard let pipeline = pipeline else {
            state = .error("Model not loaded")
            return nil
        }
        guard !samples.isEmpty else { return nil }

        state = .transcribing
        do {
            let results = try await pipeline.transcribe(audioArray: samples)
            let raw = results.map(\.text).joined(separator: " ")
            let cleaned = Self.stripArtifacts(raw)
            state = .ready
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            state = .error("Transcription failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Whisper occasionally emits training-corpus markers like [BLANK_AUDIO],
    /// [INAUDIBLE], [MUSIC], (silence), or speaker prefixes (>>, <<). Strip them
    /// so the user never pastes those.
    static func stripArtifacts(_ text: String) -> String {
        var out = text
        let patterns = [
            #"\[[A-Z_ ]{2,}\]"#,                           // [BLANK_AUDIO], [MUSIC]
            #"\[\s*(?i:silence|music|inaudible|pause|noise|sound effects|laughter|applause)\s*\]"#,
            #"\(\s*(?i:silence|music|inaudible|pause|noise|sound effects|laughter|applause)\s*\)"#,
        ]
        for pattern in patterns {
            out = out.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        out = out.replacingOccurrences(of: ">>", with: "")
        out = out.replacingOccurrences(of: "<<", with: "")
        // Collapse repeated whitespace and trim.
        out = out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Model resolution

    private func resolveOrDownloadModel() async throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = support.appendingPathComponent("MacMartin/whisper-models", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let modelFolder = root.appendingPathComponent(Self.modelName, isDirectory: true)
        let manifest = modelFolder.appendingPathComponent("config.json")

        if FileManager.default.fileExists(atPath: manifest.path) {
            return modelFolder
        }

        // Download via WhisperKit's helper.
        await setState(.downloading(progress: 0))
        let downloaded = try await WhisperKit.download(
            variant: Self.modelName,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { [weak self] progress in
                Task { @MainActor in
                    self?.state = .downloading(progress: progress.fractionCompleted)
                }
            }
        )

        // Move downloaded model to our managed folder.
        if FileManager.default.fileExists(atPath: modelFolder.path) {
            try? FileManager.default.removeItem(at: modelFolder)
        }
        try FileManager.default.moveItem(at: downloaded, to: modelFolder)
        return modelFolder
    }

    private func setState(_ newState: State) async {
        await MainActor.run { self.state = newState }
    }
}
