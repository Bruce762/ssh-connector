#!/bin/bash
# macOS 雙擊啟動器 → 執行Cloudflare 方案目錄的 ssh_host.sh
cd "$(dirname "$0")/.." || exit 1
./ssh_host.sh
echo ""
echo "（按 Enter 關閉視窗）"
read -r
