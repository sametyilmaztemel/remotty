#!/bin/bash
# Build macOS .dmg from Swift source
set -euo pipefail

echo "📦 Building remotyy macOS app..."
cd "$(dirname "$0")/remotyy-macOS"

# Clean previous build
rm -rf .build remotyy.app remotyy.dmg

# Build with SwiftPM
swift build -c release --product remotyy 2>&1

# Locate binary
BINARY=".build/release/remotyy"
if [ ! -f "$BINARY" ]; then
    echo "❌ Build failed: binary not found"
    exit 1
fi

# Create .app bundle
APP_NAME="remotyy.app"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

cp "$BINARY" "$APP_NAME/Contents/MacOS/remotyy"
cp Info.plist "$APP_NAME/Contents/"

# Create iconset (generate from a placeholder or use a PNG)
mkdir -p "$APP_NAME/Contents/Resources/AppIcon.iconset"
cat > "$APP_NAME/Contents/Resources/AppIcon.iconset/icon_256x256.png" << EOF
PLACEHOLDER — replace with actual icon
EOF

# Create DMG
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "remotyy" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "remotyy.app" 175 120 \
        --hide-extension "remotyy.app" \
        --app-drop-link 425 120 \
        "remotyy.dmg" \
        "remotyy.app"
    echo "✅ DMG created: remotyy.dmg"
elif command -v hdiutil &> /dev/null; then
    hdiutil create -volname "remotyy" -srcfolder "$APP_NAME" -ov -format UDZO "remotyy.dmg"
    echo "✅ DMG created: remotyy.dmg"
else
    echo "⚠️  DMG creation skipped (no create-dmg or hdiutil)"
    echo "   App bundle ready: $APP_NAME"
fi

echo "📁 Output: $(pwd)/remotyy.dmg"
