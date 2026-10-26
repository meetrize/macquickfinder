#!/bin/bash
# 将 Localizable.xcstrings 编译为 SPM 可加载的 .lproj/Localizable.strings。
# swift build 不会自动编译 String Catalog；未同步时运行时会直接显示键名（如 snippets.ask.form_title）。
#
# 使用 Scripts/xcstrings_to_strings.py 生成经典文本 .strings。
# 说明：完整 Xcode 的 xcstringstool 会写出 XML/binary plist，本仓库校验与历史
# 工作流按 `"key" = "value";` 文本格式；且 SPM 若同时处理 .xcstrings 与 .lproj
# 会 Multiple commands produce。故统一用 Python 写 .lproj，构建时再暂存 .xcstrings。
# 禁止「只改 .xcstrings 却不更新 .lproj」。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

compile_with_python() {
    local catalog="$1"
    local output_dir="$2"
    python3 "$ROOT/Scripts/xcstrings_to_strings.py" "$catalog" "$output_dir"
}

compile_catalog() {
    local catalog="$1"
    local output_dir="$2"
    if [ ! -f "$catalog" ]; then
        echo "FAIL: 缺少 $catalog"
        exit 1
    fi
    compile_with_python "$catalog" "$output_dir"
}

compile_catalog "Sources/Explorer/Resources/Localizable.xcstrings" "Sources/Explorer/Resources"
compile_catalog "Sources/FileList/Resources/Localizable.xcstrings" "Sources/FileList/Resources"

# 硬校验：catalog 中的键必须出现在 en.lproj（防止静默漏编）
python3 - <<'PY'
import json
import re
import sys
from pathlib import Path

def unescape(s: str) -> str:
    out = []
    i = 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            nxt = s[i + 1]
            mapping = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}
            out.append(mapping.get(nxt, nxt))
            i += 2
            continue
        out.append(s[i])
        i += 1
    return "".join(out)

def load_strings_keys(path: Path) -> set[str]:
    keys = set()
    for m in re.finditer(r'^"((?:\\.|[^"\\])*)"\s*=', path.read_text(encoding="utf-8"), re.M):
        keys.add(unescape(m.group(1)))
    return keys

def check(catalog: Path, strings_path: Path) -> list[str]:
    data = json.loads(catalog.read_text(encoding="utf-8"))
    catalog_keys = set(data.get("strings", {}))
    strings_keys = load_strings_keys(strings_path)
    return sorted(catalog_keys - strings_keys)

failures = []
pairs = [
    (
        Path("Sources/Explorer/Resources/Localizable.xcstrings"),
        Path("Sources/Explorer/Resources/en.lproj/Localizable.strings"),
    ),
    (
        Path("Sources/FileList/Resources/Localizable.xcstrings"),
        Path("Sources/FileList/Resources/en.lproj/Localizable.strings"),
    ),
]
for catalog, strings in pairs:
    if not strings.is_file():
        print(f"FAIL: 缺少 {strings}", file=sys.stderr)
        sys.exit(1)
    missing = check(catalog, strings)
    if missing:
        failures.append((catalog, missing))

if failures:
    for catalog, missing in failures:
        print(
            f"FAIL: {catalog} 有 {len(missing)} 个键未进入 "
            f"{catalog.parent / 'en.lproj/Localizable.strings'}",
            file=sys.stderr,
        )
        for k in missing[:20]:
            print(f"  - {k}", file=sys.stderr)
        if len(missing) > 20:
            print(f"  …(+{len(missing)-20})", file=sys.stderr)
    sys.exit(1)

print("本地化编译完成（已校验 catalog ⊆ en.lproj）。")
PY
