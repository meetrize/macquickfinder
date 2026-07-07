#!/bin/bash
# 将 Localizable.xcstrings 编译为 SPM 可加载的 .lproj/Localizable.strings。
# swift build 不会自动编译 String Catalog，未编译时运行时会直接显示键名（如 folder.home）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

Xcstringstool="${Xcstringstool:-$(xcrun --find xcstringstool 2>/dev/null || true)}"

required_outputs=(
    "Sources/Explorer/Resources/en.lproj/Localizable.strings"
    "Sources/Explorer/Resources/zh-Hans.lproj/Localizable.strings"
    "Sources/FileList/Resources/en.lproj/Localizable.strings"
    "Sources/FileList/Resources/zh-Hans.lproj/Localizable.strings"
)

if [ -z "$Xcstringstool" ] || [ ! -x "$Xcstringstool" ]; then
    missing_outputs=()
    for output in "${required_outputs[@]}"; do
        if [ ! -f "$output" ]; then
            missing_outputs+=("$output")
        fi
    done

    if [ "${#missing_outputs[@]}" -eq 0 ]; then
        echo "WARN: 未找到 xcstringstool，跳过编译，使用已有 .lproj 文件"
        echo "      （xcstringstool 随完整 Xcode 提供，非 Command Line Tools；修改 .xcstrings 后需安装 Xcode 并重新编译）"
        exit 0
    fi

    echo "FAIL: 未找到 xcstringstool，且缺少以下编译产物："
    printf '  %s\n' "${missing_outputs[@]}"
    echo "请安装 Xcode（App Store），然后执行："
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
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
