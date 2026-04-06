import Foundation
import SwiftUI

@MainActor
class MacMartinService: ObservableObject {
    let molePath: String

    init() {
        // Find the mole binary: check common locations.
        let candidates = [
            "/opt/homebrew/bin/mole",
            "/usr/local/bin/mole",
            "/opt/homebrew/bin/mo",
            "/usr/local/bin/mo",
        ]
        // Also check relative to the app (development mode).
        let devPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // MoleApp
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // MoleApp
            .deletingLastPathComponent() // project root
            .appendingPathComponent("mole")
            .path

        let allCandidates = [devPath] + candidates
        self.molePath = allCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? "mole" // fallback to PATH
    }

    // MARK: - Clean

    func scanClean() async throws -> CleanScanResult {
        let output = try await run(args: ["clean", "--scan"])
        guard let data = output.data(using: .utf8) else {
            throw MacMartinError.parseError("Invalid scan output")
        }
        return try JSONDecoder().decode(CleanScanResult.self, from: data)
    }

    func runClean(categories: [String]) async throws -> String {
        let catArg = categories.joined(separator: ",")
        return try await run(args: ["clean", "--no-select", "--categories", catArg])
    }

    func runCleanAll() async throws -> String {
        return try await run(args: ["clean", "--no-select"])
    }

    // MARK: - Status

    func getStatus() async throws -> StatusMetrics {
        let output = try await run(args: ["status", "--json"])
        guard let data = output.data(using: .utf8) else {
            throw MacMartinError.parseError("Invalid status output")
        }
        return try JSONDecoder().decode(StatusMetrics.self, from: data)
    }

    // MARK: - Analyze

    func analyzeDirectory(_ path: String) async throws -> AnalyzeResult {
        let output = try await run(args: ["analyze", "--json", path])
        guard let data = output.data(using: .utf8) else {
            throw MacMartinError.parseError("Invalid analyze output")
        }
        return try JSONDecoder().decode(AnalyzeResult.self, from: data)
    }

    // MARK: - Optimize

    func runOptimize() async throws -> String {
        return try await run(args: ["optimize"])
    }

    // MARK: - Uninstall

    func listApps() async throws -> [InstalledApp] {
        // Read the cached app metadata if available.
        let cachePath = NSHomeDirectory() + "/.cache/mole/uninstall_app_metadata_v1"
        guard FileManager.default.fileExists(atPath: cachePath),
              let content = try? String(contentsOfFile: cachePath, encoding: .utf8) else {
            // Trigger a scan to populate the cache by running uninstall in dry mode.
            // The CLI populates the cache on any uninstall invocation.
            _ = try? await run(args: ["uninstall", "--dry-run"])
            guard let content = try? String(contentsOfFile: cachePath, encoding: .utf8) else {
                return []
            }
            return parseAppMetadata(content)
        }
        return parseAppMetadata(content)
    }

    private func parseAppMetadata(_ content: String) -> [InstalledApp] {
        // Format: path|mtime|size_kb|last_used_epoch|cache_epoch|bundle_id|display_name
        var apps: [InstalledApp] = []
        for line in content.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 7 else { continue }
            let sizeKb = Int(parts[2]) ?? 0
            let lastUsedEpoch = Int(parts[3]) ?? 0
            let lastUsed = lastUsedEpoch > 0 ? formatRelativeTime(epoch: lastUsedEpoch) : "Unknown"
            let app = InstalledApp(
                path: parts[0],
                name: parts[6],
                bundleId: parts[5],
                sizeHuman: formatBytes(kb: sizeKb),
                sizeKb: sizeKb,
                lastUsed: lastUsed
            )
            apps.append(app)
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func formatRelativeTime(epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(epoch))
        let days = Int(-date.timeIntervalSinceNow / 86400)
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 30 { return "\(days) days ago" }
        if days < 365 { return "\(days / 30) months ago" }
        return "\(days / 365) years ago"
    }

    // MARK: - Shell Execution

    func run(args: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [molePath] in
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: molePath)
                process.arguments = args
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                process.environment = Foundation.ProcessInfo.processInfo.environment

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errOutput = String(data: errData, encoding: .utf8) ?? output
                        continuation.resume(throwing: MacMartinError.commandFailed(errOutput.isEmpty ? output : errOutput))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum MacMartinError: LocalizedError {
    case commandFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let msg): return "Command failed: \(msg)"
        case .parseError(let msg): return "Parse error: \(msg)"
        }
    }
}
