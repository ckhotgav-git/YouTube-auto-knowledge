---
name: youtube-workflow
description: YT 頻道懶人包 — 自動發現 YT 新影片、送入 NotebookLM、生成繁體中文報告/簡報/錄音/資訊圖表
---

# YT 頻道工作流 — 懶人包

這是一份**寫給 AI Agent 看的操作說明**。當使用者說出觸發詞，請按照以下步驟執行。

---

## 0. 第一步：詢問 AI Agent 類型

先問使用者：「你正在用哪一個 AI Agent？」

| Agent | 辨識方式 | 注意事項 |
|-------|---------|---------|
| **OpenCode** | 使用 opencode CLI | 有 MCP 工具可用（notebooklm_*），優先使用 |
| **Claude Code** | 使用 claude CLI | 僅能執行 shell 指令，走 `nlm` CLI |
| **AntiGravity** | 自訂框架 | 依實際環境判斷 |
| **Cursor** | IDE 內建 AI | 可執行 terminal 指令 |
| **Windsurf** | IDE 內建 AI | 可執行 terminal 指令 |
| **其他** | 請使用者描述 | 依功能判斷使用 MCP 或 CLI |

---

## 1. 環境檢查與安裝

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\setup-agent.ps1" -AgentType "<識別到的 Agent 類型>"
```

如果任一項檢查失敗，**先引導使用者安裝完成後再繼續**。不要跳過。

---

## 2. 讀取設定

從 `workflow\workflow-config.json` 讀取設定（若不存在，請使用者從 `workflow-config.example.json` 複製並填入）。

讀取內容：頻道列表、Notebook ID、每頻道上限、報告格式、成品類型。

---

## 3. 發現新影片

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\discover-videos.ps1" -ConfigPath "workflow\workflow-config.json" -MaxVideos 20
```

腳本行為：RSS（含重試）→ UULF 備援 → 每頻道上限 → 排除已處理。

**顯示結果給使用者**，詢問：
- 要全部處理還是只選特定影片？
- 要用新筆記本還是現有的？

---

## 4. 確認來源不重複

若選現有筆記本，先取得來源列表，比對網址只加不存在的。

---

## 5. 將選定影片加入 NotebookLM

每部間隔 3 秒。MCP 或用 CLI：`nlm add url <NOTEBOOK_ID> <YT_URL>`

---

## 6. 生成文字報告

MCP：`notebooklm_studio_create(..., artifact_type="report", report_format="Briefing Doc", language="zh-TW", confirm=true)`

CLI：`nlm report create <NOTEBOOK_ID> --format "Briefing Doc" --language zh-TW --confirm`

---

## 7. 將報告加入為來源

下載報告 → 以檔案或文字加回同一筆記本 → 記錄新 Source ID。

---

## 8. 從報告來源生成成品

詢問要哪些成品。**一律 `--language zh-TW` + `--source-ids` 只從報告來源生成。**

CLI：
```
nlm slides create <ID> --source-ids <報告ID> --language zh-TW --confirm
nlm video create <ID> --source-ids <報告ID> --language zh-TW --confirm
nlm audio create <ID> --source-ids <報告ID> --language zh-TW --confirm
nlm infographic create <ID> --source-ids <報告ID> --language zh-TW --confirm
```

---

## 9. 更新已處理狀態

寫入 `workflow\processed-state.json`。

---

## 10. 報告完成

向使用者回報處理摘要、成品清單、NBLM 連結。

---

## 排程執行模式

當使用者說「排程檢查」或「執行 YT 工作流排程」：

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\schedule-run.ps1"
```

此模式**不互動、使用設定檔預設值**，結束後回報摘要。

> ⚠️ 排程**預設為關閉**。需使用者手動在 `workflow\workflow-config.json` 將 `schedule_enabled` 設為 `true`，並依 `docs\SCHEDULE_SETUP.md` 設定 Windows 工作排程器。

---

## 安全規則（不可違反）

- ❌ 不得將 API Key、Token、密碼寫入任何檔案
- ❌ 不得將 `.env`、`*.key`、`*.pem` 等加入 Git
- ✅ 使用 `workflow-config.example.json` 作為範本
- ✅ 提交前執行 `scripts\check-secrets.ps1`
- 詳見 `SECURITY.md`

---

## 參考資源

- `workflow\workflow-config.example.json`：設定檔範本
- `workflow\AGENT_GUIDE.md`：AI Agent 工具對照
- `scripts\discover-videos.ps1`：YT 發現腳本
- `scripts\schedule-run.ps1`：排程執行腳本
- `scripts\setup-agent.ps1`：環境檢查腳本
- `scripts\check-secrets.ps1`：機密掃描腳本
- `scripts\install-hooks.ps1`：安裝 pre-commit hook
- `docs\SCHEDULE_SETUP.md`：Windows 排程器設定
- `docs\USAGE.md`：使用說明
- `docs\DEVELOPMENT_LOG.md`：開發日誌
- `SECURITY.md`：安全性政策

---

## 開發者

- **點哥** (FB: [jshpapa](https://facebook.com/jshpapa)) — 原始構想與需求
- **[未來腦力研究社](https://think-clue.blogspot.com/)** — 開發與維護
