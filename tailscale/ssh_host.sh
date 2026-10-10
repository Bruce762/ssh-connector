#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
if [ "${1:-}" = --help ]; then
    echo '用法：bash tailscale/ssh_host.sh（在被連線的 macOS / Linux 電腦執行）'
    exit 0
fi
[ "$#" -eq 0 ] || die '不接受參數，請使用 --help。'
[ "$(id -u)" -ne 0 ] || die '請用自己的帳號執行，不要 sudo 整支腳本。'
check_tailscale
prepare_ssh_dir
case "$(uname -s)" in
    Darwin)
        need sudo
        if ! sudo /usr/sbin/systemsetup -setremotelogin on; then
            die '無法啟用遠端登入。請在「系統設定 → 隱私權與安全性 → 完整磁碟存取權」授權目前使用的終端機／IDE，重開後重試；或在「一般 → 共享」開啟遠端登入。'
        fi
        sudo /usr/sbin/systemsetup -getremotelogin | grep -qi 'on' || die '遠端登入尚未啟用。'
        ;;
    Linux)
        need sudo
        need systemctl
        if ! command -v sshd >/dev/null 2>&1 && [ ! -x /usr/sbin/sshd ]; then
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update
                sudo apt-get install -y openssh-server
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y openssh-server
            else
                die '請先用此發行版的套件管理器安裝 openssh-server。'
            fi
        fi
        if systemctl cat ssh.service >/dev/null 2>&1; then
            sudo systemctl enable --now ssh
            systemctl is-active --quiet ssh || die 'ssh 服務尚未啟動。'
        else
            sudo systemctl enable --now sshd
            systemctl is-active --quiet sshd || die 'sshd 服務尚未啟動。'
        fi
        ;;
    *) die '此腳本支援 macOS 與使用 systemd 的 Linux。';;
esac
printf '\nSSH 服務已啟用。請在外面的電腦執行：\n\n'
printf '  bash tailscale/ssh_client.sh %s %s home\n\n' "$TS_IP" "$(id -un)"
echo '首次連線時，可核對下列主機指紋：'
for key in /etc/ssh/ssh_host_*_key.pub; do
    [ ! -f "$key" ] || ssh-keygen -lf "$key"
done
echo '若登入遭拒，請檢查遠端登入的允許使用者、主機防火牆與 Tailnet 存取規則。'
