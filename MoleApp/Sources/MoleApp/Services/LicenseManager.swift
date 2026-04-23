import Foundation
import CryptoKit
import AppKit

enum LicenseTier: String {
    case free, pro
}

/// License format: base64url(JSON payload) + "." + base64url(Ed25519 signature)
/// Payload: {"email":"...","plan":"pro","exp":"2027-01-01","id":"..."}
/// The app embeds the public key; only the developer has the private key.
@MainActor
class LicenseManager: ObservableObject {
    // MacMartin is free — all features unlocked by default.
    @Published private(set) var tier: LicenseTier = .pro
    @Published var showPaywall: Bool = false
    @Published private(set) var licenseEmail: String?

    private let storageKey = "mole_license_v2"

    /// Ed25519 public key (base64). Replace with your own from generate_keys.swift.
    /// This is safe to embed — the private key is what signs licenses.
    static let publicKeyBase64 = "mM0J3k/C+xTGkTKZ8JEvREUzUQ2FrI8sUMfmfRj9nzE="

    /// Coinbase Commerce checkout URL.
    private let cryptoCheckoutURL = "https://commerce.coinbase.com/checkout/YOUR-CHECKOUT-ID"

    init() {
        if let stored = UserDefaults.standard.string(forKey: storageKey) {
            if let payload = Self.verify(license: stored) {
                tier = .pro
                licenseEmail = payload.email
            }
        }
    }

    // MARK: - Public API

    func requiresPro(_ tab: SidebarTab) -> Bool {
        tab.isPro
    }

    /// Activate with a signed license string.
    /// Returns nil on success, or an error message on failure.
    func activate(license key: String) -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Please enter a license key" }

        guard let payload = Self.verify(license: trimmed) else {
            return "Invalid or tampered license key"
        }

        // Check expiry
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let expDate = formatter.date(from: payload.exp), expDate < Date() {
            return "This license has expired (\(payload.exp))"
        }

        UserDefaults.standard.set(trimmed, forKey: storageKey)
        tier = .pro
        licenseEmail = payload.email
        showPaywall = false
        return nil
    }

    func activateViaCrypto() {
        if let url = URL(string: cryptoCheckoutURL) {
            NSWorkspace.shared.open(url)
        }
    }

    func deactivate() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        tier = .free
        licenseEmail = nil
    }

    // MARK: - Ed25519 Verification

    struct LicensePayload: Codable {
        let email: String
        let plan: String
        let exp: String
        let id: String
    }

    /// Verify a license string: base64url(payload).base64url(signature)
    /// Returns the decoded payload if valid, nil otherwise.
    static func verify(license: String) -> LicensePayload? {
        let parts = license.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        guard let payloadData = base64urlDecode(String(parts[0])),
              let signatureData = base64urlDecode(String(parts[1])) else {
            return nil
        }

        // Decode public key
        guard let pubKeyData = Data(base64Encoded: Self.publicKeyBase64) else { return nil }

        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: pubKeyData)
            guard publicKey.isValidSignature(signatureData, for: payloadData) else { return nil }
            return try JSONDecoder().decode(LicensePayload.self, from: payloadData)
        } catch {
            return nil
        }
    }

    // MARK: - Base64url helpers

    private static func base64urlDecode(_ str: String) -> Data? {
        var s = str
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }

    static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
