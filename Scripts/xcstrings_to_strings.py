#!/usr/bin/env python3
"""将 Localizable.xcstrings 编译为 en/zh-Hans 的 Localizable.strings。

SPM 不会自动编译 String Catalog；运行时 ModuleLocalization 从 .lproj 读文案。
无 xcstringstool（完整 Xcode）时用本脚本兜底，避免界面显示键名。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def escape_strings_value(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def extract_value(entry: dict, lang: str) -> str | None:
    locs = entry.get("localizations") or {}
    loc = locs.get(lang)
    if not isinstance(loc, dict):
        return None
    unit = loc.get("stringUnit")
    if isinstance(unit, dict):
        value = unit.get("value")
        return value if isinstance(value, str) else None
    # 简化 plurals：取 other / one 兜底
    variations = loc.get("variations") or {}
    plural = variations.get("plural") or {}
    for form in ("other", "one", "zero", "few", "many", "two"):
        form_unit = plural.get(form) or {}
        string_unit = form_unit.get("stringUnit") or {}
        value = string_unit.get("value")
        if isinstance(value, str):
            return value
    return None


def compile_catalog(catalog_path: Path, output_dir: Path, languages: list[str]) -> None:
    data = json.loads(catalog_path.read_text(encoding="utf-8"))
    strings = data.get("strings") or {}
    if not isinstance(strings, dict):
        raise SystemExit(f"FAIL: invalid catalog format: {catalog_path}")

    by_lang: dict[str, list[tuple[str, str]]] = {lang: [] for lang in languages}
    missing: list[str] = []

    for key, entry in strings.items():
        if not isinstance(entry, dict):
            continue
        # 跳过仅标注不翻译的
        if entry.get("shouldTranslate") is False and not entry.get("localizations"):
            continue
        for lang in languages:
            value = extract_value(entry, lang)
            if value is None:
                # 尝试回退到 en
                if lang != "en":
                    value = extract_value(entry, "en")
                if value is None:
                    missing.append(f"{key} ({lang})")
                    continue
            by_lang[lang].append((key, value))

    if missing:
        sample = ", ".join(missing[:8])
        more = f" …(+{len(missing) - 8})" if len(missing) > 8 else ""
        print(f"WARN: {catalog_path.name} 缺译文 {len(missing)} 条，已跳过：{sample}{more}", file=sys.stderr)

    for lang, pairs in by_lang.items():
        # 稳定顺序，便于 diff
        pairs.sort(key=lambda kv: kv[0])
        lproj = output_dir / f"{lang}.lproj"
        lproj.mkdir(parents=True, exist_ok=True)
        out = lproj / "Localizable.strings"
        lines = [
            "/* Generated from Localizable.xcstrings — do not edit by hand; run Scripts/compile_localizations.sh */",
            "",
        ]
        for key, value in pairs:
            lines.append(f'"{escape_strings_value(key)}" = "{escape_strings_value(value)}";')
        out.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"OK: {catalog_path} -> {out} ({len(pairs)} keys)")


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <Localizable.xcstrings> <output-resources-dir>", file=sys.stderr)
        raise SystemExit(2)
    catalog = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    if not catalog.is_file():
        raise SystemExit(f"FAIL: missing {catalog}")
    compile_catalog(catalog, output_dir, ["en", "zh-Hans"])


if __name__ == "__main__":
    main()
