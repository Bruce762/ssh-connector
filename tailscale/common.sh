#!/bin/bash
# Shared by the entry points; compatible with macOS Bash 3.2.
set -euo pipefail

die() { printf '錯誤：%s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "找不到 $1，請先安裝。"; }

check_tailscale() {
    if command -v tailscale >/dev/null 2>&1; then
        TS_BIN=$(command -v tailscale)
    elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
        TS_BIN=/Applications/Tailscale.app/Contents/MacOS/Tailscale
    else
        die '請先安裝 Tailscale 並登入：https://tailscale.com/download'
    fi
    "$TS_BIN" status >/dev/null || die '請開啟 Tailscale、登入並連線後重試。'
    TS_IP=$("$TS_BIN" ip -4) || die '無法取得 Tailscale IP。'
    [ -n "$TS_IP" ] || die 'Tailscale 尚未連線。'
}

prepare_ssh_dir() {
    SSH_DIR=${SSH_DIR:-$HOME/.ssh}
    case "$SSH_DIR" in /*) ;; *) die 'SSH_DIR 必須是絕對路徑。';; esac
    # These characters have special meaning in ssh_config values.
    case "$SSH_DIR" in *\"*|*\\*|*%*|*'$'*|*$'\n'*|*$'\r'*) die 'SSH_DIR 包含不支援的字元。';; esac
    umask 077
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
}
