#!/bin/bash
# Build MacMartin as a macOS .app bundle and optionally a DMG for sharing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="MacMartin"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"

echo "Building MacMartin (universal: arm64 + x86_64)..."
swift build -c release --triple arm64-apple-macosx 2>&1
swift build -c release --triple x86_64-apple-macosx 2>&1

echo "Creating universal binary with lipo..."
UNIVERSAL_BIN="$BUILD_DIR/MoleApp-universal"
lipo -create \
    "$BUILD_DIR/arm64-apple-macosx/release/MoleApp" \
    "$BUILD_DIR/x86_64-apple-macosx/release/MoleApp" \
    -output "$UNIVERSAL_BIN"

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# Copy universal binary
cp "$UNIVERSAL_BIN" "$CONTENTS/MacOS/$APP_NAME"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacMartin</string>
    <key>CFBundleIdentifier</key>
    <string>com.krakelabs.macmartin</string>
    <key>CFBundleName</key>
    <string>MacMartin</string>
    <key>CFBundleDisplayName</key>
    <string>MacMartin</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Generate app icon programmatically
echo "Generating app icon..."
ICON_SCRIPT=$(mktemp /tmp/mole_icon_XXXXXX.swift)
cat > "$ICON_SCRIPT" << 'ICONSCRIPT'
import AppKit

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

let outputDir = CommandLine.arguments[1]
let iconsetPath = "\(outputDir)/AppIcon.iconset"

try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    // Background: rounded rect with gradient
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.05, dy: s * 0.05), xRadius: s * 0.22, yRadius: s * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.2, green: 0.35, blue: 0.9, alpha: 1),
        NSColor(red: 0.35, green: 0.55, blue: 1.0, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -45)

    // Magnifying glass symbol (drawn as circles + line)
    let cx = s * 0.42, cy = s * 0.58, r = s * 0.2
    let lensPath = NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    NSColor.white.withAlphaComponent(0.9).setStroke()
    lensPath.lineWidth = s * 0.06
    lensPath.stroke()

    let handlePath = NSBezierPath()
    handlePath.move(to: NSPoint(x: cx + r * 0.7, y: cy - r * 0.7))
    handlePath.line(to: NSPoint(x: cx + r * 1.6, y: cy - r * 1.6))
    handlePath.lineWidth = s * 0.07
    handlePath.lineCapStyle = .round
    handlePath.stroke()

    // Sparkle dot
    let dotR = s * 0.04
    let dotPath = NSBezierPath(ovalIn: NSRect(x: cx + r * 0.5 - dotR, y: cy + r * 0.6 - dotR, width: dotR * 2, height: dotR * 2))
    NSColor.white.setFill()
    dotPath.fill()

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { continue }
    try? png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
}
ICONSCRIPT

swift "$ICON_SCRIPT" "$CONTENTS/Resources" 2> /dev/null || true
if [[ -d "$CONTENTS/Resources/AppIcon.iconset" ]]; then
    iconutil -c icns "$CONTENTS/Resources/AppIcon.iconset" -o "$CONTENTS/Resources/AppIcon.icns" 2> /dev/null || true
    rm -rf "$CONTENTS/Resources/AppIcon.iconset"
    echo "App icon generated."
else
    echo "App icon generation skipped (requires display context)."
fi
rm -f "$ICON_SCRIPT"

# Self-sign the app to avoid repeated Gatekeeper warnings
echo "Signing app..."
codesign --force --deep --sign - "$APP_BUNDLE" 2> /dev/null && echo "App signed." || echo "Signing skipped."

echo ""
echo "Built: $APP_BUNDLE"

# Create DMG if --dmg flag is passed
if [[ "${1:-}" == "--dmg" ]]; then
    DMG_NAME="${APP_NAME}-macOS.dmg"
    DMG_PATH="$BUILD_DIR/$DMG_NAME"
    STAGING="$BUILD_DIR/dmg-staging"

    echo ""
    echo "Creating DMG..."

    rm -rf "$STAGING" "$DMG_PATH"
    mkdir -p "$STAGING"
    cp -R "$APP_BUNDLE" "$STAGING/"

    # Create a symlink to /Applications for drag-and-drop install
    ln -s /Applications "$STAGING/Applications"

    # Create the DMG
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING" \
        -ov -format UDZO \
        "$DMG_PATH" \
        > /dev/null

    rm -rf "$STAGING"
    echo "DMG: $DMG_PATH"
    echo ""
    echo "Share this file with others. They can drag MacMartin.app to Applications to install."
fi

echo ""
echo "Run:   open $APP_BUNDLE"
