#!/bin/bash
# Phase 0 i18n 基础设施验证脚本
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_CONFIG="${BUILD_CONFIG:-release}"
echo "==> 编译 String Catalog"
bash Scripts/compile_localizations.sh

echo "==> swift build -c $BUILD_CONFIG"
swift build -c "$BUILD_CONFIG" >/dev/null

echo "==> 检查 SPM 资源 bundle"
for bundle_name in Explorer_Explorer Explorer_FileList; do
    bundle_path=$(find -L ".build/$BUILD_CONFIG" -name "${bundle_name}.bundle" -type d 2>/dev/null | head -1)
    if [ -z "$bundle_path" ]; then
        echo "FAIL: 未找到 ${bundle_name}.bundle"
        exit 1
    fi
    if [ ! -f "$bundle_path/Localizable.xcstrings" ]; then
        echo "FAIL: $bundle_path 缺少 Localizable.xcstrings"
        exit 1
    fi
    if [ ! -f "$bundle_path/en.lproj/Localizable.strings" ]; then
        echo "FAIL: $bundle_path 缺少 en.lproj/Localizable.strings（请先运行 Scripts/compile_localizations.sh）"
        exit 1
    fi
    echo "OK: $bundle_path/Localizable.xcstrings"
    echo "OK: $bundle_path/en.lproj/Localizable.strings"
done

echo "==> 检查 InfoPlist.strings"
for lproj in en zh-Hans; do
    path="Explorer/Resources/${lproj}.lproj/InfoPlist.strings"
    if [ ! -f "$path" ]; then
        echo "FAIL: 缺少 $path"
        exit 1
    fi
    echo "OK: $path"
done

echo "==> 检查 L10n 源文件"
for f in Sources/Explorer/L10n.swift Sources/FileList/L10n.swift; do
    if [ ! -f "$f" ]; then
        echo "FAIL: 缺少 $f"
        exit 1
    fi
    echo "OK: $f"
done

echo ""
echo "Phase 0 i18n 基础设施验证通过。"
