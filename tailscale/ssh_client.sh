#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
CHECK_TAILSCALE=yes
while [ "$#" -gt 0 ]; do
    case "$1" in
        --skip-tailscale) CHECK_TAILSCALE=no; shift ;;
        --help)
            echo '用法：bash tailscale/ssh_client.sh [--skip-tailscale] [主機IPv4或DNS名稱 使用者 [別名]]'
            echo '未提供的位址、使用者與別名會互動詢問；預設 SSH port 22。'
            echo '不提供主機位址時，會先詢問使用 Tailscale 或其他 VPN／區網。'
            echo '--skip-tailscale：使用其他 VPN 或區網時，略過 Tailscale 檢查。'
            exit 0 ;;
        --) shift; break ;;
        -*) die "不支援的選項：$1，請使用 --help。" ;;
        *) break ;;
    esac
done
[ "$#" -le 3 ] || die '參數太多，請使用 --help。'
[ "$(id -u)" -ne 0 ] || die '請用自己的帳號執行，不要 sudo 整支腳本。'
REMOTE_HOST=${1:-}
REMOTE_USER=${2:-}
HOST_ALIAS=${3:-}
SSH_CONFIG="${SSH_DIR:-$HOME/.ssh}/config"
printf '\n目前已設定的連線別名（%s）：\n' "$SSH_CONFIG"
EXISTING_ALIASES=''
if [ -f "$SSH_CONFIG" ]; then
    EXISTING_ALIASES=$(awk '
        {
            line=$0
            sub(/#.*/, "", line)
            sub(/^[ \t]+/, "", line)
            sub(/^[Hh][Oo][Ss][Tt][ \t]*=[ \t]*/, "Host ", line)
            count=split(line, fields, /[ \t]+/)
            if (tolower(fields[1]) != "host") next
            for (i=2; i<=count; i++) {
                alias=fields[i]
                gsub(/"/, "", alias)
                if (alias == "" || alias ~ /[*?!]/ || seen[alias]++) continue
                printf "  - %s\n", alias
            }
        }
    ' "$SSH_CONFIG")
fi
if [ -n "$EXISTING_ALIASES" ]; then
    printf '%s\n' "$EXISTING_ALIASES"
else
    echo '  （尚無連線別名）'
fi
echo '不同名稱會保留多筆設定；使用相同名稱會更新該筆 Tailscale 設定。'
if [ -z "$REMOTE_HOST" ]; then
    if [ "$CHECK_TAILSCALE" = yes ]; then
        printf '\n請選擇連線網路：\n  1) Tailscale\n  2) 其他 VPN／區網（略過 Tailscale 檢查）\n'
        while true; do
            read -r -p '請輸入 1 或 2（直接 Enter 使用 Tailscale）：' NETWORK_CHOICE
            case "$NETWORK_CHOICE" in
                ''|1) break ;;
                2) CHECK_TAILSCALE=no; break ;;
                *) echo '請輸入 1 或 2。' ;;
            esac
        done
    fi
    if [ "$CHECK_TAILSCALE" = yes ]; then
        read -r -p '家裡電腦的 Tailscale IP 或 MagicDNS 名稱：' REMOTE_HOST
    else
        read -r -p '家裡電腦可連線的 IPv4 或 DNS 名稱（VPN／區網位址）：' REMOTE_HOST
    fi
fi
[ -n "$REMOTE_USER" ] || read -r -p '家裡電腦的登入帳號（在那台電腦執行 whoami 取得）：' REMOTE_USER
[ -n "$HOST_ALIAS" ] || read -r -p '這台電腦的連線名稱（例如 home-imac 或 home-windows；同名會更新既有設定）：' HOST_ALIAS
# Ignore surrounding whitespace introduced when copying the account name.
REMOTE_USER="${REMOTE_USER#"${REMOTE_USER%%[![:space:]]*}"}"
REMOTE_USER="${REMOTE_USER%"${REMOTE_USER##*[![:space:]]}"}"
[[ "$REMOTE_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || die '主機必須是 IPv4 或 DNS 名稱。'
# Account naming rules belong to the remote OS; allow numeric and locale-aware
# alphanumeric names while rejecting whitespace and SSH config metacharacters.
[[ "$REMOTE_USER" =~ ^[[:alnum:]_][[:alnum:]_.@-]*[$]?$ ]] || die '登入帳號格式不支援。請填入被連線電腦上 whoami 的輸出，不要填顯示名稱、整段 SSH 指令或附加主機 IP。'
[[ "$HOST_ALIAS" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || die '連線名稱不可空白，須以英數字開頭，且只接受英數字、底線與連字號。'
need ssh
need ssh-keygen
if [ "$CHECK_TAILSCALE" = yes ]; then
    check_tailscale
fi
prepare_ssh_dir
KEY_PATH="$SSH_DIR/id_ed25519_tailscale"
SSH_CONFIG="$SSH_DIR/config"
[ ! -L "$SSH_CONFIG" ] || die 'config 是符號連結，請先改用一般檔案。'
if [ ! -e "$KEY_PATH" ]; then
    [ ! -e "$KEY_PATH.pub" ] || die '只找到公鑰，請先找回配對的私鑰或移走此孤立公鑰。'
    echo '建立這台電腦專用的金鑰；請依提示設定金鑰密碼（passphrase）。'
    ssh-keygen -t ed25519 -a 100 -C "$(id -un)@$(hostname)-tailscale" -f "$KEY_PATH"
fi
[ -f "$KEY_PATH" ] || die '私鑰路徑不是一般檔案。'
chmod 600 "$KEY_PATH"
TMP_PUB=$(mktemp "$SSH_DIR/.tailscale-pub.XXXXXX")
TMP_CONFIG=''
cleanup() { rm -f "$TMP_PUB"; [ -z "$TMP_CONFIG" ] || rm -f "$TMP_CONFIG"; }
trap cleanup EXIT
# Derive from the private key so a missing or stale .pub cannot install the wrong key.
ssh-keygen -y -f "$KEY_PATH" > "$TMP_PUB"
cp "$TMP_PUB" "$KEY_PATH.pub"
chmod 644 "$KEY_PATH.pub"
SSH_ARGS=(-F /dev/null -o StrictHostKeyChecking=ask -o ConnectTimeout=15
    -o "UserKnownHostsFile=\"$SSH_DIR/known_hosts\""
    -o IdentitiesOnly=yes -i "$KEY_PATH" -p 22 -l "$REMOTE_USER")
echo '安裝公鑰：首次請核對主機指紋，並輸入遠端帳號密碼（或既有金鑰密碼）。'
ssh "${SSH_ARGS[@]}" "$REMOTE_HOST" 'sh -c '\''set -eu
    umask 077
    IFS= read -r key
    case "$key" in ssh-ed25519\ *) ;; *) echo "Invalid public key" >&2; exit 1;; esac
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    if ! grep -qxF "$key" "$HOME/.ssh/authorized_keys"; then
        printf "\n%s\n" "$key" >> "$HOME/.ssh/authorized_keys"
    fi'\''' < "$TMP_PUB"
echo '驗證金鑰登入（可能需要再次輸入金鑰密碼）：'
ssh "${SSH_ARGS[@]}" -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no \
    -o PreferredAuthentications=publickey "$REMOTE_HOST" true || die '金鑰驗證失敗，尚未修改 SSH config。'

START_MARK="# >>> tailscale managed ($HOST_ALIAS) >>>"
END_MARK="# <<< tailscale managed ($HOST_ALIAS) <<<"
TMP_CONFIG=$(mktemp "$SSH_DIR/.tailscale-config.XXXXXX")
{
    printf '%s\nHost %s\n' "$START_MARK" "$HOST_ALIAS"
    printf '    HostName %s\n    User "%s"\n    Port 22\n' "$REMOTE_HOST" "$REMOTE_USER"
    printf '    IdentityFile "%s"\n' "$KEY_PATH"
    printf '    IdentitiesOnly yes\n    AddKeysToAgent yes\n    StrictHostKeyChecking ask\n'
    printf '    UserKnownHostsFile "%s/known_hosts"\n' "$SSH_DIR"
    printf '    PasswordAuthentication no\n    KbdInteractiveAuthentication no\n'
    printf '    ProxyCommand none\n    ProxyJump none\n'
    if [ "$(uname -s)" = Darwin ]; then printf '    UseKeychain yes\n'; fi
    printf 'Host *\n%s\n' "$END_MARK"
    if [ -f "$SSH_CONFIG" ]; then
        awk -v start="$START_MARK" -v end="$END_MARK" '
            $0 == start {if (skip) exit 1; skip=1; next}
            $0 == end {if (!skip) exit 1; skip=0; next}
            !skip {print}
            END {if (skip) exit 1}
        ' "$SSH_CONFIG"
    fi
} > "$TMP_CONFIG" || die '既有 managed block 不完整，未修改 config。'
ssh -G -F "$TMP_CONFIG" "$HOST_ALIAS" >/dev/null || die 'SSH config 語法驗證失敗，未修改 config。'
if [ -f "$SSH_CONFIG" ]; then
    BACKUP=$(mktemp "$SSH_DIR/config.backup.XXXXXX")
    cp -p "$SSH_CONFIG" "$BACKUP"
    printf '原設定已備份至 %s\n' "$BACKUP"
fi
chmod 600 "$TMP_CONFIG"
mv "$TMP_CONFIG" "$SSH_CONFIG"
TMP_CONFIG=''
printf '\n完成！之後執行：ssh %s\n' "$HOST_ALIAS"
if [ "$SSH_DIR" != "$HOME/.ssh" ]; then
    printf '使用自訂 SSH_DIR 時請加上：ssh -F "%s" %s\n' "$SSH_CONFIG" "$HOST_ALIAS"
fi
