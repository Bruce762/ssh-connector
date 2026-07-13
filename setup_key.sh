#!/bin/bash

# 一次性腳本（在 client 端 / 筆電跑）：
#   步驟 1：產生連 home-computer 專用的 SSH 金鑰對
#   步驟 2：把公鑰送上家裡電腦 的 authorized_keys
# 步驟 3（IdentityFile）已寫進 ssh_client.sh，會自動處理。
# 步驟 4（關 電腦 密碼登入）屬於危險的一次性動作，維持手動，最後只印提示。

set -euo pipefail

KEY_PATH="${KEY_PATH:-$HOME/.ssh/home_computer_key}"
KEY_COMMENT="${KEY_COMMENT:-$(whoami)@$(hostname -s)-home_computer}"
HOST_ALIAS="${HOST_ALIAS:-home-computer}"
SSH_CONFIG="$HOME/.ssh/config"

# ---------- 步驟 1：產生金鑰 ----------
echo "🔑 步驟 1：產生 SSH 金鑰"
echo "    路徑：$KEY_PATH"

mkdir -p "$(dirname "$KEY_PATH")"
chmod 700 "$(dirname "$KEY_PATH")"

if [ -f "$KEY_PATH" ]; then
    echo "ℹ️  已存在金鑰：$KEY_PATH（跳過產生，不覆蓋既有私鑰）"
else
    # 不加 -N，讓 ssh-keygen 互動式問你 passphrase（強烈建議設一個）
    ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$KEY_PATH"
    echo "✅ 已產生金鑰"
fi
echo ""

# ---------- 步驟 2：把公鑰送上 home-computer ----------
echo "📤 步驟 2：把公鑰送上 $HOST_ALIAS"

# 先確認 ssh_client.sh 已經寫好 config 區塊（步驟 2 需要靠這個別名連線）
if ! grep -q "^Host $HOST_ALIAS$" "$SSH_CONFIG" 2>/dev/null; then
    echo "⚠️  在 $SSH_CONFIG 找不到 Host $HOST_ALIAS。"
    echo "    請先在 host 端跑 ssh_host.sh，再在本機跑 ssh_client.sh 產生連線設定，"
    echo "    然後重新執行本腳本，就能自動送公鑰。"
    echo "    （金鑰已備妥，之後隨時可再跑。）"
    exit 0
fi

# 讓使用者確認：這一步會用「密碼」登入 電腦 一次（因為還沒關密碼登入），把公鑰寫上去
read -r -p "現在用密碼登入 $HOST_ALIAS 一次、把公鑰寫上去？(y/N) " ans
case "$ans" in
    [yY]|[yY][eE][sS])
        if command -v ssh-copy-id >/dev/null 2>&1; then
            ssh-copy-id -i "${KEY_PATH}.pub" "$HOST_ALIAS"
        else
            # 沒有 ssh-copy-id 時的等效手動做法
            ssh "$HOST_ALIAS" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
                cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" \
                < "${KEY_PATH}.pub"
        fi
        echo "✅ 公鑰已送達"
        echo ""
        echo "🔎 驗證：現在試著用金鑰連線（應只問 passphrase，不再問 電腦 密碼）"
        echo "        ssh $HOST_ALIAS"
        ;;
    *)
        echo "略過步驟 2。之後可手動執行：ssh-copy-id -i ${KEY_PATH}.pub $HOST_ALIAS"
        ;;
esac

echo ""
echo "👉 剩下步驟 4（維持手動，最關鍵也最危險）："
echo "    確認 ssh $HOST_ALIAS 能用金鑰連進去後，"
echo "    到家裡電腦 編輯 /etc/ssh/sshd_config，設："
echo "        PasswordAuthentication no"
echo "        KbdInteractiveAuthentication no"
echo "        PubkeyAuthentication yes"
echo "    再重開「遠端登入」讓設定生效。"
