#!/bin/bash

# Exit on any error
set -e
set -o pipefail

# release（默认）或 debug（编译更快，适合日常迭代；可用 ./build_debug.sh）
BUILD_CONFIG="${BUILD_CONFIG:-release}"
FAST_DEBUG="${FAST_DEBUG:-0}"

filter_known_spm_warnings() {
    awk '
        /could not determine XCTest paths/ { skip=1; next }
        skip && (/^[[:space:]]+/ || /xcrun: error/ || /PlatformPath/) { next }
        { skip=0; print }
    '
}

# Build the project
build_args=(-c "$BUILD_CONFIG" --skip-update)
if [ "$BUILD_CONFIG" = "debug" ] && [ "$FAST_DEBUG" = "1" ]; then
    # 仅编译 Explorer 可执行目标，跳过测试与其它产物；-q 减少 SPM 输出
    build_args+=(--target Explorer -q)
fi

if [ "$BUILD_CONFIG" = "debug" ] && [ "$FAST_DEBUG" = "1" ]; then
    swift build "${build_args[@]}"
else
    swift build "${build_args[@]}" 2>&1 | filter_known_spm_warnings
fi
build_status=$?
if [ "$build_status" -ne 0 ]; then
    exit "$build_status"
fi

# Create the app bundle structure
APP_NAME="MeoFind.app"
APP_DIR="$APP_NAME/Contents"
MACOS_DIR="$APP_DIR/MacOS"
RESOURCES_DIR="$APP_DIR/Resources"
FRAMEWORKS_DIR="$APP_DIR/Frameworks"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

# Copy the executable
cp ".build/$BUILD_CONFIG/Explorer" "$MACOS_DIR/"

# Create Info.plist in Contents directory
cp Explorer/Info.plist "$APP_DIR/"

# Create PkgInfo
echo "APPL????" > "$APP_DIR/PkgInfo"

# Create app icon from PNG
ICON_PNG="Explorer/Resources/icon.png"
ICON_PATH="$RESOURCES_DIR/AppIcon.icns"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"

if [ -f "$ICON_PNG" ]; then
    # debug 快速模式：已有 icns 则完全跳过；否则仅在 PNG 更新时重建
    icon_stale=false
    if [ ! -f "$ICON_PATH" ] || [ "$ICON_PNG" -nt "$ICON_PATH" ]; then
        icon_stale=true
    fi
    if [ "$FAST_DEBUG" = "1" ] && [ -f "$ICON_PATH" ]; then
        icon_stale=false
    fi
    if [ "$icon_stale" = true ]; then
        mkdir -p "$ICONSET_DIR"
        sips -z 16 16 "$ICON_PNG" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
        sips -z 32 32 "$ICON_PNG" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
        sips -z 32 32 "$ICON_PNG" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
        sips -z 64 64 "$ICON_PNG" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
        sips -z 128 128 "$ICON_PNG" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
        sips -z 256 256 "$ICON_PNG" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
        sips -z 256 256 "$ICON_PNG" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
        sips -z 512 512 "$ICON_PNG" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
        sips -z 512 512 "$ICON_PNG" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
        sips -z 1024 1024 "$ICON_PNG" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null
        iconutil -c icns "$ICONSET_DIR" >/dev/null 2>&1
    fi

    if ! grep -q "CFBundleIconFile" "$APP_DIR/Info.plist"; then
        sed -i '' 's/<dict>/<dict>\
    <key>CFBundleIconFile<\/key>\
    <string>AppIcon<\/string>/' "$APP_DIR/Info.plist"
    fi
else
    EXISTING_ICON="Explorer/Resources/AppIcon.icns"
    if [ ! -f "$EXISTING_ICON" ]; then
        EXISTING_ICON="Explorer.app/Contents/Resources/AppIcon.icns"
    fi
    if [ -f "$EXISTING_ICON" ] && [ "$EXISTING_ICON" != "$ICON_PATH" ]; then
        cp "$EXISTING_ICON" "$ICON_PATH"
    fi
fi

# Make the binary executable
chmod +x "$MACOS_DIR/Explorer"

# Ad-hoc 签名（含 Apple Events entitlement，废纸篓需自动化权限）
ENTITLEMENTS="Explorer/Explorer.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    if [ "$FAST_DEBUG" = "1" ]; then
        # debug 仅签可执行文件，省去 --deep 遍历 bundle
        codesign --force --sign - --entitlements "$ENTITLEMENTS" "$MACOS_DIR/Explorer" 2>/dev/null \
            || echo "Warning: codesign with entitlements failed"
    else
        codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "./$APP_NAME" 2>/dev/null \
            || echo "Warning: codesign with entitlements failed"
    fi
else
    if [ "$FAST_DEBUG" = "1" ]; then
        codesign --force --sign - "$MACOS_DIR/Explorer" 2>/dev/null \
            || echo "Warning: codesign failed"
    else
        codesign --force --deep --sign - "./$APP_NAME" 2>/dev/null \
            || echo "Warning: codesign failed"
    fi
fi

# Quit any running instance so the new binary is loaded on launch
osascript -e 'tell application "MeoFind" to quit' >/dev/null 2>&1 || true
sleep 0.1

# Open the app
open "./$APP_NAME"