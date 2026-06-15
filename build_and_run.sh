#!/bin/bash

# Exit on any error
set -e

# Build the project
swift build -c release

# Create the app bundle structure
APP_NAME="Explorer.app"
APP_DIR="$APP_NAME/Contents"
MACOS_DIR="$APP_DIR/MacOS"
RESOURCES_DIR="$APP_DIR/Resources"
FRAMEWORKS_DIR="$APP_DIR/Frameworks"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

# Copy the executable
cp .build/release/Explorer "$MACOS_DIR/"

# Create Info.plist in Contents directory
cp Explorer/Info.plist "$APP_DIR/"

# Create PkgInfo
echo "APPL????" > "$APP_DIR/PkgInfo"

# Create app icon from PNG
ICON_PNG="Explorer/Resources/icon.png"
ICON_PATH="$RESOURCES_DIR/AppIcon.icns"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"

if [ -f "$ICON_PNG" ]; then
    echo "Creating app icon from PNG..."
    
    # Create iconset directory
    mkdir -p "$ICONSET_DIR"
    
    # Create all required icon sizes with sips
    sips -z 16 16 "$ICON_PNG" --out "${ICONSET_DIR}/icon_16x16.png"
    sips -z 32 32 "$ICON_PNG" --out "${ICONSET_DIR}/icon_16x16@2x.png"
    sips -z 32 32 "$ICON_PNG" --out "${ICONSET_DIR}/icon_32x32.png"
    sips -z 64 64 "$ICON_PNG" --out "${ICONSET_DIR}/icon_32x32@2x.png"
    sips -z 128 128 "$ICON_PNG" --out "${ICONSET_DIR}/icon_128x128.png"
    sips -z 256 256 "$ICON_PNG" --out "${ICONSET_DIR}/icon_128x128@2x.png"
    sips -z 256 256 "$ICON_PNG" --out "${ICONSET_DIR}/icon_256x256.png"
    sips -z 512 512 "$ICON_PNG" --out "${ICONSET_DIR}/icon_256x256@2x.png"
    sips -z 512 512 "$ICON_PNG" --out "${ICONSET_DIR}/icon_512x512.png"
    sips -z 1024 1024 "$ICON_PNG" --out "${ICONSET_DIR}/icon_512x512@2x.png"
    
    # Create .icns file
    iconutil -c icns "$ICONSET_DIR"
    
    # Copy to app resources and update Info.plist
    cp "$ICON_PATH" "$APP_DIR/Resources/"
    
    # Add icon reference to Info.plist if it doesn't exist
    if ! grep -q "CFBundleIconFile" "$APP_DIR/Info.plist"; then
        sed -i '' 's/<dict>/<dict>\
    <key>CFBundleIconFile<\/key>\
    <string>AppIcon<\/string>/' "$APP_DIR/Info.plist"
    fi
    
    echo "App icon created successfully at $RESOURCES_DIR/AppIcon.icns"
else
    echo "PNG icon file not found at $ICON_PNG."
    # Reuse existing icon from a previous build if available
    EXISTING_ICON="Explorer/Resources/AppIcon.icns"
    if [ ! -f "$EXISTING_ICON" ]; then
        EXISTING_ICON="Explorer.app/Contents/Resources/AppIcon.icns"
    fi
    if [ -f "$EXISTING_ICON" ] && [ "$EXISTING_ICON" != "$ICON_PATH" ]; then
        cp "$EXISTING_ICON" "$ICON_PATH"
        echo "Copied existing icon from $EXISTING_ICON"
    elif [ -f "$EXISTING_ICON" ]; then
        echo "Using existing icon at $EXISTING_ICON"
    else
        echo "No icon available. You can add Explorer/Resources/icon.png to generate one."
    fi
fi

# Use a placeholder if icon creation failed
if [ ! -f "$ICON_PATH" ]; then
    echo "Icon not created. You can add one later to $ICON_PATH"
fi

# Make the binary executable
chmod +x "$MACOS_DIR/Explorer"

# Ad-hoc 签名（含 Apple Events entitlement，废纸篓需自动化权限）
ENTITLEMENTS="Explorer/Explorer.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "./$APP_NAME" 2>/dev/null \
        || echo "Warning: codesign with entitlements failed"
else
    codesign --force --deep --sign - "./$APP_NAME" 2>/dev/null \
        || echo "Warning: codesign failed"
fi

echo "Application bundle created at ./$APP_NAME"

# Quit any running instance so the new binary is loaded on launch
osascript -e 'tell application "Explorer" to quit' >/dev/null 2>&1 || true
sleep 0.3

# Open the app
open "./$APP_NAME"