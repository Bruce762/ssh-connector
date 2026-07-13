#!/bin/bash

# 從同目錄下的 .env 讀取設定（該檔案不會進 git）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ 找不到 $ENV_FILE，請參考 .env.example 建立設定檔"
    exit 1
fi

source "$ENV_FILE"

if [ -z "$USER_NAME" ] || [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "❌ .env 內缺少 USER_NAME、TELEGRAM_BOT_TOKEN 或 TELEGRAM_CHAT_ID"
    exit 1
fi

# Host alias 寫進 ~/.ssh/config 用
HOST_ALIAS="home-computer"
SSH_CONFIG="$HOME/.ssh/config"

echo "🔍 正在從 Telegram 取得最新網址..."

# 2. 呼叫 Telegram getChat，讀取釘選訊息（bot 主動發的訊息不會出現在 getUpdates，只能靠釘選訊息取得）
RESPONSE=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getChat?chat_id=${TELEGRAM_CHAT_ID}")

if [ -z "$RESPONSE" ]; then
    echo "❌ 無法連線 Telegram API，請檢查網路。"
    exit 1
fi

# 3. 用正規表示式精準萃取出網域（先把 JSON 內的 \n 跳脫符號換成空白，避免吃到多餘的 n；取最後一筆，也就是最新的）
DOMAIN=$(echo "$RESPONSE" | sed 's/\\n/ /g' | grep -o '[a-zA-Z0-9.-]*\.trycloudflare\.com' | tail -n 1)

if [ -z "$DOMAIN" ]; then
    echo "❌ 找不到有效的 Cloudflare 網址，請確認 host 端腳本已執行並成功釘選訊息。"
    exit 1
fi

echo "✅ 成功取得網址: $DOMAIN"
echo "🚀 準備連線..."

# 4. 檢查外部筆電是否有安裝 cloudflared
if ! command -v cloudflared &> /dev/null; then
    echo "❌ 你的筆電尚未安裝 cloudflared。請先執行: brew install cloudflared"
    exit 1
fi

# 5. 自動寫入/更新 ~/.ssh/config 內的 managed block（不會動到其他 Host 設定）
mkdir -p "$(dirname "$SSH_CONFIG")"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

START_MARK="# >>> ssh_client managed block ($HOST_ALIAS) >>>"
END_MARK="# <<< ssh_client managed block ($HOST_ALIAS) <<<"

# 先移除舊的 block（如果有）
awk -v start="$START_MARK" -v end="$END_MARK" '
    $0 == start {skip=1}
    !skip {print}
    $0 == end {skip=0}
' "$SSH_CONFIG" > "${SSH_CONFIG}.tmp" && mv "${SSH_CONFIG}.tmp" "$SSH_CONFIG"

# 再附加最新的 block
{
    echo ""
    echo "$START_MARK"
    echo "Host $HOST_ALIAS"
    echo "    HostName $DOMAIN"
    echo "    User $USER_NAME"
    echo "    ProxyCommand $(which cloudflared) access ssh --hostname %h"
    echo "    StrictHostKeyChecking no"
    echo "    UserKnownHostsFile /dev/null"
    echo "$END_MARK"
} >> "$SSH_CONFIG"

echo "✅ 已更新 $SSH_CONFIG (Host: $HOST_ALIAS)"
echo ""
echo "👉 請自行執行以下指令連線："
echo ""
echo "    ssh $HOST_ALIAS"
echo ""