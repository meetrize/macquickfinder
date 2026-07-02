#!/usr/bin/env bash
set -euo pipefail

# Smart Commit Script
# Usage: DEEPSEEK_API_KEY="key" HTTPS_PROXY="http://127.0.0.1:7890" ./smart-commit.sh "scope"

exec python3 "$(dirname "$0")/smart-commit.py" "$@"
