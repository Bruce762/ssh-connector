# Tailscale SSH 自動設定

用 Tailscale 連通兩台電腦，再以 OpenSSH 金鑰登入。支援 macOS 與 Linux（包含啟用 systemd 的 WSL 2）；Linux 主機需使用 systemd，這組 Bash 腳本不支援原生 Windows。無需 Telegram、Cloudflare 或 `.env`。

<a id="setup"></a>

## 重點流程：先設定一次，之後直接連線

兩台電腦先安裝 Tailscale、登入同一個 Tailnet 並保持連線。以下指令都在專案根目錄執行。

### 1. 在被連線的主機執行

```bash
bash tailscale/ssh_host.sh
```

腳本會啟用 SSH，印出主機位址、登入帳號與主機指紋。需要時輸入主機的管理員密碼；不要用 `sudo` 執行整支腳本。

### 2. 在發起連線的筆電執行

```bash
bash tailscale/ssh_client.sh
```

依序準備以下資訊：

| 提示 | 要填什麼 |
| --- | --- |
| 主機 IP 或 MagicDNS | 上一步提供的主機位址 |
| 登入帳號 | 主機執行 `whoami` 的結果 |
| 新金鑰的 passphrase | 自己設定的保護密碼，再輸入一次確認；不設定則兩次都按 Enter |
| 主機指紋確認 | 與主機顯示的指紋核對，一致才輸入 `yes` |
| `帳號@主機's password:` | 主機該帳號原本的登入密碼 |
| 既有金鑰的 passphrase | 該私鑰原本的保護密碼，可能詢問多次 |

密碼輸入時不會顯示字元。腳本會自動建立金鑰、安裝公鑰、驗證金鑰登入，成功後備份並更新連線設定。
主機若已禁止密碼登入，這把金鑰必須事先獲得授權，才能完成安裝流程。

### 3. 之後在筆電直接連線

```bash
ssh home
```

設定腳本不用持續執行或每次重跑。兩端 Tailscale 須保持運作，主機須開機且未進入無法接受連線的睡眠狀態。VS Code Remote SSH 也可選擇 `home`。

若終端機已在 `tailscale/` 目錄內，設定指令改用 `bash ssh_host.sh` 或 `bash ssh_client.sh`。

<a id="wsl-setup"></a>

## Tailscale 跑在 WSL 2 裡，Mac 直接連進 WSL

這個流程將 WSL 當成 Linux 主機，Mac 透過 WSL 自己的 Tailscale IP 連進 WSL 的 OpenSSH 服務。Mac 須先安裝 Tailscale 並保持連線。

### 1. 確認 WSL 2，並中斷 Windows 的 Tailscale

在 **Windows PowerShell** 執行：

```powershell
wsl -l -v
```

確認要使用的發行版 `VERSION` 是 `2`，再從 Windows 的 Tailscale 選單中斷連線。

[Tailscale 官方文件](https://tailscale.com/docs/install/windows/wsl2)建議只在 Windows 主機執行 Tailscale，因為 Windows 與 WSL 同時執行時，雙層 Tailscale 封包可能造成連線問題。若採用本節的 WSL 方案，請讓 Windows 端保持中斷，Mac 端則保持連線。

### 2. 在 WSL 確認 systemd

在 **WSL 終端機**執行：

```bash
ps -p 1 -o comm=
```

顯示 `systemd` 就繼續下一步。若不是，開啟設定檔：

```bash
sudo nano /etc/wsl.conf
```

加入以下設定；已有 `[boot]` 區段就修改該區段，保留其他設定：

```ini
[boot]
systemd=true
```

儲存後，先存好所有 WSL 工作，再到 **Windows PowerShell** 執行：

```powershell
wsl --shutdown
```

這會停止所有 WSL 發行版。重新開啟 WSL，再執行 `ps -p 1 -o comm=` 確認。
若無法啟用 systemd，在 PowerShell 用 `wsl --version` 確認 WSL 版本至少為 `0.67.6`，必要時執行 `wsl --update`。參考 [Microsoft systemd 說明](https://learn.microsoft.com/en-us/windows/wsl/systemd)。

### 3. 在 WSL 安裝並啟動 Tailscale

尚未安裝才需要執行：

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

接著啟動背景服務並連線：

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

開啟顯示的登入網址，登入與 Mac 相同的 Tailnet。

### 4. 確認連線，啟用 WSL 的 SSH

在 **WSL 終端機**執行：

```bash
tailscale status
tailscale ip -4

cd ~/ssh-connector/tailscale
bash ssh_host.sh
```

專案若放在其他位置，請調整 `cd` 路徑。用自己的 WSL 帳號執行，不要用 `sudo` 執行整支腳本；腳本會在需要時詢問 sudo 密碼，並印出 **WSL 的 Tailscale IP、登入帳號與主機指紋**。

### 5. 在 Mac 設定連線

在 **Mac 的專案根目錄**執行：

```bash
bash tailscale/ssh_client.sh
```

填入上一步的 **WSL Tailscale IP**，不要填 Windows 端的 IP。登入帳號填 WSL 的 `whoami` 結果；例如你的 WSL 帳號是 `bruce` 就填 `bruce`。核對主機指紋並依提示完成金鑰設定，之後在 Mac 執行：

```bash
ssh home
```

此方案使用 WSL 裡的 `ssh_host.sh`。Windows 要保持開機，WSL、`tailscaled` 與 SSH 服務也要保持運作；`enable --now` 會在 WSL 啟動時啟用服務，不會自動讓關閉的 WSL 啟動。

<a id="wsl-management"></a>

## WSL 的 Tailscale 日常管理

以下指令都在 **WSL 終端機**操作。

**開啟管理儀表板**，透過 Windows 預設瀏覽器：

```bash
explorer.exe "https://console.tailscale.com/admin/"
```

也可以直接點：[Tailscale 儀表板](https://console.tailscale.com/admin/)。

**中斷 WSL 的 Tailscale 連線：**

```bash
sudo tailscale down
```

**重新連線：**

```bash
sudo tailscale up
```

這些指令會保留登入資訊；`down` 只中斷連線，背景服務仍會運作，不等於登出。參考 [Tailscale CLI 說明](https://tailscale.com/docs/reference/tailscale-cli)。

**連背景服務一起停止：**

```bash
sudo systemctl stop tailscaled
```

**之後重新啟動並連線：**

```bash
sudo systemctl start tailscaled
sudo tailscale up
```

**如果 Mac 正透過 WSL 的 Tailscale 連線，中斷連線或停止背景服務後，SSH 也會中斷。** 請在 WSL 本機終端機執行重新連線指令。

<a id="authentication"></a>

## 主機關閉 SSH 密碼登入有什麼影響？

**這三項用來停用 SSH 密碼驗證、允許金鑰驗證。** `no` 表示停用，`yes` 表示啟用。

請設定在**被連線的主機** `/etc/ssh/sshd_config`，不是筆電的 `~/.ssh/config`，也不是 Tailscale 的設定：

```text
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
```

| 設定 | 效果 |
| --- | --- |
| `PasswordAuthentication no` | 禁止主機帳號密碼驗證 |
| `KbdInteractiveAuthentication no` | 禁止鍵盤互動驗證，例如經由 PAM 詢問密碼或驗證碼 |
| `PubkeyAuthentication yes` | 允許已授權的公鑰驗證 |

`PubkeyAuthentication yes` 不代表任何金鑰都能登入；筆電公鑰仍須在主機該帳號的授權清單中，並符合其他帳號存取規則。

| 情況 | 套用後的影響 |
| --- | --- |
| 筆電已安裝公鑰且驗證成功 | 可繼續用原本私鑰登入 |
| 新筆電尚未安裝公鑰 | 不能靠主機帳號密碼完成首次安裝，需在主機本機或透過既有管理通道加入公鑰 |
| 私鑰設定了 passphrase | 仍可能需要輸入它；這是在筆電解鎖私鑰，不是用主機帳號密碼登入 |
| 同一主機只是 IP 改變 | 原公鑰授權仍在且新位址可連通時，更新連線位址即可繼續使用金鑰 |

**先完成 `ssh_client.sh` 並確認金鑰登入成功，再停用主機密碼驗證。** 可在筆電使用以下指令，明確禁止退回密碼驗證：

```bash
ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no home
```

若私鑰有保護密碼，這個測試仍可能詢問 passphrase，屬正常現象。
修改主機設定後，依系統方式讓 SSH 服務重新載入設定；不要只把重複設定附加到檔案最後就假設生效。
保留原本的 SSH 連線，再另開終端機執行上述測試，確認成功後再關閉舊連線。
腳本本身不會修改主機這三項設定；它只在客戶端驗證及產生的連線設定中停用密碼驗證。

這些設定不會改變 Tailscale IP、不會取消已授權的公鑰，也不會取消私鑰的保護密碼。SSH 金鑰同樣可以用於 VS Code Remote SSH、SFTP 與 SCP；完整圖形桌面控制則需要另外設定其他服務。

## 詳細說明索引

- [Mac 直接連進 WSL 2 的設定流程](#wsl-setup)
- [WSL 的 Tailscale 日常管理](#wsl-management)
- [角色與連線參數](#roles)
- [金鑰與密碼說明](#prompts)
- [金鑰、設定與備份位置](#storage)
- [ASCII 架構圖與驗證流程](#flow)
- [多台筆電與多台主機](#multiple-devices)
- [IP 變更與 MagicDNS](#address-changes)
- [停用主機密碼登入](#authentication)
- [移除金鑰、授權與連線資訊](#cleanup)
- [腳本用途](#files)
- [限制與排錯](#troubleshooting)

以下的帳號、IP 與主機名稱均為示意值，請依實際環境替換；檔案路徑使用通用表示。

<a id="roles"></a>

## 角色與連線參數

本文以「你在外面用筆電，連回家裡電腦」為例：

| 名稱 | 代表哪台電腦 | 執行的腳本 |
| --- | --- | --- |
| Client／筆電 A | 你現在操作、發起連線的外面筆電 | `ssh_client.sh` |
| Host／主機 | 你要連進去的家裡電腦 | `ssh_host.sh` |
| 筆電 B | 未來可能使用的第二台外面筆電；沒有就忽略 | 在那台筆電執行 `ssh_client.sh` |

「自己」取決於你在哪台電腦執行指令。下文會標示操作位置；`~` 永遠代表該台電腦上目前使用者的家目錄。

```text
你現在操作的外面筆電（Client／筆電 A）
  保存：筆電 A 的私鑰與公鑰
  執行：ssh home
              |
              | SSH 連線，經由 Tailscale 網路
              v
家裡電腦（Host／主機）
  authorized_keys 保存：筆電 A 的公鑰
  用公鑰驗證這台筆電是否有登入權限
```

設定時會詢問主機位址、登入帳號與連線名稱，例如 `home-imac` 或 `home-windows`。之後使用 `ssh home-imac` 或 `ssh home-windows` 連線；本文件的 `ssh home` 範例適用於將連線名稱設為 `home` 的情況。

腳本啟動後、詢問主機位址前，會先列出目前 `~/.ssh/config` 中明確設定的 `Host` 別名（指定 `SSH_DIR` 時則讀取該目錄的 `config`）。清單會去除重複名稱，略過萬用字元與否定條件；不展開 `Include` 引用的檔案。同一台主機設定兩個名稱只會增加兩筆連線設定，仍重用這台筆電的 `id_ed25519_tailscale` 金鑰。

也可直接傳入參數，省略位址、帳號與連線名稱的互動詢問：

```bash
# 範例值請換成實際的主機位址與帳號
bash tailscale/ssh_client.sh home-mac remote_user home
```

| 參數 | 範例 | 意義 |
| --- | --- | --- |
| 第一個 | `home-mac` | 主機的 MagicDNS 名稱，也可填 Tailscale IPv4 |
| 第二個 | `remote_user` | 主機的登入帳號，不是 IP、Tailscale 登入信箱或顯示名稱 |
| 第三個 | `home` | 自訂連線捷徑；省略時會詢問，不可空白 |

帳號支援數字開頭，腳本會移除貼上時附帶的前後空白。不同主機請用不同別名；同名別名會更新為這次指定的主機。

### 使用其他 VPN 或區網

直接執行客戶端時，會先列出既有別名，再詢問使用「1) Tailscale」或「2) 其他 VPN／區網」。選擇 `2` 就會略過 Tailscale 檢查，不需要安裝或啟動 Tailscale；直接按 Enter 則使用 Tailscale。

也可加上 `--skip-tailscale`，直接使用其他 VPN／區網，省略網路選擇：

```bash
# 互動選擇網路，再設定位址、帳號與名稱
bash tailscale/ssh_client.sh

# 直接使用其他 VPN／區網
bash tailscale/ssh_client.sh --skip-tailscale

# 或直接指定主機 IPv4、帳號與別名（請換成實際資料）
bash tailscale/ssh_client.sh --skip-tailscale 192.168.1.10 remote_user home-imac
ssh home-imac
```

此選項只略過 Tailscale 檢查，不會建立 VPN 連線。請先連好 VPN，確認可存取主機的 SSH port 22，且主機已啟用 SSH。客戶端仍會核對主機指紋、安裝公鑰並驗證金鑰登入，成功後才更新設定；沿用既有金鑰與 managed block 格式。`ssh_host.sh` 仍使用 Tailscale 主機設定流程。

<a id="prompts"></a>

## 金鑰與密碼說明

| 項目 | 誰產生或設定 | 作用 |
| --- | --- | --- |
| SSH 私鑰與公鑰 | 腳本呼叫 `ssh-keygen` 自動產生 | 用於證明筆電有登入權限 |
| 金鑰保護密碼（passphrase） | 你在首次建立時自己設定 | 保護筆電上的私鑰，可選擇不設定 |
| 主機帳號密碼 | 家裡電腦該帳號原本的登入密碼 | 首次登入主機、安裝公鑰時使用 |

程式目前不會替你產生隨機保護密碼。設定時可以選自己記得住的長密碼；若不設定，在「設定密碼」和「再次確認」兩個提示各按一次 Enter 即可。
這不等於讓任何人都能登入：仍須有已授權的私鑰與主機連線權限，但私鑰外洩時會少一道保護。

重跑腳本會重用原本的私鑰，不會重新讓你選密碼。若提示要解鎖既有金鑰，就必須輸入它原本的保護密碼，直接 Enter 不會移除保護密碼。

`Enter passphrase (empty for no passphrase):` 是設定新密碼；`Enter passphrase for key ...:` 則是解鎖既有私鑰。程式產生金鑰，你選擇保護密碼，兩者不同。
保護密碼只用來在筆電上解鎖私鑰，不必與 Mac 登入密碼相同，也不會傳給主機。macOS 產生的設定含 `UseKeychain yes`，可透過鑰匙圈記住密碼，減少日後輸入。

主機首次啟用 SSH 時可能詢問 sudo 密碼。若 macOS 拒絕 `systemsetup`，依錯誤提示授權終端機／IDE 的完整磁碟存取權，或在「一般 → 共享」開啟遠端登入。

<a id="storage"></a>

## 金鑰與連線資訊存在哪裡？

以下是預設路徑。`~` 代表目前使用者的家目錄；macOS 的通用寫法為 `/Users/<使用者名稱>`。

| 電腦 | 路徑 | 用途 |
| --- | --- | --- |
| 外面筆電 | `~/.ssh/id_ed25519_tailscale` | 你的私鑰，留在筆電，不要分享 |
| 外面筆電 | `~/.ssh/id_ed25519_tailscale.pub` | 對應公鑰，腳本會安裝到主機 |
| 外面筆電 | `~/.ssh/config` | 別名、主機位址、登入帳號與私鑰路徑 |
| 外面筆電 | `~/.ssh/known_hosts` | 記住你確認過的主機身分 |
| 外面筆電 | `~/.ssh/config.backup.*` | 更新連線設定前的備份 |
| 家裡主機 | `~/.ssh/authorized_keys` | 該登入帳號允許使用的公鑰，可包含多台筆電 |
| 家裡主機 | `/etc/ssh/ssh_host_*_key` | 主機自己的身分私鑰，和筆電的登入私鑰不同 |

若指定 `SSH_DIR`，客戶端的金鑰、config、known_hosts 與備份會改放到該目錄；遠端公鑰仍安裝到該帳號的 `~/.ssh/authorized_keys`。
保護密碼若曾儲存到 macOS 鑰匙圈，也會有對應的鑰匙圈項目。

例如筆電的 `~/.ssh/config` 會包含下列資訊（節錄，實際內容由腳本產生）：

```sshconfig
Host home
    HostName 100.101.102.103
    User remote_user
    Port 22
    IdentityFile ~/.ssh/id_ed25519_tailscale
    IdentitiesOnly yes
```

`ssh home` 會讀取這些設定，不必每次輸入主機位址、帳號或私鑰路徑。金鑰檔案不在專案資料夾內；刪除本專案不會自動刪除上述 SSH 設定或撤銷主機授權。

<a id="flow"></a>

## SSH 金鑰架構與流程圖

圖中的「筆電 A」就是目前發起連線的筆電；「筆電 B」代表另一台筆電，只有一台時可忽略。以下使用預設檔案位置，帳號與主機名稱均為示意值。

```text
==========================================================================
                  Tailscale + OpenSSH 金鑰連線完整架構
              Tailscale 負責網路；OpenSSH 負責登入與驗證
==========================================================================

【兩端角色與檔案】

  外面筆電 A（Client，你正在操作）       家裡電腦（Host，被連線的主機）
  +--------------------------------+   +--------------------------------+
  | ~/.ssh/                        |   | ~/.ssh/                        |
  |                                |   |                                |
  | id_ed25519_tailscale            |   | authorized_keys                |
  |   私鑰：只留在筆電，用來簽名    |   |   筆電 A 的公鑰                |
  |                                |   |   筆電 B 的公鑰（若有）        |
  | id_ed25519_tailscale.pub        |   |                                |
  |   公鑰：提供給主機授權          |   | /etc/ssh/                      |
  |                                |   |   ssh_host_*_key               |
  | config                         |   |   主機身分私鑰：留在主機      |
  |   home -> 位址、帳號、私鑰路徑  |   |                                |
  |                                |   | SSH 服務：預設 TCP 22          |
  | known_hosts                    |   |   核對公鑰授權與帳號規則      |
  |   保存已確認的主機身分          |   |                                |
  +--------------------------------+   +--------------------------------+
                   |                                  |
                   +--------- Tailscale 網路 ----------+
                    兩端須連線，且存取規則允許 SSH


【階段 A：首次設定】

  家裡主機：bash tailscale/ssh_host.sh
      |
      +-> 檢查 Tailscale，啟用 SSH 服務
      +-> 印出主機 IP、登入帳號與主機指紋

  外面筆電：bash tailscale/ssh_client.sh
      |
      +-> 輸入主機 IP / MagicDNS、主機登入帳號
      |
      +-> 已有 id_ed25519_tailscale？
      |      沒有 -> ssh-keygen 產生金鑰對，自選保護密碼
      |      已有 -> 重用原本私鑰，不覆蓋、不重設密碼
      |
      +-> 從私鑰產生公鑰，補回或更新 .pub
      |
      +-> 透過 Tailscale 連到主機
      |      首次連線：核對主機指紋，一致才輸入 yes
      |      確認後將主機身分保存到 known_hosts
      |
      +-> 用主機帳號密碼登入一次
      |      若這把金鑰已獲授權，也能用它登入
      |      若沒有可用的登入方式，必須先在主機本機授權
      |
      +------ 將筆電公鑰送到主機 ------> ~/.ssh/authorized_keys
      |                                  加入公鑰、設定檔案權限
      |                                  同一公鑰行不重複加入
      |
      +-> 再建立一次連線，只允許 publickey 驗證
             |
             +-- 失敗 -> 停止，尚未更新筆電 config
             |
             +-- 成功 -> 備份原 config，寫入 home 連線設定
                         之後使用 ssh home

  此處停用的是「驗證連線的密碼登入方式」，不會修改主機 sshd 設定。


【階段 B：日常登入，執行 ssh home】

  筆電 A（保存私鑰）                    主機（保存授權公鑰）

  (1) 讀取 ~/.ssh/config
      Host home
        HostName home-mac
        User remote_user
        IdentityFile ~/.ssh/id_ed25519_tailscale
      |
      +--------- 經由 Tailscale 建立 SSH 連線 --------->|

  (2) 確認主機身分
      核對 known_hosts  <--------- 主機身分證明 --------|
      不符合預期 -> 停止並核對原因，不直接略過警告

  (3) 使用筆電的金鑰身分
      公鑰／金鑰驗證請求 ----------------------------->|
                                             檢查此帳號是否授權該公鑰

  (4) 必要時輸入 passphrase 解鎖私鑰
      或使用 agent 中已載入的金鑰
      用私鑰簽署「綁定本次 SSH 連線的驗證資料」
      |
      +-------------------- 簽章 --------------------->|
                                             用已授權的公鑰驗證簽章
                                                      |
                                                      +-- 失敗：拒絕登入
                                                      |
                                                      +-- 成功且符合
                                                          帳號規則：登入

  私鑰不會傳出去；綁定本次連線的簽章不能直接重用來登入下一條連線。
  此圖呈現驗證概念，實際金鑰詢問與簽章請求可能合併。


【IdentityFile 指向私鑰，為什麼可以把公鑰送出去？】

                   IdentityFile = 本機私鑰的路徑
                                |
                  +-------------+-------------+
                  |                           |
                  v                           v
              推導對應公鑰               在本機簽署驗證資料
                  |                           |
                  v                           v
              傳送公鑰                    傳送簽章結果
                  |                           |
                  +-------------+-------------+
                                v
                           主機驗證身分

  .pub 是方便安裝的公鑰副本；有私鑰就能重新產生公鑰。
  只有公鑰不能代替私鑰簽名登入，私鑰本身仍保留在筆電。


【passphrase：保護筆電上的私鑰】

  有保護密碼：私鑰檔案 + 正確的 passphrase -> 解鎖後才能簽名
  沒保護密碼：取得私鑰檔案即可使用，不需額外解鎖

  passphrase 由使用者自己設定，與主機帳號密碼不同，不會傳給主機。
  SSH agent 可保存已解鎖的金鑰；macOS 鑰匙圈可記住保護密碼。
  是否需要再次輸入，取決於金鑰是否已解鎖及 agent／鑰匙圈狀態。


【兩種驗證，方向不同】

  主機驗證：筆電確認「連到的是預期的主機嗎？」
      主機身分金鑰 -> 筆電 known_hosts 核對
      本方案：StrictHostKeyChecking ask，首次要求確認並保存紀錄

  使用者驗證：主機確認「對方持有被授權的私鑰嗎？」
      筆電私鑰簽名 -> 主機 authorized_keys 中的公鑰驗簽
      本方案：設定成功後產生的連線設定停用密碼驗證


【多台電腦與 IP 變動】

  筆電 A（獨立私鑰 A） -- 公鑰 A --> 主機 1 的 authorized_keys
                      -- 公鑰 A --> 主機 2 的 authorized_keys

  筆電 B（獨立私鑰 B） -- 公鑰 B --> 主機 1 的 authorized_keys

  一台筆電可授權多台主機；一台主機也可授權多台筆電。
  IP / MagicDNS 用來找到主機，金鑰用來證明登入權限。
  只換 IP -> 更新連線位址即可；前提是同一主機且原公鑰授權仍在。
  撤銷筆電 A -> 在各主機移除公鑰 A，不影響筆電 B。
==========================================================================
```

<a id="multiple-devices"></a>

## 多台筆電、多台主機

**同一台筆電連多台主機**：目前腳本重用這台筆電的同一把金鑰，使用不同別名區分主機。

```bash
# 都在同一台外面筆電執行；位址與帳號換成實際值
bash tailscale/ssh_client.sh 100.101.102.103 remote_user home
bash tailscale/ssh_client.sh 100.104.105.106 remote_user office

ssh home
ssh office
```

SSH 本身也支援每台主機使用不同金鑰，但目前腳本沒有獨立的金鑰路徑參數。

**同一台主機讓多台筆電登入**：每台筆電分別執行 `ssh_client.sh`，各自產生獨立金鑰。檔名即使相同，金鑰內容也不同，不需要在筆電之間複製私鑰。

```text
筆電 A（你現在的筆電） --公鑰 A--+
                               |
                               +--> 主機 remote_user 的 authorized_keys
                               |      公鑰 A
筆電 B（第二台筆電）   --公鑰 B--+      公鑰 B
```

若登入主機的不同帳號，公鑰分別安裝到各帳號的家目錄。刪除公鑰 A 的授權不影響公鑰 B。

<a id="address-changes"></a>

## Tailscale IP 改變怎麼辦？

Tailscale IP 通常保持穩定，不會因為換 Wi-Fi 或手機熱點就改變。IP / MagicDNS 用來找到主機，金鑰用來證明登入權限。

- 主機 IP 改了：如果 config 寫的是 IP，需要更新位址；原本的金鑰與公鑰授權仍有效。
- 筆電 IP 改了：目前腳本沒有將公鑰綁定筆電 IP，不需重裝金鑰；網路與存取規則仍須允許連線。
- 使用可正常解析的 MagicDNS 名稱：不必在 SSH 設定寫死 IP；名稱也改了才需更新。
- 主機重灌或換成另一台：公鑰授權與主機身分可能已改變，不能只假設更新 IP 就完成。

在外面筆電用同一個別名重跑，即可重用私鑰並更新設定：

```bash
# 範例：改用新 IP
bash tailscale/ssh_client.sh 100.110.120.130 remote_user home

# 或改用主機實際的 MagicDNS 名稱
bash tailscale/ssh_client.sh home-mac remote_user home
```

即使主機已禁用密碼登入，只要這把金鑰仍獲授權，新位址可連通，就可以執行更新。

<a id="cleanup"></a>

## 如何移除金鑰與連線資訊？

**刪除筆電上的連線別名不等於撤銷登入權限。要撤銷某台筆電的金鑰授權，必須從主機移除它的公鑰。**
以下以預設目錄及別名 `home` 為例；不要直接刪掉整個 `.ssh`，其中可能還有其他服務的設定。

### 1. 在主機撤銷這台筆電的公鑰

先在外面筆電查看公鑰（只查看 `.pub`，不要分享私鑰）：

```bash
cat ~/.ssh/id_ed25519_tailscale.pub
```

再到家裡主機，以原本 SSH 登入的帳號編輯：

```bash
nano ~/.ssh/authorized_keys
```

比對公鑰的類型與中間編碼內容，刪除對應的公鑰行，保留其他筆電的公鑰。若同一公鑰出現多次，移除所有對應授權行。
若這台筆電獲多台主機或多個帳號授權，要分別移除。最好在主機本機操作，以免移除後無法重新登入。

### 2. 在筆電移除連線別名

```bash
nano ~/.ssh/config
```

移除下列兩個標記之間的整段內容，包含標記本身，保留其他設定：

```text
# >>> tailscale managed (home) >>>
（此別名的設定）
# <<< tailscale managed (home) <<<
```

`~/.ssh/config.backup.*` 可能留有舊主機資訊，確認不需要還原後，可刪除對應備份。

### 3. 在筆電移除記住的主機指紋

使用該主機實際的 IP 或 MagicDNS 名稱，不是單純填 SSH 別名 `home`：

```bash
ssh-keygen -R 100.101.102.103
ssh-keygen -R home-mac
```

只需處理你曾使用過的位址或名稱。此步驟移除主機信任紀錄，下次連線會重新確認指紋，不會撤銷筆電的登入權限。
工具可能產生 `~/.ssh/known_hosts.old`，不需要保留舊紀錄時可刪除該備份。

### 4. 確定不再使用這把金鑰，才刪除筆電上的金鑰

目前多台主機共用這台筆電的金鑰。若只取消一台主機的連線，保留私鑰供其他主機使用。
若全部都不再使用，先從 SSH agent 移除（未啟用 agent 或未載入時可能顯示錯誤），再刪除檔案：

```bash
ssh-add -d ~/.ssh/id_ed25519_tailscale
rm -i ~/.ssh/id_ed25519_tailscale ~/.ssh/id_ed25519_tailscale.pub
```

`rm -i` 會逐檔確認，輸入 `y` 才刪除。若曾在 macOS 儲存保護密碼，在「鑰匙圈存取」搜尋該金鑰路徑，刪除對應項目。
刪除公鑰授權不會自動終止已建立的 SSH 連線；上述清理也不會關閉主機 SSH 服務或移除 Tailscale 裝置。

<a id="files"></a>

## 腳本用途與自動處理範圍

| 檔案 | 在哪裡使用 | 用途 |
| --- | --- | --- |
| `ssh_host.sh` | 被連線的主機 | 啟用 macOS 遠端登入，或安裝並啟用 Linux OpenSSH 服務 |
| `ssh_client.sh` | 發起連線的筆電 | 建立／重用私鑰、安裝公鑰、驗證登入、更新連線別名 |
| `common.sh` | 由以上腳本自動載入 | 檢查 Tailscale、取得本機 IP、準備 SSH 目錄與處理錯誤；必須保留，不需直接執行 |
| `README.md` | 閱讀 | 本使用說明 |

不需要額外的金鑰設定腳本或 SSH config 範例檔，這些步驟已整合在 `ssh_client.sh`。`cloudflare/setup_key.sh` 屬於其他方案，使用本指南時不需執行。

客戶端腳本會：

- 建立 Ed25519 金鑰，已存在就重用；同一台筆電預設共用一把金鑰連線到不同主機。
- 從私鑰產生公鑰，補回缺少或不一致的 `.pub`，並加入遠端 `authorized_keys`；相同公鑰行不會重複加入。
- 設定 SSH 目錄與檔案權限，停用本次連線的密碼驗證來測試金鑰登入。
- 驗證成功才備份並更新 config 的對應 managed block，保留其他內容。產生的同名 Host 設定會優先於既有設定。

不要同時執行多個設定程序。Linux 主機使用 apt-get / dnf 安裝缺少的 OpenSSH 套件，服務管理需要 systemd。

<a id="troubleshooting"></a>

## 其他限制與排錯

不必複製公鑰或手動編輯 SSH config。主機端不會自動停用密碼登入或更動使用者存取名單。
啟用原生 SSH 服務也可能允許區域網路等其他介面連線；此腳本不將服務限制在 Tailscale 介面，也不修改主機防火牆或 Tailnet 規則。
若連線逾時或拒絕登入，請確認 TCP 22、遠端登入允許使用者及 Tailscale 存取規則。

預設使用 port 22、IPv4 或 MagicDNS 主機名稱。若已有自訂 SSH 規則（例如 `Host *`、`Include` 或額外 IdentityFile），可用 `ssh -G home` 查看最終生效設定。
備份放在 `~/.ssh/config.backup.*`；需要還原時，將對應備份複製回 `~/.ssh/config`。

| 現象 | 檢查方式 |
| --- | --- |
| 登入帳號格式不支援 | 位址和帳號分開填；帳號使用主機 `whoami` 的輸出 |
| 找不到 Tailscale 或尚未連線 | 先安裝並開啟 Tailscale，登入可互通的 Tailnet |
| `Could not resolve hostname` | 檢查 MagicDNS 名稱與 DNS 是否可用；也可改用主機目前的 Tailscale IPv4 |
| 連線逾時／`Connection refused` | 確認主機開機且可接受連線、SSH 服務啟動、TCP 22 與存取規則允許連線 |
| `Permission denied (publickey)` | 確認帳號、私鑰與主機的公鑰授權；尚未授權且主機禁止密碼登入時，需先用其他管理通道安裝公鑰 |
| 主機身分變更警告 | 先在主機核對指紋，確認是否重灌或換機；不要未確認就刪除信任紀錄 |
| 重跑一直詢問 passphrase | 安裝、衍生公鑰、驗證是不同步驟，可能各自要求解鎖；重跑不會重設密碼 |

在筆電查看最終連線設定或診斷連線：

```bash
ssh -G home    # 顯示設定，不建立 SSH 連線
ssh -v home    # 嘗試連線，顯示診斷資訊
```

一般設定完成後只需 `ssh home`，不必每次重跑設定腳本。主機與筆電的 Tailscale 仍須保持運作；主機不可進入無法接受連線的睡眠狀態。

參考：[Tailscale CLI](https://tailscale.com/docs/reference/tailscale-cli)、[Tailscale IP 位址](https://tailscale.com/docs/concepts/ip-and-dns-addresses)、[MagicDNS](https://tailscale.com/docs/features/magicdns)、[OpenSSH 伺服器設定](https://man.openbsd.org/sshd_config)、[Apple systemsetup](https://support.apple.com/en-mt/guide/remote-desktop/apd95406b8d/mac)、[Mac 遠端登入](https://support.apple.com/en-mk/guide/mac-help/mchlp1066/mac)。
