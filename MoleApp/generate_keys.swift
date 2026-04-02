#!/usr/bin/env swift
/// Mole License Key Generator
/// Usage:
///   swift generate_keys.swift --init           Generate a new keypair
///   swift generate_keys.swift --sign EMAIL     Sign a license for EMAIL
///   swift generate_keys.swift --verify KEY     Verify a license key
///
/// The private key is saved to ~/.mole_private_key (keep secret!)
/// The public key is printed for embedding in LicenseManager.swift

import Foundation
import CryptoKit

let privateKeyPath = NSHomeDirectory() + "/.mole_private_key"

func base64urlEncode(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func base64urlDecode(_ str: String) -> Data? {
    var s = str
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while s.count % 4 != 0 { s += "=" }
    return Data(base64Encoded: s)
}

func loadPrivateKey() -> Curve25519.Signing.PrivateKey? {
    guard let b64 = try? String(contentsOfFile: privateKeyPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
          let data = Data(base64Encoded: b64) else { return nil }
    return try? Curve25519.Signing.PrivateKey(rawRepresentation: data)
}

// --- Commands ---

let args = CommandLine.arguments

if args.contains("--init") {
    let key = Curve25519.Signing.PrivateKey()
    let privateB64 = key.rawRepresentation.base64EncodedString()
    let publicB64 = key.publicKey.rawRepresentation.base64EncodedString()

    try! privateB64.write(toFile: privateKeyPath, atomically: true, encoding: .utf8)

    // Restrict permissions
    let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
    try? FileManager.default.setAttributes(attrs, ofItemAtPath: privateKeyPath)

    print("Keypair generated!\n")
    print("Private key saved to: \(privateKeyPath)")
    print("  (Keep this secret. Never commit it.)\n")
    print("Public key (paste into LicenseManager.swift):")
    print("  \(publicB64)\n")

} else if let signIdx = args.firstIndex(of: "--sign"), signIdx + 1 < args.count {
    let email = args[signIdx + 1]

    guard let privateKey = loadPrivateKey() else {
        print("No private key found. Run: swift generate_keys.swift --init")
        exit(1)
    }

    // Default: 1 year from now
    let cal = Calendar.current
    let expiry = cal.date(byAdding: .year, value: 1, to: Date())!
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    let expStr = formatter.string(from: expiry)

    let id = UUID().uuidString.prefix(8).lowercased()
    let payload: [String: String] = [
        "email": email,
        "plan": "pro",
        "exp": expStr,
        "id": String(id),
    ]

    let payloadData = try! JSONEncoder().encode(payload)
    let signature = try! privateKey.signature(for: payloadData)

    let license = base64urlEncode(payloadData) + "." + base64urlEncode(signature)

    print("License generated for: \(email)")
    print("Expires: \(expStr)\n")
    print("License key:")
    print(license)
    print("")

} else if let verifyIdx = args.firstIndex(of: "--verify"), verifyIdx + 1 < args.count {
    let license = args[verifyIdx + 1]
    let parts = license.split(separator: ".", maxSplits: 1)
    guard parts.count == 2,
          let payloadData = base64urlDecode(String(parts[0])),
          let sigData = base64urlDecode(String(parts[1])) else {
        print("Invalid license format")
        exit(1)
    }

    guard let privateKey = loadPrivateKey() else {
        print("No private key found for verification.")
        exit(1)
    }

    let publicKey = privateKey.publicKey
    if publicKey.isValidSignature(sigData, for: payloadData) {
        let payload = try! JSONDecoder().decode([String: String].self, from: payloadData)
        print("VALID license")
        print("  Email: \(payload["email"] ?? "?")")
        print("  Plan:  \(payload["plan"] ?? "?")")
        print("  Exp:   \(payload["exp"] ?? "?")")
        print("  ID:    \(payload["id"] ?? "?")")
    } else {
        print("INVALID — signature does not match")
        exit(1)
    }

} else {
    print("""
    Mole License Key Tool

    Usage:
      swift generate_keys.swift --init           Generate new Ed25519 keypair
      swift generate_keys.swift --sign EMAIL     Create a signed license
      swift generate_keys.swift --verify KEY     Verify a license key

    Workflow:
      1. Run --init once (saves private key to ~/.mole_private_key)
      2. Copy the public key into LicenseManager.swift
      3. Run --sign user@email.com to generate licenses
      4. Give the license string to users
    """)
}
