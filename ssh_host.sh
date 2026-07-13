#!/bin/bash

LAST_URL=""

for cmd in cloudflared curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ 找不到指令：$cmd，請先安裝後再執行"
        exit 1
    fi
done

# 從同目錄下的 .env 讀取設定（該檔案不會進 git）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ 找不到 $ENV_FILE，請參考 .env.example 建立設定檔"
    exit 1
fi

source "$ENV_FILE"

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "❌ .env 內缺少 TELEGRAM_BOT_TOKEN 或 TELEGRAM_CHAT_ID"
    exit 1
fi

# 要暴露的本機 SSH port，預設 22，可在 .env 用 SSH_LOCAL_PORT 覆寫
SSH_LOCAL_PORT="${SSH_LOCAL_PORT:-22}"

echo "啟動 Cloudflare Tunnel 並監聽網址中..."

cloudflared tunnel --url "tcp://localhost:${SSH_LOCAL_PORT}" 2>&1 | while read -r line; do
    
    if echo "$line" | grep -q "trycloudflare.com"; then
        
        URL=$(echo "$line" | grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' | head -n 1)
        
        if [ ! -z "$URL" ] && [ "$URL" != "$LAST_URL" ]; then
            LAST_URL="$URL"
            CLEAN_DOMAIN=${URL#https://}
            
            # 取得當前時間，格式例如：2026-07-13 16:19:33
            UPDATE_TIME=$(date "+%Y-%m-%d %H:%M:%S")
            
            echo "擷取到新網址: $CLEAN_DOMAIN"

            # 組裝 Telegram 訊息內容
            MESSAGE=$(printf "🔔 最新 SSH 網址 (%s)\n請複製以下網址連線：\n\n%s" "$UPDATE_TIME" "$CLEAN_DOMAIN")

            SEND_RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                --data-urlencode chat_id="${TELEGRAM_CHAT_ID}" \
                --data-urlencode text="${MESSAGE}")

            if echo "$SEND_RESPONSE" | grep -q '"ok":true'; then
                MESSAGE_ID=$(echo "$SEND_RESPONSE" | grep -o '"message_id":[0-9]*' | head -n 1 | grep -o '[0-9]*')

                # 先取消釘選所有舊訊息，確保 client 端讀到的一定是最新網址
                curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/unpinAllChatMessages" \
                    --data-urlencode chat_id="${TELEGRAM_CHAT_ID}" > /dev/null

                PIN_RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/pinChatMessage" \
                    --data-urlencode chat_id="${TELEGRAM_CHAT_ID}" \
                    --data-urlencode message_id="${MESSAGE_ID}" \
                    --data-urlencode disable_notification=true)

                if echo "$PIN_RESPONSE" | grep -q '"ok":true'; then
                    echo "✅ 已成功發送並釘選 Telegram 通知！"
                else
                    echo "⚠️ 訊息已發送，但釘選失敗: $PIN_RESPONSE"
                fi
            else
                echo "❌ Telegram 通知發送失敗: $SEND_RESPONSE"
            fi
        fi
    fi
done