#!/bin/bash
# 拖拽调试：正常启动应用，在另一终端用 tail -f 查看日志。
# 不要用 swift run ... | grep，管道会导致 GUI 应用有时无法启动。

set -e
cd "$(dirname "$0")"

LOG="/tmp/macquickfinder-filedrag.log"

echo "构建中..."
swift build -c release

echo ""
echo "日志文件: $LOG"
echo "请在另一个终端运行:"
echo "  tail -f $LOG"
echo ""
echo "启动应用..."

./build_and_run.sh
