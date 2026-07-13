#!/bin/bash
# macOS 雙擊啟動器 → 執行根目錄的 ssh_client.sh
cd "$(dirname "$0")/.." || exit 1
./ssh_client.sh
echo ""
echo "（按 Enter 關閉視窗）"
read -r
