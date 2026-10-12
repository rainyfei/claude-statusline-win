# claude-statusline-win

給 Windows 用的 [Claude Code](https://claude.com/claude-code) 狀態列，用純 PowerShell 5.1 寫成，不需要 bash、jq 或安裝其他東西。專為訂閱方案設計：一眼看出 5 小時與 7 天額度用了多少、什麼時候重置，以及是不是用得太快。

[English](README.md)

![screenshot](docs/screenshot.png)

## 功能

- **漸層量表**：上下文視窗、5h、7d 三條量表；百分比未滿 70% 綠色、70～89% 黃色、90% 以上紅色
- **重置倒數**：`5h ... (2h13m)`、`7d ... (3d5h)`
- **用量速度警示**：用量比時段經過的時間超前 10% 以上，倒數變黃色；超前 30% 以上變紅色，提醒你照這個速度可能撐不到重置
- **自動換行**：視窗太窄時，會以區塊為單位換到下一行，不會被截成 `…`
- **Fast mode 標示**：開啟 `/fast` 時顯示 `⚡fast`，因為它消耗額度比較快
- **自動強度標示**（`⟳ Auto`）：選用功能，只有在其他工具寫入 `%USERPROFILE%\.claude\rainy-console\live\<session_id>.json` 且內容為 `"auto": true` 時才會出現；沒有這個檔案就完全不影響
- **自動模型標示**（`⇄`）：選用功能，同一個檔案內容為 `"autoModel": true` 時，模型名稱改顯示這一輪選用的模型（`"model"`），後面緊接同色的 `⇄`
- 模型、effort 等級、對話經過時間、目前資料夾、git 分支與未提交標記（`*`）
- Windows Terminal 下使用全彩，另外支援 16 色、ASCII、Nerd Font、Powerline 模式

```
◆ Opus 5.5 high │ █░░░░░░░░░ 12% / 1M │ 1.5h │ 5h ███░░░░░░░ 30% (4h15m) │ 7d ███░░░░░░░ 30% (1d1h) │ 📁 my-project │ ⎇ main*
```

## 需求

- Windows 10／11（內建 Windows PowerShell 5.1）
- Claude Code
- 建議使用 Windows Terminal 才能顯示全彩
- 只有 Claude 訂閱方案會回報額度；使用 API 計費時，5h／7d 區塊會自動隱藏

## 安裝

```powershell
git clone https://github.com/rainyfei/claude-statusline-win.git
cd claude-statusline-win
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

安裝程式會把 `statusline.ps1` 複製到 `%USERPROFILE%\.claude\`，並設定 `%USERPROFILE%\.claude\settings.json` 的 `statusLine`。被取代的檔案會先備份成 `*.bak-<時間>`。送出下一則訊息後狀態列就會出現。

### 手動安裝

把 `statusline.ps1` 複製到 `%USERPROFILE%\.claude\`，再把下面這段加進 `%USERPROFILE%\.claude\settings.json`（`<you>` 換成你的 Windows 使用者名稱）：

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/<you>/.claude/statusline.ps1\"",
    "refreshInterval": 2
  }
}
```

`refreshInterval` 讓狀態列每 2 秒重跑一次，Auto 標示和時間不用等你下一則訊息就會更新；不加的話只在有新訊息時更新。

## 選項

設定成 Windows 環境變數後，重新啟動 Claude Code。

| 變數 | 效果 |
|---|---|
| `CLAUDE_STATUSLINE_ASCII=1` | 純 ASCII，給不支援方塊字元的字型 |
| `CLAUDE_STATUSLINE_NERDFONT=1` | Nerd Font 圖示（終端機要使用 Nerd Font 字型） |
| `CLAUDE_STATUSLINE_POWERLINE=1` | Powerline 分隔符（開啟 Nerd Font 時預設開啟） |
| `COLORTERM=truecolor` | 在 Windows Terminal 以外強制使用 24 位元全彩 |

## 運作方式

Claude Code 每次更新時，會把對話資料以 JSON 傳給腳本。腳本讀取上下文與額度百分比，用 `resets_at` 算出重置倒數，從 `COLUMNS` 讀取終端機寬度決定在哪裡換行，並檢查 git 狀態（在 `%TEMP%` 快取 5 秒）。如果有上面提到的自動強度檔案，也會讀取它。它不會連網，除了 git 快取以外也不會寫入任何檔案。

## 解除安裝

刪除 `%USERPROFILE%\.claude\settings.json` 裡的 `statusLine` 設定，再刪除 `%USERPROFILE%\.claude\statusline.ps1`。

## 授權

[MIT](LICENSE)
