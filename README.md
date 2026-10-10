# ssh-connector

提供 **Tailscale** 與 **Cloudflare + Telegram** 兩套獨立的 SSH 遠端連線方案。選一套設定即可，不需要兩套都執行。

| 比較 | Tailscale | Cloudflare + Telegram |
| --- | --- | --- |
| 連線方式 | 經由 Tailscale 私人網路，以 IP 或 MagicDNS 找到主機 | 主機建立 Tunnel，筆電從 Telegram 取得最新網址 |
| 事前準備 | 兩端安裝 Tailscale、登入同一個 Tailnet | 兩端安裝 cloudflared，設定 Telegram bot 與 `.env`，主機啟用 SSH |
| 首次金鑰設定 | 整合在 `ssh_client.sh` | 另外執行 `setup_key.sh` |
| 日常連線 | `ssh home` | 更新網址後執行 `ssh home-computer` |
| 持續運作需求 | 兩端 Tailscale 與主機 SSH 服務 | 主機 Tunnel 與 SSH 服務 |
| 詳細文件 | [Tailscale README](tailscale/README.md) | [Cloudflare README](cloudflare/README.md) |

**主機（Host）是被連線的電腦；筆電（Client）是發起連線的電腦。** 兩個資料夾有同名腳本，請使用所選方案的路徑。以下指令都從專案根目錄執行。

## Tailscale 執行流程

```text
兩端登入 Tailscale → 主機啟用 SSH → 筆電自動設定金鑰 → ssh home
```

**1. 兩端安裝並登入 Tailscale，保持連線。** 本方案支援 macOS / Linux；Linux 主機需使用 systemd。

**2. 在主機執行：**

```bash
bash tailscale/ssh_host.sh
```

腳本會啟用 SSH，並印出主機位址、登入帳號與指紋。

**3. 在筆電執行一次：**

```bash
bash tailscale/ssh_client.sh
```

依提示輸入主機位址、主機帳號與所需密碼。腳本會建立金鑰、安裝公鑰、驗證登入並寫入連線設定。

**4. 之後在筆電直接連線：**

```bash
ssh home
```

設定腳本不必持續執行。主機須保持開機、SSH 可用，兩端 Tailscale 須保持連線。密碼提示、IP 變更與多台主機設定見 [Tailscale README](tailscale/README.md)。

## Cloudflare + Telegram 執行流程

```text
安裝工具、設定 bot 與 .env → 主機啟用 SSH 並開 Tunnel
    → 筆電取得網址 → 首次安裝金鑰 → ssh home-computer
```

**1. 依 [Cloudflare README](cloudflare/README.md) 完成準備：**

- 兩端安裝 `cloudflared`，主機啟用 SSH。
- 建立 Telegram bot，取得 token 與 chat ID。
- 兩端在 `cloudflare/.env` 填入設定；新環境可複製 `cloudflare/.env.example` 建立，已有設定則保留。

**2. 在主機執行並保持此程序運作：**

```bash
bash cloudflare/ssh_host.sh
```

腳本啟動 Tunnel，將最新網址發送並釘選到 Telegram。

**3. 在筆電取得網址，首次安裝金鑰：**

```bash
bash cloudflare/ssh_client.sh
bash cloudflare/setup_key.sh
ssh home-computer
```

第一支腳本寫入連線設定；第二支建立金鑰並詢問是否安裝公鑰，輸入 `y` 後依提示登入主機。

**4. 之後每次在筆電更新網址再連線：**

```bash
bash cloudflare/ssh_client.sh && ssh home-computer
```

主機 Tunnel 必須持續運作，不必每次重建金鑰。雙擊啟動器位於 `cloudflare/mac/` 與 `cloudflare/windows/`。
Cloudflare README 中的 `./ssh_host.sh` 等指令，需先 `cd cloudflare` 再執行。

## 兩套方案共用的注意事項

- 金鑰由程式產生，passphrase 是自己選的私鑰保護密碼，與主機帳號密碼不同；輸入時不會顯示字元。
- 首次安裝公鑰需有可用的登入方式。先確認金鑰登入成功，再考慮停用主機的密碼驗證。
- 私鑰留在筆電，公鑰加入主機帳號的 `~/.ssh/authorized_keys`。兩套方案預設使用不同私鑰與別名，但都會寫入筆電的 `~/.ssh/config`。
- Tailscale 目前會核對並保存主機指紋；Cloudflare 客戶端目前停用這項檢查。各自的驗證原理、檔案位置與限制請閱讀對應 README。
