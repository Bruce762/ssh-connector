# Tailscale SSH 自動設定

適用於 Mac → Mac，以及 macOS / Linux 客戶端連到 macOS / Linux 主機。Linux 主機需使用 systemd；這組 Bash 腳本不支援原生 Windows。
使用一般 OpenSSH 經由 Tailscale 連線，不需要 Telegram、Cloudflare 或 `.env`。

## 第一次使用

兩台電腦先安裝 Tailscale、登入同一個 Tailnet 並保持連線。在專案根目錄執行以下指令。

**1. 家裡電腦（被連線的一方）**

```bash
bash tailscale/ssh_host.sh
```

腳本會自動開啟 macOS 遠端登入；Linux 會啟用 OpenSSH，缺少套件時透過 apt-get / dnf 安裝。
完成後會印出 Tailscale IP、登入帳號、主機指紋，以及要在另一台電腦執行的完整指令。
請以自己的帳號執行，腳本需要管理員權限時會自行呼叫 sudo。

**2. 外面的電腦（發起連線的一方）**

```bash
bash tailscale/ssh_client.sh
# 或直接貼上主機腳本提供的指令，例如：
bash tailscale/ssh_client.sh 100.101.102.103 alex home
```

腳本依序完成：

- 建立 `~/.ssh/id_ed25519_tailscale`，已存在則重用；所有主機共用這台客戶端的同一把金鑰。
- 從私鑰重新產生公鑰，自動加入遠端 `authorized_keys` 並設定權限；重跑不會重複加入相同公鑰行。
- 禁用密碼驗證來實際測試金鑰登入，成功後才寫入 `~/.ssh/config`。
- 備份原 config，更新此別名的 managed block，保留其他內容。

**3. 日常連線**

```bash
ssh home
```

VS Code Remote SSH 也可選擇 `home`。家裡電腦須保持開機與網路連線，腳本不需要持續執行。
不同主機請使用不同別名；這組設定會優先於既有同名 Host。不要同时執行多個設定程序。

## 首次仍需輸入的資訊

- Tailscale 登入與系統要求的授權。
- 主機啟用服務時的 sudo 密碼。若 macOS 拒絕 `systemsetup`，依錯誤提示授權終端機／IDE 的完整磁碟存取權，或在「一般 → 共享」啟用遠端登入。
- 客戶端建立金鑰時設定的 passphrase；驗證／安裝時可能需再次輸入。macOS 產生的設定包含 `UseKeychain yes`。
- 首次 SSH 連線的主機指紋確認，以及遠端帳號密碼。主機若已禁止密碼登入且尚未授權此金鑰，必須先透過主機本機或既有管理通道完成授權，無法無憑證安裝公鑰。

不必複製公鑰或手動編輯 SSH config。主機端不會自動停用密碼登入或更動使用者存取名單。
啟用原生 SSH 服務也可能允許區域網路等其他介面連線；此腳本不將服務限制在 Tailscale 介面，也不修改主機防火牆或 Tailnet 規則。
若連線逾時或拒絕登入，請確認 TCP 22、遠端登入允許使用者及 Tailscale 存取規則。

預設使用 port 22、IPv4 或 MagicDNS 主機名稱。若已有自訂 SSH 規則（例如 `Host *`、`Include` 或額外 IdentityFile），可用 `ssh -G home` 查看最終生效設定。
備份放在 `~/.ssh/config.backup.*`；需要還原時，將對應備份複製回 `~/.ssh/config`。

參考：[Tailscale CLI](https://tailscale.com/docs/reference/tailscale-cli)、[Apple systemsetup](https://support.apple.com/en-mt/guide/remote-desktop/apd95406b8d/mac)、[Mac 遠端登入](https://support.apple.com/en-mk/guide/mac-help/mchlp1066/mac)。
