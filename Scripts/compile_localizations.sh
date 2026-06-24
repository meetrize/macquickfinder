#!/bin/bash
# 将 Localizable.xcstrings 编译为 SPM 可加载的 .lproj/Localizable.strings。
# swift build 不会自动编译 String Catalog，未编译时运行时会直接显示键名（如 folder.home）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

Xcstringstool="${Xcstringstool:-$(xcrun --find xcstringstool 2>/dev/null || true)}"
if [ -z "$Xcstringstool" ] || [ ! -x "$Xcstringstool" ]; then
    echo "FAIL: 未找到 xcstringstool（需要 Xcode Command Line Tools）"
    exit 1
fi

compile_catalog() {
    local catalog="$1"
    local output_dir="$2"
    if [ ! -f "$catalog" ]; then
        echo "FAIL: 缺少 $catalog"
        exit 1
    fi
    mkdir -p "$output_dir"
    "$Xcstringstool" compile "$catalog" --output-directory "$output_dir"
    echo "OK: $catalog -> $output_dir/*.lproj"
}

compile_catalog "Sources/Explorer/Resources/Localizable.xcstrings" "Sources/Explorer/Resources"
compile_catalog "Sources/FileList/Resources/Localizable.xcstrings" "Sources/FileList/Resources"

echo "本地化编译完成。"
