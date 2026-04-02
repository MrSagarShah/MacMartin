# MacMartin Pro — License Key Management

## Quick Start

```bash
cd MoleApp
```

### 1. Generate your keypair (one time only)

```bash
swift generate_keys.swift --init
```

This creates:
- **Private key** at `~/.mole_private_key` — NEVER share this, NEVER commit it
- **Public key** printed to terminal — already embedded in the app

Output:
```
Keypair generated!

Private key saved to: /Users/sagar/.mole_private_key
Public key (paste into LicenseManager.swift):
  mM0J3k/C+xTGkTKZ8JEvREUzUQ2FrI8sUMfmfRj9nzE=
```

> If you regenerate keys, you must update `publicKeyBase64` in
> `Sources/MoleApp/Services/LicenseManager.swift` and rebuild the app.
> All previously issued keys will stop working.

---

### 2. Generate a license for a customer

```bash
swift generate_keys.swift --sign customer@email.com
```

Output:
```
License generated for: customer@email.com
Expires: 2027-04-02

License key:
eyJlbWFpbCI6ImN1c3RvbWVyQGVtYW...
```

Copy the license key string and send it to the customer.

---

### 3. Verify a license key

```bash
swift generate_keys.swift --verify "eyJlbWFpbCI6ImN1c3RvbWVyQGVtYW..."
```

Output:
```
VALID license
  Email: customer@email.com
  Plan:  pro
  Exp:   2027-04-02
  ID:    aecbf464
```

---

## How It Works

Each license key is two parts joined by a dot:

```
base64url(JSON payload) . base64url(Ed25519 signature)
```

**Payload** (signed JSON):
```json
{
  "email": "customer@email.com",
  "plan": "pro",
  "exp": "2027-04-02",
  "id": "aecbf464"
}
```

**Security**:
- The app has the **public key** embedded — it can verify but not create licenses
- Only you have the **private key** at `~/.mole_private_key` — needed to sign
- Ed25519 signatures cannot be forged or brute-forced
- Each key has an expiry date — expired keys are rejected

---

## Customer Instructions

Tell your customers:

1. Open MacMartin
2. Click any locked feature (Analyze, Uninstall, or Optimize)
3. Click **Unlock with MacMartin Pro**
4. Paste the license key into the text field
5. Click **Activate License**

The license persists across app restarts. No internet required.

---

## Common Tasks

### Generate multiple keys at once

```bash
for email in alice@test.com bob@test.com carol@test.com; do
  echo "---"
  swift generate_keys.swift --sign "$email"
done
```

### Generate a key with custom expiry

Edit `generate_keys.swift` line that sets expiry and change:
```swift
let expiry = cal.date(byAdding: .year, value: 1, to: Date())!
```
To for example 2 years:
```swift
let expiry = cal.date(byAdding: .year, value: 2, to: Date())!
```

### Revoke all keys and start fresh

```bash
swift generate_keys.swift --init
```

Then update `publicKeyBase64` in `LicenseManager.swift` with the new public key and rebuild the app. All old keys become invalid.

---

## File Locations

| File | Purpose |
|------|---------|
| `~/.mole_private_key` | Your secret signing key (chmod 600) |
| `generate_keys.swift` | Key generation tool |
| `Sources/MoleApp/Services/LicenseManager.swift` | Public key embedded here |

---

## Security Notes

- The private key file has `chmod 600` (owner-only read/write)
- Never commit `~/.mole_private_key` to git
- The public key in the app binary is safe to distribute
- Keys are validated offline — no server or internet needed
- Expired keys are rejected at app launch
