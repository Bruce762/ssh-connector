#!/bin/bash
# 一鍵修復權限：給Cloudflare 方案目錄所有 .sh 和 mac/ 內所有 .command 加上執行權限
cd "$(dirname "$0")/.." || exit 1
chmod +x *.sh mac/*.command
echo "✅ 已為以下檔案加上執行權限："
ls -l *.sh mac/*.command
echo ""
echo "（按 Enter 關閉視窗）"
read -r
