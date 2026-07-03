#!/bin/bash
# 将 build_and_run.sh 产出的 MeoFind.app 安装到 /Applications，并尝试授予「完全磁盘访问权限」。
#
# 用法：
#   ./Scripts/install_to_applications.sh
#   ./build_install.sh
#
# 可选：在项目根目录创建 .install.local.env（见 .install.local.env.example）以非交互 sudo。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="MeoFind.app"
SRC_APP="$REPO_ROOT/$APP_NAME"
DEST_APP="/Applications/$APP_NAME"
BUNDLE_ID="com.explorer.app"
ENTITLEMENTS="$REPO_ROOT/Explorer/Explorer.entitlements"
TCC_SERVICE="kTCCServiceSystemPolicyAllFiles"
TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"

if [[ -f "$REPO_ROOT/.install.local.env" ]]; then
    # shellcheck source=/dev/null
    source "$REPO_ROOT/.install.local.env"
fi

run_sudo() {
    if [[ -n "${SUDO_PASSWORD:-}" ]]; then
        echo "$SUDO_PASSWORD" | sudo -S -p '' "$@"
    else
        sudo "$@"
    fi
}

if [[ ! -d "$SRC_APP" ]]; then
    echo "错误: 未找到 $SRC_APP，请先运行 ./build_and_run.sh 或 ./build_install.sh" >&2
    exit 1
fi

echo "==> 退出正在运行的 MeoFind"
osascript -e 'tell application "MeoFind" to quit' >/dev/null 2>&1 || true
pkill -x Explorer >/dev/null 2>&1 || true
sleep 0.2

echo "==> 安装到 $DEST_APP"
if [[ -d "$DEST_APP" ]]; then
    run_sudo rm -rf "$DEST_APP"
fi
run_sudo ditto "$SRC_APP" "$DEST_APP"
run_sudo chown -R "$(whoami):admin" "$DEST_APP"

echo "==> 对安装副本重新 ad-hoc 签名"
# app 根目录的 SPM bundle 副本会导致 deep sign 报 unsealed contents；Resources 内已有副本。
run_sudo rm -rf \
    "$DEST_APP/Explorer_Explorer.bundle" \
    "$DEST_APP/Explorer_FileList.bundle" 2>/dev/null || true

sign_app() {
    local target="$1"
    local entitlements="${2:-}"
    if [[ -n "$entitlements" && -f "$entitlements" ]]; then
        run_sudo codesign --force --sign - --entitlements "$entitlements" "$target"
    else
        run_sudo codesign --force --sign - "$target"
    fi
}

if sign_app "$DEST_APP/Contents/MacOS/Explorer" "$ENTITLEMENTS" \
    && sign_app "$DEST_APP/Contents/Library/Helpers/MeoFindDocumentOpener.app/Contents/MacOS/DocumentOpener" \
    && sign_app "$DEST_APP"; then
    echo "    签名完成"
else
    echo "警告: codesign 部分失败，完全磁盘访问可能需手动重新授权"
fi

open_full_disk_access_settings() {
    echo "==> 打开「完全磁盘访问」系统设置（请手动勾选 MeoFind）"
    open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles" \
        2>/dev/null \
        || open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" \
        2>/dev/null \
        || true
}

grant_full_disk_access() {
    local client="$1"
    local client_type="$2"
    local now
    now="$(date +%s)"

    if [[ ! -f "$TCC_DB" ]]; then
        echo "警告: 未找到 TCC 数据库 $TCC_DB"
        return 1
    fi

    run_sudo sqlite3 "$TCC_DB" <<SQL
INSERT OR REPLACE INTO access
  (service, client, client_type, auth_value, auth_reason, auth_version,
   csreq, policy_id, indirect_object_identifier_type, indirect_object_identifier,
   indirect_object_code_id, flags, last_modified)
VALUES
  ('$TCC_SERVICE', '$client', $client_type, 2, 4, 1,
   NULL, NULL, 0, 'UNUSED', NULL, 0, $now);
SQL
}

echo "==> 尝试授予「完全磁盘访问权限」"
FDA_OK=false
if grant_full_disk_access "$BUNDLE_ID" 0; then
    echo "    已写入 Bundle ID: $BUNDLE_ID"
    FDA_OK=true
else
    echo "    Bundle ID 写入失败"
fi

if grant_full_disk_access "$DEST_APP" 1; then
    echo "    已写入应用路径: $DEST_APP"
    FDA_OK=true
else
    echo "    应用路径写入失败"
fi

if $FDA_OK; then
    echo "==> 刷新 TCC 守护进程"
    run_sudo killall tccd 2>/dev/null || true
    sleep 0.5
    echo "    完全磁盘访问权限已写入 TCC 数据库"
else
    echo "==> 无法自动写入 TCC 数据库（新版 macOS 默认保护系统 TCC.db）"
    open_full_disk_access_settings
fi

echo ""
echo "==> 安装完成: $DEST_APP"
echo ""
if ! $FDA_OK; then
    echo "请在上方的系统设置中，为 MeoFind 开启「完全磁盘访问」。"
    echo "（若需脚本自动写入，需在恢复模式下关闭 SIP 后再运行本脚本。）"
else
    echo "请重启 MeoFind 以使完全磁盘访问权限生效："
    echo "  open -a /Applications/MeoFind.app"
fi
