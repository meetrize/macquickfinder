#!/bin/bash
# 日常开发用：debug 编译（无优化、仅 Explorer 目标），比 release 快约 2 倍
cd "$(dirname "$0")"
export BUILD_CONFIG=debug
export FAST_DEBUG=1
exec ./build_and_run.sh "$@"
