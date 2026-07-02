#!/usr/bin/env python3
"""Smart commit script - AI powered commit messages via DeepSeek API."""

import json
import os
import re
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str], cwd: str | None = None) -> str:
    """Run a shell command and return stdout."""
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=30, cwd=cwd
    )
    return result.stdout.strip()


def git_diff_size() -> int:
    return len(run(["git", "diff", "HEAD"]))


def get_file_summary():
    """Get concise per-file change summary."""
    staged = set(run(["git", "diff", "--cached", "--name-only"]).splitlines())
    untracked = set(run(["git", "ls-files", "--others", "--exclude-standard"]).splitlines())
    modified = set(run(["git", "diff", "--name-only"]).splitlines())
    all_files = sorted(set(staged) | set(untracked) | set(modified))

    summaries = []
    total_diff_size = git_diff_size()

    for f in all_files:
        numstat_str = run(["git", "diff", "HEAD", "--numstat", f])
        parts = numstat_str.split("\t") if numstat_str.strip() else ["-", "-", "-"]
        try:
            added = int(parts[0]) if parts[0] and parts[0] != "-" else 0
        except ValueError:
            added = 0
        try:
            removed = int(parts[1]) if parts[1] and parts[1] != "-" else 0
        except ValueError:
            removed = 0
        flags = []
        if staged and f in staged:
            flags.append("staged")
        if untracked and f in untracked:
            flags.append("untracked")
        if modified and f in modified:
            flags.append("modified")
        s = f"  {f} (+{added}/-{removed}) {' '.join(flags)}"
        summaries.append(s)

    # For small diffs include full content, otherwise just summaries
    output_lines = [
        "Files changed:",
        *summaries,
        "",
    ]

    if total_diff_size < 15000:
        output_lines.append("=== FULL DIFF ===")
        output_lines.append(run(["git", "diff", "HEAD"]))
    else:
        output_lines.append(f"Total diff size: {total_diff_size} bytes (partial)")
        for f in all_files:
            fsize = len(run(["git", "diff", "HEAD", "--", f]))
            if fsize > 0 and fsize <= 3000:
                output_lines += [f"\n--- {f} ---", run(["git", "diff", "HEAD", "--", f])]

    return "\n".join(output_lines)


def build_api_payload(context_text: str, scope: str):
    system_prompt = (
        "You are a professional Git commit message writer following Conventional Commits.\n"
        "Rules:\n"
        "- First line: <type>(<scope>): <description>\n"
        "- Type: feat|fix|chore|refactor|docs|style|test|build|ci\n"
        "- Present tense imperative mood, max 72 chars first line\n"
        "- Optional brief body explaining WHAT and WHY\n"
        "- Output ONLY the commit message, no backticks, no explanation"
    )
    user_prompt = (
        f"Recent commits:\n```\n"
        f"{run(['git', 'log', '--oneline', '-5'])}\n```"
        f"\n\n{context_text}"
        f"\n\nScope hint: {scope}"
        f"\n\nGenerate a Conventional Commits formatted commit message."
    )

    return {
        "model": "deepseek-v4-flash",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "max_completion_tokens": 500,
        "temperature": 0.2,
    }


def call_deepseek(payload: dict, api_key: str, proxy: str | None = None) -> str:
    """Call DeepSeek API and return generated commit message."""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    import http.client
    from urllib.parse import urlparse

    url = "https://api.deepseek.com/v1/chat/completions"
    data = json.dumps(payload).encode("utf-8")
    parsed = urlparse(url)

    if proxy:
        p_parsed = urlparse(proxy)
        conn = http.client.HTTPSConnection(p_parsed.hostname, p_parsed.port or 443)
        conn.set_tunnel(parsed.hostname, parsed.port or 443)
    else:
        conn = http.client.HTTPSConnection(parsed.hostname, parsed.port or 443)

    try:
        conn.request("POST", parsed.path, body=data, headers=headers)
        resp = conn.getresponse()
        body = resp.read().decode("utf-8")
        result = json.loads(body)

        if "error" in result:
            raise RuntimeError(f"API error: {result['error']}")

        msg = result["choices"][0]["message"]["content"].strip()
        msg = msg.lstrip("`").rstrip("`").strip()
        lines = [l.strip() for l in msg.split("\n") if l.strip()]
        return "\n".join(lines) if lines else ""
    finally:
        conn.close()


def main():
    scope = sys.argv[1] if len(sys.argv) > 1 else "general"
    api_key = os.environ.get("DEEPSEEK_API_KEY")
    proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("http_proxy")

    if not api_key:
        print("ERROR: DEEPSEEK_API_KEY env var is not set")
        sys.exit(1)

    # Auth check + connectivity test
    print("Testing API connection...")
    test_payload = {
        "model": "deepseek-v4-flash",
        "messages": [{"role": "user", "content": "hi"}],
        "max_completion_tokens": 5,
        "temperature": 0.2,
    }
    try:
        call_deepseek(test_payload, api_key, proxy)
        print("Connection OK")
    except Exception as e:
        print(f"API error: {e}")
        sys.exit(1)

    # Build context
    file_context = get_file_summary()
    file_count = len(file_context.splitlines())

    if file_count == 1:
        print("No changes detected.")
        sys.exit(0)

    changed_files = file_context.split("\n")[1:]
    changed_files = [f for f in changed_files if f.startswith("  ")]
    print(f"Detected {len(changed_files)} changed file(s)")

    payload = build_api_payload(file_context, scope)

    try:
        generated_msg = call_deepseek(payload, api_key, proxy)
    except Exception as e:
        print(f"AI request failed: {e}")
        generated_msg = "chore: update code"

    if not generated_msg:
        generated_msg = "chore: update code"

    # Show and confirm
    print()
    print("Generated commit message:")
    print("=" * 42)
    for line in generated_msg.split("\n"):
        print(f"  {line}")
    print("=" * 42)

    confirm = input("Use this message? [Y/n]: ").strip().lower()
    if confirm in ("n", "no", "f"):
        custom = input("Enter custom message (or Enter to cancel): ").strip()
        if custom:
            auto_push(custom, api_key, proxy)
        print("Cancelled.")
        return

    auto_push(generated_msg, api_key, proxy)


def auto_push(msg: str, api_key=None, proxy=None):
    """Stage, commit, and push."""
    subprocess.run(["git", "add", "-A"], check=True)
    subprocess.run(["git", "commit", "-m", msg], check=True)

    branch = run(["git", "branch", "--show-current"])
    remote_branch = f"origin/{branch}"

    try:
        subprocess.check_call(["git", "rev-parse", "--verify", remote_branch])
        subprocess.run(["git", "push", "origin", branch], check=True)
    except subprocess.CalledProcessError:
        subprocess.run(["git", "push", "-u", "origin", branch], check=True)
        print(f"Set upstream: origin/{branch}")

    print(f"Completed on branch: {branch}")


if __name__ == "__main__":
    main()
