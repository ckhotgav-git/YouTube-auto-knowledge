# 開發日誌 — YouTube Auto Knowledge

> 作者：**點哥** (FB: [jshpapa](https://facebook.com/jshpapa)) & **[未來腦力研究社](https://think-clue.blogspot.com/)**
> 專案開始：2026-06-09

---

## v1.0.0 — 2026-06-09

### 緣起

本專案起源於一個需求：能不能讓 AI 自動掃描指定的 YouTube 頻道，將新影片送進 NotebookLM 分析，然後自動產出簡報、錄音、影片等學習材料？

### 開發歷程

#### Phase 1：基礎架構
- 決定使用 OpenCode Skill 模式，讓 AI Agent 能直接讀取操作說明
- 建立三層結構：SKILL.md（AI 指引）→ scripts（自動化腳本）→ config（設定檔）
- 選擇 YouTube RSS Feed 為主要發現方式（零 API Key 需求）

#### Phase 2：影片發現機制
- 實作 RSS 解析（支援 XML namespace 正確處理）
- 加入 3 次重試機制應對 RSS 間歇不穩
- 實作 UULF playlist_id 備援方案
- 每頻道獨立計數，支援 per-channel limit

#### Phase 3：NotebookLM 整合
- 發現 NotebookLM MCP 工具與 CLI 兩種操作方式
- 建立正確流程順序：YT → NBLM 來源 → 文字報告 → 報告加回為來源 → 成品
- 解決 auth token 過期問題（`nlm login` + refresh）
- 加入 `--language zh-TW` 確保繁體中文輸出

#### Phase 4：懶人包化
- 加入環境檢查腳本（`setup-agent.ps1`），自動檢測 8 項必要條件
- 支援 5 種 AI Agent（OpenCode、Claude Code、AntiGravity、Cursor、Windsurf）
- 加入機密掃描機制（`check-secrets.ps1` + pre-commit hook）
- 撰寫 AI Agent 專用工具對照表（`AGENT_GUIDE.md`）

#### Phase 5：實戰測試
- 成功掃描 3 個頻道 × 3 部影片 = 9 部
- 成功生成 Briefing Doc（繁體中文）
- 成功生成 Slide Deck、Video Overview、Audio Podcast、Infographic
- 所有成品皆以繁體中文輸出

### 技術決策記錄

| 決策 | 選擇 | 理由 |
|------|------|------|
| 影片發現 | RSS Feed | 不需要 API Key |
| 備援方案 | UULF playlist_id | RSS 2025/12 起不穩 |
| 操作方式 | MCP 優先，CLI 降級 | 兼顧效率與相容性 |
| 語言 | zh-TW BCP-47 | 繁體中文為目標語言 |
| 成品來源 | 基於報告而非原始 YT | 報告濃縮後品質較高 |
| 每頻道上限 | 3 筆 | 避免 NotebookLM 來源過多 |
| 排程 | Windows Task Scheduler | 使用者環境為 Windows |

### 已知限制

- YouTube RSS 偶發性 404（有 retry 但無法完全避免）
- Video Overview 生成時間較長（可能需 5-10 分鐘）
- MCP auth token 需定期更新（`nlm login`）
- 目前僅支援 Windows（PowerShell 腳本相依）

### 未來規劃

- [ ] 支援更多 AI Agent（GitHub Copilot、Continue 等）
- [ ] 加入 YT API Key 選項（RSS 失效時備援）
- [ ] 跨平台支援（Linux/macOS）
- [ ] 支援更多報告格式
- [ ] 自動摘要推送到 Discord / Telegram

---

> 感謝所有使用者的回饋，讓這個工具越來越完善。
