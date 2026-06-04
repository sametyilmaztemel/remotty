#!/bin/bash
# Build remotyy macOS .dmg from source
# Usage: bash scripts/build-dmg.sh [--install]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DMG_NAME="remotyy.dmg"

echo "📦 Building remotyy macOS app..."
echo "Root: $ROOT_DIR"

# 1. Build Go daemon binary
echo "🔨 Building Go daemon..."
cd "$ROOT_DIR"
mkdir -p "$BUILD_DIR"
go build -o "$BUILD_DIR/remotyyd" -ldflags="-s -w" ./cmd/remotyy

# 2. Build SwiftUI menu bar app
echo "🖥  Building SwiftUI app..."
cd "$ROOT_DIR/remotyy-macOS"
swift build -c release --product remotyy 2>&1 | tail -3
SWIFT_BINARY=".build/release/remotyy"

# 3. Create .app bundle
echo "📁 Creating .app bundle..."
APP_BUNDLE="$BUILD_DIR/remotyy.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$SWIFT_BINARY" "$APP_BUNDLE/Contents/MacOS/remotyy"
cp "Info.plist" "$APP_BUNDLE/Contents/"
cp "$BUILD_DIR/remotyyd" "$APP_BUNDLE/Contents/Resources/remotyyd"

# 4. Create DMG
echo "💿 Creating DMG..."
DMG_PATH="$BUILD_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

hdiutil create -volname "remotyy" \
  -srcfolder "$APP_BUNDLE" \
  -ov -format UDZO \
  "$DMG_PATH" 2>&1 | tail -1

# 5. Copy to Downloads
if [ "${1:-}" = "--install" ] || [ "${1:-}" = "-i" ]; then
    cp "$DMG_PATH" ~/Downloads/
    echo "✅ Copied to ~/Downloads/$DMG_NAME"
    
    # Install and open
    rm -rf /Applications/remotyy.app
    hdiutil attach ~/Downloads/$DMG_NAME 2>&1 | tail -1
    cp -R "/Volumes/remotyy/remotyy.app" /Applications/
    xattr -dr com.apple.quarantine /Applications/remotyy.app
    hdiutil detach "/Volumes/remotyy" 2>/dev/null || true
    open /Applications/remotyy.app
    echo "✅ Installed and launched"
else
    echo "✅ DMG: $DMG_PATH"
    echo "   Size: $(du -h "$DMG_PATH" | cut -f1)"
    echo ""
    echo "To install: open $DMG_PATH"
    echo "Or run: bash $0 --install"
fi
