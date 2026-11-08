#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "🔨 Building Zest (Universal: Apple Silicon arm64 + Intel x86_64)..."
if swift build -c release --arch arm64 --arch x86_64; then
    BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path 2>/dev/null || echo "$DIR/.build/out/Products/Release")"
    BINARY_SRC="$BIN_DIR/Zest"
    if [ ! -f "$BINARY_SRC" ]; then
        BINARY_SRC="$DIR/.build/out/Products/Release/Zest"
    fi
else
    echo "⚠️ Universal build failed, falling back to native architecture build..."
    swift build -c release
    BIN_DIR="$(swift build -c release --show-bin-path 2>/dev/null || echo "$DIR/.build/release")"
    BINARY_SRC="$BIN_DIR/Zest"
fi

if [ ! -f "$BINARY_SRC" ]; then
    echo "❌ Error: Could not locate built binary at $BINARY_SRC"
    exit 1
fi

APP_NAME="Zest.app"
APP_DIR="$DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Packaging $APP_NAME..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Ensure AppIcon.icns exists
if [ ! -f "$DIR/AppIcon.icns" ]; then
    echo "🎨 Generating AppIcon.icns..."
    swift "$DIR/scripts/generate_app_icon.swift"
fi

# Copy binary and AppIcon
cp "$BINARY_SRC" "$MACOS_DIR/Zest"
chmod +x "$MACOS_DIR/Zest"
cp "$DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# Create Info.plist (LSUIElement=true ensures it runs purely as a menu bar accessory)
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Zest</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>app.zest.macos</string>
    <key>CFBundleName</key>
    <string>Zest</string>
    <key>CFBundleDisplayName</key>
    <string>Zest</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>5</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Zest Contributors. All rights reserved.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Zest needs screen recording access to perform Optical Character Recognition (OCR) on selected areas.</string>
</dict>
</plist>
EOF

# Code sign with ad-hoc identity and stable designated requirement to preserve TCC permissions across builds
# Note: For standalone DMG/direct distribution, App Sandbox is omitted so system keystroke simulation works.
# Mac App Store builds with sandbox use scripts/package-appstore.sh.
echo "🔏 Signing $APP_NAME (ad-hoc with stable designated requirement)..."
codesign --force --deep -s - -r='designated => identifier "app.zest.macos"' "$APP_DIR"

# Create standalone distribution artifacts (DMG + ZIP)
DIST_DIR="$DIR/dist"
echo "📦 Creating distributable artifacts in $DIST_DIR..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# 1. Create ZIP for quick sharing / AirDrop
ditto -c -k --keepParent "$APP_DIR" "$DIST_DIR/Zest.zip"

# 2. Create Drag-and-Drop DMG
DMG_TEMP="$DIR/.dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "$APP_DIR" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"
hdiutil create -volname "Zest" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DIST_DIR/Zest.dmg" > /dev/null
rm -rf "$DMG_TEMP"

# Install to ~/Applications
DEST_DIR="$HOME/Applications"
mkdir -p "$DEST_DIR"
rm -rf "$DEST_DIR/$APP_NAME"
cp -R "$APP_DIR" "$DEST_DIR/$APP_NAME"

echo ""
echo "✅ Successfully built Zest.app and installed to $DEST_DIR/$APP_NAME"
echo "🎉 Distributable packages ready for other Macs (no Swift/Xcode required):"
echo "   - $DIST_DIR/Zest.dmg (Drag & Drop installer)"
echo "   - $DIST_DIR/Zest.zip (Portable archive)"
echo ""
echo "💡 To make it launch automatically on login:"
echo "   Go to: System Settings → General → Login Items → '+' and select Zest."
