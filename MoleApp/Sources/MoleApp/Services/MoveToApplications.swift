import AppKit
import Foundation

enum MoveToApplications {
    private static let declinedKey = "macmartin_declined_move_to_applications"

    static func promptIfNeeded() {
        #if DEBUG
        return
        #else
        guard shouldOffer() else { return }
        if UserDefaults.standard.bool(forKey: declinedKey) { return }

        let alert = NSAlert()
        alert.messageText = "Move MacMartin to the Applications folder?"
        alert.informativeText = "MacMartin works best from /Applications. Keeping it in Downloads or a mounted disk image can break updates, login-at-startup, and permissions prompts."
        alert.addButton(withTitle: "Move to Applications Folder")
        alert.addButton(withTitle: "Do Not Move")
        alert.alertStyle = .informational
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"

        let response = alert.runModal()
        let suppress = alert.suppressionButton?.state == .on

        if response == .alertFirstButtonReturn {
            performMove()
        } else if suppress {
            UserDefaults.standard.set(true, forKey: declinedKey)
        }
        #endif
    }

    private static func shouldOffer() -> Bool {
        let bundlePath = Bundle.main.bundlePath

        if bundlePath.hasPrefix("/Applications/") { return false }
        let homeApps = (NSHomeDirectory() as NSString).appendingPathComponent("Applications") + "/"
        if bundlePath.hasPrefix(homeApps) { return false }

        if bundlePath.contains("/DerivedData/") { return false }
        if bundlePath.contains("/.build/") { return false }
        if bundlePath.contains("/Xcode.app/") { return false }

        return true
    }

    private static func performMove() {
        let fm = FileManager.default
        let sourceURL = Bundle.main.bundleURL
        let destinationDir = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let destinationURL = destinationDir.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.trashItem(at: destinationURL, resultingItemURL: nil)
            }

            try fm.copyItem(at: sourceURL, to: destinationURL)

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-n", destinationURL.path]
            try task.run()

            NSApp.terminate(nil)
        } catch {
            showFailureAlert(error: error, destination: destinationURL)
        }
    }

    private static func showFailureAlert(error: Error, destination: URL) {
        let alert = NSAlert()
        alert.messageText = "Couldn't move MacMartin automatically"
        alert.informativeText = "\(error.localizedDescription)\n\nYou can drag MacMartin into /Applications yourself."
        alert.addButton(withTitle: "Reveal in Finder")
        alert.addButton(withTitle: "Close")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        }
    }
}
