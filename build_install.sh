#!/bin/bash
# 编译打包 → 安装到 /Applications → 尝试授予完全磁盘访问权限
#
# 首次使用（可选，避免每次输入 sudo 密码）：
#   cp .install.local.env.example .install.local.env
#   # 编辑 .install.local.env，填入 SUDO_PASSWORD=你的密码
#
# 日常：
#   ./build_install.sh

set -euo pipefail
cd "$(dirname "$0")"

export SKIP_OPEN=1
export BUILD_CONFIG="${BUILD_CONFIG:-debug}"
export FAST_DEBUG="${FAST_DEBUG:-1}"

./build_and_run.sh "$@"
./Scripts/install_to_applications.sh
