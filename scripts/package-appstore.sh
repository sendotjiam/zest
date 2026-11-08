#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🍎 Zest Mac App Store Packaging Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Build Universal Release Binary
echo "🔨 Building Universal Release Binary (arm64 + x86_64)..."
if swift build -c release --arch arm64 --arch x86_64; then
    BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path 2>/dev/null || echo "$DIR/.build/out/Products/Release")"
    BINARY_SRC="$BIN_DIR/Zest"
    if [ ! -f "$BINARY_SRC" ]; then
        BINARY_SRC="$DIR/.build/out/Products/Release/Zest"
    fi
else
    echo "⚠️ Universal build failed, falling back to native architecture..."
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

echo "📦 Assembling $APP_NAME bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary and AppIcon
cp "$BINARY_SRC" "$MACOS_DIR/Zest"
chmod +x "$MACOS_DIR/Zest"
cp "$DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# Production App Store Info.plist
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
</dict>
</plist>
EOF

# Determine Signing Identity
APP_IDENTITY="${APPLE_APP_IDENTITY:-3rd Party Mac Developer Application}"
INSTALLER_IDENTITY="${APPLE_INSTALLER_IDENTITY:-3rd Party Mac Developer Installer}"

DIST_DIR="$DIR/dist"
mkdir -p "$DIST_DIR"
PKG_PATH="$DIST_DIR/Zest-AppStore.pkg"

# Check if certificates exist in keychain
if security find-identity -p codesigning -v | grep -q "$APP_IDENTITY"; then
    echo "🔏 Signing with Apple Developer Certificate: $APP_IDENTITY..."
    codesign --force --deep --options runtime \
        --entitlements "$DIR/Zest.entitlements" \
        -s "$APP_IDENTITY" "$APP_DIR"
    
    echo "📦 Creating signed App Store installer package (.pkg)..."
    productbuild --component "$APP_DIR" /Applications \
        --sign "$INSTALLER_IDENTITY" "$PKG_PATH"
    
    echo "🔍 Validating package integrity..."
    pkgutil --check-signature "$PKG_PATH"
    
    echo ""
    echo "✅ Success! App Store installer generated at:"
    echo "   $PKG_PATH"
    echo ""
    echo "🚀 Next step to upload to App Store Connect:"
    echo "   xcrun altool --upload-app -f \"$PKG_PATH\" -t macos -u \"<Apple-ID>\" -p \"<App-Specific-Password>\""
else
    echo "⚠️ Apple Developer signing identities not found in Keychain."
    echo "   Packaging with local ad-hoc sandbox signature for testing..."
    codesign --force --deep --entitlements "$DIR/Zest.entitlements" -s - "$APP_DIR"
    echo "✅ Local sandbox signed build ready at $APP_DIR"
fi
