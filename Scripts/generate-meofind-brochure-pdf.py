#!/usr/bin/env python3
"""Generate MeoFind-v1.0.pdf from docs/releases/MeoFind-v1.0-brochure.md"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

from fpdf import FPDF
from fpdf.fonts import FontFace

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/releases/MeoFind-v1.0-brochure.md"
FONT = Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf")
OUTPUTS = [
    ROOT / "MeoFind-Showcase/releases/MeoFind-v1.0.pdf",
    ROOT / "docs/releases/MeoFind-v1.0.pdf",
]

# fpdf2 不支持 <style> 标签，样式须通过 tag_styles 传入（否则会当正文渲染）
TAG_STYLES = {
    "h1": FontFace(family="zh", size_pt=22, color="#0c1222", emphasis="BOLD"),
    "h2": FontFace(family="zh", size_pt=15, color="#0f766e", emphasis="BOLD"),
    "h3": FontFace(family="zh", size_pt=12, color="#0f172a", emphasis="BOLD"),
    "p": FontFace(family="zh", size_pt=11, color="#1e293b"),
    "li": FontFace(family="zh", size_pt=11, color="#1e293b"),
}


def md_to_html(md_path: Path) -> str:
    result = subprocess.run(
        [
            "pandoc",
            str(md_path),
            "--from=markdown",
            "--to=html",
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    body = result.stdout.strip()
    # 若 pandoc 输出完整文档，只取 body 内层
    if "<body" in body:
        start = body.index(">", body.index("<body")) + 1
        end = body.index("</body>")
        body = body[start:end]
    # 移除 style / script，避免 fpdf2 当文本输出
    body = re.sub(r"<style[^>]*>.*?</style>", "", body, flags=re.DOTALL | re.IGNORECASE)
    body = re.sub(r"<script[^>]*>.*?</script>", "", body, flags=re.DOTALL | re.IGNORECASE)
    # fpdf2 表格单元格内不支持嵌套 strong/em/code
    body = re.sub(r"</?(strong|b|em|i|code)>", "", body)
    return body.strip()


class BrochurePDF(FPDF):
    def __init__(self) -> None:
        super().__init__(orientation="P", unit="mm", format="A4")
        self.set_auto_page_break(auto=True, margin=18)
        self.add_font("zh", "", str(FONT))
        self.add_font("zh", "B", str(FONT))
        self.add_font("zh", "I", str(FONT))
        self.add_font("zh", "BI", str(FONT))
        self.set_font("zh", size=11)

    def footer(self) -> None:
        self.set_y(-12)
        self.set_font("zh", size=8)
        self.set_text_color(100, 116, 139)
        self.cell(0, 8, f"MeoFind v1.0 · 第 {self.page_no()} 页", align="C")


def build_pdf(html: str, output: Path) -> None:
    pdf = BrochurePDF()
    pdf.add_page()
    pdf.write_html(
        html,
        font_family="zh",
        tag_styles=TAG_STYLES,
        table_line_separators=True,
        render_title_tag=False,
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(output))


def main() -> int:
    if not SOURCE.exists():
        print(f"Missing source: {SOURCE}", file=sys.stderr)
        return 1
    if not FONT.exists():
        print(f"Missing font: {FONT}", file=sys.stderr)
        return 1

    html = md_to_html(SOURCE)
    for out in OUTPUTS:
        build_pdf(html, out)
        print(f"Wrote {out} ({out.stat().st_size // 1024} KB)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
