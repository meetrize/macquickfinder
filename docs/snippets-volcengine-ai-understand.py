#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AI 文件理解 — 火山引擎 Doubao（Snippet 参考脚本，勿直接运行）"""

# ===== 配置（在 Snippet 编辑器中修改以下常量）=====
API_KEY = "45ea3371-3dee-45a9-b672-6496bb6bf7e5"
BASE_URL = "https://ark.cn-beijing.volces.com/api/v3"
TEXT_MODEL = "doubao-1-5-pro-32k-250115"  # 文本理解模型（控制台 endpoint id）
VISION_MODEL = "doubao-1.5-vision-pro-250328"  # 视觉理解模型
MODE = "summarize"  # summarize=总结理解 | rename=智能重命名
DRY_RUN = True  # rename 模式：True=仅预览，False=执行改名
MAX_TEXT_BYTES = 80000
MAX_NAME_LEN = 30
CWD = "%d"

import base64
import json
import mimetypes
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Optional, Tuple

# %Q 展开为 shell 单引号路径，shlex 可正确解析含空格的路径
SELECTED = shlex.split("%Q")

RENAME_RULES = (
    "要求：\n"
    "1. 只输出新文件名本身，不要引号、不要解释、不要 Markdown\n"
    "2. 中文场景用中文命名，英文场景用英文命名\n"
    "3. 用「-」连接词语，不含空格、斜杠、冒号等非法字符\n"
    "4. 长度不超过 30 个字符\n"
    "5. 必须依据内容理解结果，禁止照搬或微调原文件名"
)

TEXT_MIME_PREFIXES = (
    "text/",
    "application/json",
    "application/xml",
    "application/javascript",
    "application/x-sh",
    "application/sql",
    "application/x-python",
    "application/typescript",
    "application/yaml",
    "application/toml",
    "application/x-php",
    "application/rtf",
    "application/x-latex",
    "application/x-tex",
)

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".heic", ".heif", ".bmp", ".tiff"}


def log(msg: str) -> None:
    print(msg, flush=True)


def run_cmd(args, *, input_data=None, timeout=120):
    try:
        return subprocess.run(
            args,
            input=input_data,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
        return subprocess.CompletedProcess(args, 1, "", str(exc))


def mime_type(path: Path) -> str:
    proc = run_cmd(["file", "-b", "--mime-type", str(path)])
    if proc.returncode == 0 and proc.stdout.strip():
        return proc.stdout.strip()
    guess, _ = mimetypes.guess_type(str(path))
    return guess or "application/octet-stream"


def chat_completion(messages, model, max_tokens=2048) -> str:
    if not API_KEY or "在此填入" in API_KEY:
        raise RuntimeError("请先在脚本顶部配置 API_KEY")

    url = f"{BASE_URL.rstrip('/')}/chat/completions"
    payload = json.dumps(
        {"model": model, "messages": messages, "max_tokens": max_tokens}
    ).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"API HTTP {exc.code}: {body[:500]}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"API 连接失败: {exc}") from exc

    choices = data.get("choices") or []
    if not choices:
        raise RuntimeError(f"API 无返回: {json.dumps(data, ensure_ascii=False)[:300]}")
    content = choices[0].get("message", {}).get("content", "")
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(block.get("text", ""))
        content = "\n".join(parts)
    return (content or "").strip()


def ask_text(prompt: str, body: str = "") -> str:
    if body:
        user_content = f"{prompt}\n\n--- 文件内容 ---\n{body}"
    else:
        user_content = prompt
    return chat_completion([{"role": "user", "content": user_content}], TEXT_MODEL)


def ask_vision(prompt: str, image_path: Path) -> str:
    with open(image_path, "rb") as f:
        b64 = base64.standard_b64encode(f.read()).decode("ascii")
    mime = mime_type(image_path)
    if not mime.startswith("image/"):
        mime = mimetypes.guess_type(str(image_path))[0] or "image/jpeg"
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:{mime};base64,{b64}",
                        "detail": "high",
                    },
                },
            ],
        }
    ]
    return chat_completion(messages, VISION_MODEL)


def sanitize_name(name: str) -> str:
    name = re.sub(r"[\r\n]+", "", name)
    name = re.sub(r'[\\/:*?"<>|]', "-", name)
    name = name.strip()
    return name[:MAX_NAME_LEN]


def prepare_vision_image(path: Path) -> Tuple[Path, Optional[Path]]:
    proc = run_cmd(["sips", "-g", "pixelWidth", str(path)])
    width = None
    for line in proc.stdout.splitlines():
        if "pixelWidth:" in line:
            try:
                width = int(line.split(":")[-1].strip())
            except ValueError:
                pass
    if width and width > 1536:
        tmp = Path(tempfile.mktemp(suffix=".jpg", prefix="meofind-vision-"))
        if run_cmd(["sips", "-Z", "1536", str(path), "--out", str(tmp)]).returncode == 0:
            return tmp, tmp
    return path, None


def ocr_image(path: Path, limit=2000) -> str:
    if not shutil.which("tesseract"):
        return ""
    proc = run_cmd(["tesseract", str(path), "stdout", "-l", "chi_sim+eng"])
    text = re.sub(r"\s+", " ", proc.stdout or "").strip()
    return text[:limit]


def heic_to_png(path: Path) -> Tuple[Path, Optional[Path]]:
    tmp = Path(tempfile.mktemp(suffix=".png", prefix="meofind-heic-"))
    if run_cmd(["sips", "-s", "format", "png", str(path), "--out", str(tmp)]).returncode == 0:
        return tmp, tmp
    return path, None


def read_text_file(path: Path) -> str:
    try:
        with open(path, "rb") as f:
            raw = f.read(MAX_TEXT_BYTES)
        return raw.decode("utf-8", errors="replace")
    except OSError as exc:
        return f"[读取失败: {exc}]"


def pdf_text(path: Path) -> str:
    if not shutil.which("pdftotext"):
        return ""
    proc = run_cmd(["pdftotext", "-f", "1", "-l", "5", str(path), "-"])
    return (proc.stdout or "")[:MAX_TEXT_BYTES]


def video_frame(path: Path) -> Tuple[Optional[Path], Optional[Path]]:
    if not shutil.which("ffmpeg"):
        return None, None
    frame = Path(tempfile.mktemp(suffix=".jpg", prefix="meofind-frame-"))
    proc = run_cmd(
        [
            "ffmpeg", "-y", "-loglevel", "error", "-ss", "1",
            "-i", str(path), "-vframes", "1", "-q:v", "3", str(frame),
        ]
    )
    if proc.returncode == 0 and frame.exists():
        return frame, frame
    if frame.exists():
        frame.unlink(missing_ok=True)
    return None, None


def mdls_summary(path: Path, keys: list[str]) -> str:
    args = ["mdls"]
    for key in keys:
        args.extend(["-name", key])
    args.append(str(path))
    proc = run_cmd(args)
    return re.sub(r"\s+", " ", proc.stdout or "").strip()


def summarize_directory(path: Path) -> str:
    entries = []
    try:
        for entry in sorted(path.iterdir())[:200]:
            if entry.name.startswith("."):
                continue
            kind = "目录" if entry.is_dir() else "文件"
            entries.append(f"- [{kind}] {entry.name}")
    except OSError as exc:
        return f"无法列出目录: {exc}"
    listing = "\n".join(entries) if entries else "（空目录）"
    prompt = (
        f"你是文件管理助手。请分析以下目录的结构与用途。\n\n"
        f"- 路径：{path}\n"
        f"- 目录名：{path.name}\n"
        f"- 当前工作目录：{CWD}\n\n"
        f"目录内容（最多 200 项）：\n{listing}\n\n"
        f"请用中文输出：\n"
        f"1. 3-5 句话概括该目录可能的项目/用途\n"
        f"2. 主要文件类型与组织方式\n"
        f"3. 1-2 条整理或命名建议（不要执行任何操作）"
    )
    return ask_text(prompt)


def understand_file(path: Path) -> str:
    mime = mime_type(path)
    base = path.name
    log(f">>> 分析：{base} ({mime})")

    if path.is_dir():
        return summarize_directory(path)

    ext = path.suffix.lower()

    # 文本类
    if mime.startswith(TEXT_MIME_PREFIXES) or mime in TEXT_MIME_PREFIXES:
        body = read_text_file(path)
        prompt = (
            f"请阅读以下文本文件并用中文总结。\n\n"
            f"- 路径：{path}\n- MIME：{mime}\n- 理解方式：文本直读\n\n"
            f"输出：1) 3-5 句内容概括 2) 文件类型/用途 3) 1-2 条改进建议"
        )
        return ask_text(prompt, body)

    # 图片
    if mime.startswith("image/") or ext in IMAGE_EXTS:
        analyze = path
        cleanup = []
        if mime in ("image/heic", "image/heif") or ext in (".heic", ".heif"):
            analyze, tmp = heic_to_png(path)
            if tmp:
                cleanup.append(tmp)

        ocr = ocr_image(analyze)
        if len(re.sub(r"\s", "", ocr)) > 2:
            prompt = (
                f"这是图片文件，下方为 OCR 提取文字。\n\n"
                f"- 路径：{path}\n- MIME：{mime}\n- 理解方式：图片 OCR\n"
                f"- OCR：{ocr}\n\n"
                f"请用中文总结画面主题与文字信息，3-5 句话。"
            )
            result = ask_text(prompt)
        else:
            vision_src, tmp = prepare_vision_image(analyze)
            if tmp:
                cleanup.append(tmp)
            prompt = (
                f"请观察这张图片并用中文描述。\n\n"
                f"- 路径：{path}\n- MIME：{mime}\n- 理解方式：视觉模型\n\n"
                f"输出：1) 画面主体与场景 2) 可见文字（如有）3) 可能的用途"
            )
            result = ask_vision(prompt, vision_src)

        for item in cleanup:
            item.unlink(missing_ok=True)
        return result

    # 视频
    if mime.startswith("video/"):
        frame, frame_tmp = video_frame(path)
        if frame:
            ocr = ocr_image(frame)
            if len(re.sub(r"\s", "", ocr)) > 2:
                prompt = (
                    f"这是视频关键帧 OCR 文字。\n\n"
                    f"- 路径：{path}\n- MIME：{mime}\n- OCR：{ocr}\n\n"
                    f"请用中文推断视频主题，3-5 句话。"
                )
                result = ask_text(prompt)
            else:
                vision_src, vtmp = prepare_vision_image(frame)
                if vtmp:
                    frame_tmp = vtmp
                prompt = (
                    f"这是视频第 1 秒处的关键帧截图。\n\n"
                    f"- 路径：{path}\n- MIME：{mime}\n\n"
                    f"请用中文描述画面并推断视频主题。"
                )
                result = ask_vision(prompt, vision_src)
            if frame_tmp and frame_tmp.exists():
                frame_tmp.unlink(missing_ok=True)
            return result

        meta = mdls_summary(
            path,
            [
                "kMDItemDurationSeconds",
                "kMDItemCodecs",
                "kMDItemPixelWidth",
                "kMDItemPixelHeight",
            ],
        )
        prompt = (
            f"这是视频文件，无法抽取画面，请根据元数据推断。\n\n"
            f"- 路径：{path}\n- MIME：{mime}\n- 元数据：{meta}\n\n"
            f"请用中文概括可能的内容类型与用途。"
        )
        return ask_text(prompt)

    # 音频
    if mime.startswith("audio/"):
        meta = mdls_summary(
            path,
            [
                "kMDItemDurationSeconds",
                "kMDItemAudioBitRate",
                "kMDItemAudioChannelCount",
            ],
        )
        if shutil.which("afinfo"):
            proc = run_cmd(["afinfo", str(path)])
            meta = f"{meta} {(proc.stdout or '')[:500]}"
        prompt = (
            f"这是音频文件。\n\n"
            f"- 路径：{path}\n- MIME：{mime}\n- 元数据：{meta}\n\n"
            f"请用中文推断音频类型与可能用途。"
        )
        return ask_text(prompt)

    # PDF
    if mime == "application/pdf" or ext == ".pdf":
        text = pdf_text(path)
        if text.strip():
            prompt = (
                f"请阅读 PDF 提取文本（前 5 页）并中文总结。\n\n"
                f"- 路径：{path}\n- MIME：{mime}\n"
            )
            return ask_text(prompt, text)
        prompt = (
            f"无法提取 PDF 文本，请根据路径与文件名做合理推断。\n\n"
            f"- 路径：{path}\n- 文件名：{base}\n"
        )
        return ask_text(prompt)

    # 其他
    desc = run_cmd(["file", "-b", str(path)]).stdout.strip()
    prompt = (
        f"这是无法直接读取内容的文件。\n\n"
        f"- 路径：{path}\n- MIME：{mime}\n- file 描述：{desc}\n- 扩展名：{ext or '无'}\n\n"
        f"请用中文根据类型做合理推断与说明。"
    )
    return ask_text(prompt)


def suggest_rename(path: Path, understanding: str) -> str:
    base = path.name
    stem = path.stem
    ext = path.suffix

    if path.is_dir():
        prompt = (
            f"你是目录重命名助手。根据下方「目录理解结果」输出新目录名（不含路径）。\n\n"
            f"- 原路径：{path}\n- 原名称：{base}\n\n"
            f"目录理解结果：\n{understanding}\n\n{RENAME_RULES}"
        )
    else:
        prompt = (
            f"你是文件重命名助手。根据下方「内容理解结果」输出新文件名（不含扩展名）。\n\n"
            f"- 原路径：{path}\n- 原文件名：{base}\n\n"
            f"内容理解结果：\n{understanding}\n\n{RENAME_RULES}"
        )
    raw = ask_text(prompt)
    name = sanitize_name(raw)
    if not name:
        return ""
    if path.is_dir():
        return name
    return f"{name}{ext}" if ext else name


def unique_path(directory: Path, name: str, original: Path) -> Path:
    candidate = directory / name
    if candidate == original or not candidate.exists():
        return candidate
    stem = Path(name).stem
    ext = Path(name).suffix
    i = 1
    while True:
        alt = f"{stem}-{i}{ext}" if ext else f"{stem}-{i}"
        candidate = directory / alt
        if not candidate.exists() or candidate == original:
            return candidate
        i += 1


def main() -> int:
    if not SELECTED:
        log("错误：未选中任何文件或文件夹。")
        return 1

    log(f">>> 共 {len(SELECTED)} 项 | 模式：{MODE} | 模型：{TEXT_MODEL} / {VISION_MODEL}")
    log("---")

    ok = 0
    for raw in SELECTED:
        path = Path(raw)
        if not path.exists():
            log(f"⚠️  跳过（不存在）：{raw}")
            continue

        try:
            understanding = understand_file(path)
        except Exception as exc:
            log(f"⚠️  理解失败：{path.name} — {exc}")
            continue

        if MODE == "summarize":
            log(understanding)
            log("---")
            ok += 1
            continue

        if MODE == "rename":
            new_name = suggest_rename(path, understanding)
            if not new_name:
                log(f"⚠️  跳过（AI 未返回有效名称）：{path.name}")
                continue
            new_path = unique_path(path.parent, new_name, path)
            if new_path == path:
                log(f"＝ 无需改名：{path.name}")
                ok += 1
                continue
            if DRY_RUN:
                log(f"🔍 预览：{path.name}  →  {new_path.name}")
            else:
                path.rename(new_path)
                log(f"✅ 已改名：{path.name}  →  {new_path.name}")
            ok += 1
            continue

        log(f"⚠️  未知 MODE：{MODE}")
        return 1

    if MODE == "rename" and DRY_RUN:
        log("")
        log("以上为预览结果，未修改任何文件。确认无误后将 DRY_RUN 改为 False 再运行。")

    log(f">>> 完成 {ok}/{len(SELECTED)} 项")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
