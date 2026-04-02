import Foundation
import AppKit

@MainActor
class UpdateManager: ObservableObject {
    @Published var updateRequired = false
    @Published var updateMessage = ""
    @Published var downloadURL: URL?
    @Published var latestVersion = ""

    /// Current app version (must match build.sh Info.plist).
    static let currentVersion = "1.0.0"

    /// URL to a JSON file with version info. Host this on GitHub Pages, a CDN, or raw GitHub.
    /// Format: {"min_version":"1.0.0","latest_version":"1.1.0","download_url":"...","message":"..."}
    private let versionURL = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/MoleApp/version.json"

    struct VersionInfo: Codable {
        let minVersion: String
        let latestVersion: String
        let downloadUrl: String
        let message: String

        enum CodingKeys: String, CodingKey {
            case minVersion = "min_version"
            case latestVersion = "latest_version"
            case downloadUrl = "download_url"
            case message
        }
    }

    func checkForUpdates() {
        guard let url = URL(string: versionURL) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let info = try JSONDecoder().decode(VersionInfo.self, from: data)

                latestVersion = info.latestVersion
                downloadURL = URL(string: info.downloadUrl)

                if compareVersions(Self.currentVersion, isLessThan: info.minVersion) {
                    updateRequired = true
                    updateMessage = info.message.isEmpty
                        ? "A required update is available (v\(info.latestVersion)). Please update to continue."
                        : info.message
                }
            } catch {
                // Silently fail — don't block the app if the check fails.
            }
        }
    }

    func openDownload() {
        if let url = downloadURL {
            NSWorkspace.shared.open(url)
        }
    }

    /// Semver comparison: returns true if `a` < `b`.
    private func compareVersions(_ a: String, isLessThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(aParts.count, bParts.count) {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av < bv { return true }
            if av > bv { return false }
        }
        return false
    }
}
