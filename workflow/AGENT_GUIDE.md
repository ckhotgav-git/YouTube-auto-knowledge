# YT 懶人包 — AI Agent 工具對照表

本文件說明各 AI Agent 在執行 YT 工作流時，如何找到並使用對應的工具、套件與指令。

---

## 1. 不同 Agent 的執行策略

| Agent 類型 | 推薦操作方式 | 理由 |
|-----------|------------|------|
| **OpenCode** | MCP 工具優先 → 失敗降級 CLI | OpenCode 內建 `notebooklm_*` MCP 工具組 |
| **Claude Code** | 全部走 `nlm` CLI | Claude Code 無 MCP 工具，純 shell 執行 |
| **Cursor** | 全部走 `nlm` CLI | Cursor 可執行 terminal 指令 |
| **Windsurf** | 全部走 `nlm` CLI | Windsurf 可執行 terminal 指令 |
| **AntiGravity (自訂)** | 依實作判斷 | 若有 MCP Client 支援則用 MCP，否則 CLI |
| **GitHub Copilot** | 全部走 `nlm` CLI | 僅能執行 shell 指令 |
| **其他** | 預設 CLI | 若支援 MCP 則可嘗試 MCP |

---

## 2. MCP 工具對照（OpenCode / 支援 MCP 的 Agent）

當 Agent 有 MCP 能力時，使用下列工具對應：

| 工作 | MCP 工具 | 備註 |
|------|---------|------|
| 建立筆記本 | `notebooklm_notebook_create(title)` | |
| 取得筆記本資訊 | `notebooklm_notebook_get(notebook_id)` | 含來源列表 |
| 列出筆記本 | `notebooklm_notebook_list()` | 讓使用者選 |
| 加入 URL 來源 | `notebooklm_source_add(notebook_id, source_type="url", urls=[...], wait=true)` | 可批次加入 |
| 加入文字來源 | `notebooklm_source_add(notebook_id, source_type="text", text="...", title="...")` | 加入報告用 |
| 加入檔案來源 | `notebooklm_source_add(notebook_id, source_type="file", file_path="...", title="...", wait=true)` | 加入報告檔 |
| 生成成品 | `notebooklm_studio_create(notebook_id, artifact_type, source_ids=[...], language="zh-TW", confirm=true)` | |
| 下載成品 | `notebooklm_download_artifact(notebook_id, artifact_type, artifact_id, output_path)` | |
| 刪除成品 | `notebooklm_studio_delete(notebook_id, artifact_id, confirm=true)` | |
| 檢查狀態 | `notebooklm_studio_status(notebook_id)` | 列出所有成品 |
| 重新整理授權 | `notebooklm_refresh_auth()` | Token 更新後呼叫 |

**重要**：`notebooklm_source_add` 的 `source_type="file"` 支援 PDF、TXT、MD、DOCX、CSV、EPUB、MP3、M4A、WAV、MP4、JPG、PNG 等。

---

## 3. CLI 工具對照（所有 Agent 通用）

當 MCP 不可用時，全部走 `nlm` CLI：

| 工作 | CLI 指令 | 備註 |
|------|---------|------|
| 建立筆記本 | `nlm create notebook "標題"` | |
| 取得筆記本 | `nlm get notebook <NOTEBOOK_ID>` | 輸出 JSON |
| 列出筆記本 | `nlm list notebooks` | |
| 加入 URL | `nlm add url <NOTEBOOK_ID> <URL>` | 輸出含 Source ID |
| 加入文字 | `nlm add text <NOTEBOOK_ID> "標題" "內容"` | |
| 加入檔案 | `nlm add file <NOTEBOOK_ID> <路徑> --title "標題"` | 新版語法 |
| 生成報告 | `nlm report create <NOTEBOOK_ID> --format "Briefing Doc" --language zh-TW --confirm` | |
| 生成簡報 | `nlm slides create <NOTEBOOK_ID> --source-ids <ID> --language zh-TW --confirm` | |
| 生成影片 | `nlm video create <NOTEBOOK_ID> --source-ids <ID> --language zh-TW --confirm` | |
| 生成錄音 | `nlm audio create <NOTEBOOK_ID> --source-ids <ID> --language zh-TW --confirm` | |
| 生成資訊圖表 | `nlm infographic create <NOTEBOOK_ID> --source-ids <ID> --language zh-TW --confirm` | |
| 下載成品 | `nlm download report/slides/video/audio/infographic <NOTEBOOK_ID> <ARTIFACT_ID>` | |
| 狀態查詢 | `nlm studio status <NOTEBOOK_ID>` | 輸出 JSON |
| 刪除成品 | `nlm studio delete <NOTEBOOK_ID> <ARTIFACT_ID> --confirm` | |
| 刪除來源 | `nlm delete source <SOURCE_ID> --confirm` | 只需 source ID |
| 登入 | `nlm login` | 自動開瀏覽器 |
| 登入檢查 | `nlm login --check` | 檢查 Token 有效 |

### CLI 輸出解析技巧

`nlm add url` 輸出範例：
```
Added source: 影片標題
  Source ID: abc12345-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Source ID 擷取方法（PowerShell）：
```powershell
$lines = & nlm add url <ID> <URL> 2>&1
$sourceId = ""
foreach ($l in $lines) {
  if ($l -match 'Source ID:\s*(\S+)') { $sourceId = $Matches[1]; break }
}
```

`nlm studio status` 輸出為 JSON，解析方法：
```powershell
$status = nlm studio status <NOTEBOOK_ID> | ConvertFrom-Json
$status | Where-Object { $_.type -eq "video" -and $_.status -eq "completed" }
```

---

## 4. 套件安裝指令

| 套件 | 安裝指令 | 備註 |
|------|---------|------|
| **uv** | `winget install uv` 或 `pip install uv` | Python 套件管理器 |
| **nlm CLI** | `uv tool install notebooklm-mcp-cli` 或 `pip install notebooklm-mcp-cli` | NotebookLM CLI |
| **nlm 更新** | `uv tool upgrade notebooklm-mcp-cli` 或 `pip install --upgrade notebooklm-mcp-cli` | |

`$env:USERPROFILE\.config\opencode\skills\youtube-workflow` 為技能目錄，內含：
- `SKILL.md` — AI Agent 操作說明（懶人包入口）
- `workflow-config.json` — 頻道與預設值設定
- `scripts/` — 自動化腳本
- `processed-state.json` — 已處理記錄
- `SCHEDULE_SETUP.md` — 排程器設定
- `AGENT_GUIDE.md` — 本文件

---

## 5. 常見問題

### Q: MCP 工具回報 auth expired 怎麼辦？
```powershell
nlm login
```
完成後若 MCP 仍報錯，執行 `notebooklm_refresh_auth()` 或重啟 Agent。

### Q: RSS 抓不到影片怎麼辦？
腳本已內建 3 次重試 + UULF playlist_id 備援。若仍為 0 筆：
- 改用「手動指定搜尋模式」，用 websearch 找影片網址
- 或在 YT 頻道頁手動複製網址餵給腳本

### Q: 成品語言跑出英文怎麼辦？
確認每個生成指令都有 `--language zh-TW`。若遺漏，刪除後重建。

### Q: `nlm add file` 路徑含空格？
用雙引號包起來：`nlm add file <NOTEBOOK_ID> "C:\path with spaces\file.md"`

### Q: 如何在排程模式指定語言？
`schedule-run.ps1` 已內建 `--language zh-TW`，無需額外設定。

---

> 最後更新：2026-06-09
