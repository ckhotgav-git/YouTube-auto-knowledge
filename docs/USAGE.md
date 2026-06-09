# YouTube Auto Knowledge 使用說明

## 什麼是 YouTube Auto Knowledge？

一個**給 AI Agent 讀的工作流懶人包**，能夠：

1. 自動掃描指定的 YouTube 頻道新影片
2. 將影片送進 Google NotebookLM
3. 自動生成繁體中文的 Briefing Doc 報告
4. 把報告加入為新來源
5. 從報告產出簡報 (Slide Deck)、影片 (Video)、錄音 (Audio)、資訊圖表 (Infographic)

## 需求環境

| 項目 | 需求 |
|------|------|
| 作業系統 | Windows 10/11 |
| PowerShell | 5.1 或以上 |
| uv 或 Python | uv 套件管理器（或 Python 3.8+） |
| nlm CLI | `uv tool install notebooklm-mcp-cli` |
| NotebookLM 帳號 | 需有 Google 帳號並可存取 NotebookLM |

## 快速開始

### 1. 安裝必要工具

```powershell
# 安裝 uv（Python 套件管理器）
winget install uv
# 或 pip install uv

# 安裝 NotebookLM CLI
uv tool install notebooklm-mcp-cli

# 登入 NotebookLM
nlm login
```

### 2. 設定頻道

複製 `workflow\workflow-config.example.json` 為 `workflow\workflow-config.json`，填入：

```json
{
  "notebook_id": "",
  "processed_state_path": "workflow/processed-state.json",
  "defaults": {
    "max_per_channel": 3,
    "report_format": "briefing_doc",
    "language": "zh-TW",
    "artifacts": ["slide_deck", "video", "audio", "infographic"]
  },
  "channels": [
    {
      "name": "我的頻道",
      "channel_id": "UC...",
      "rss_url": "https://www.youtube.com/feeds/videos.xml?channel_id=UC...",
      "playlist_id": "UULFUC..."
    }
  ]
}
```

**如何取得 Channel ID：**
1. 開啟 YouTube 頻道頁面
2. 網址最後一段 `/channel/UC...` 或 `@handle`
3. 若為 `@handle`，RSS URL 改為 `https://www.youtube.com/feeds/videos.xml?user=handle`

### 3. 給 AI Agent 執行

將此專案路徑告知你的 AI Agent，然後說：

> 「執行 YT 懶人包」

AI Agent 會自動閱讀 `workflow\SKILL.md`，依序完成所有步驟。

### 4. 手動執行

```powershell
# 環境檢查
powershell -ExecutionPolicy Bypass -File scripts\setup-agent.ps1

# 發現新影片
powershell -ExecutionPolicy Bypass -File scripts\discover-videos.ps1 -ConfigPath workflow\workflow-config.json -MaxVideos 20

# 排程執行（無互動）
powershell -ExecutionPolicy Bypass -File scripts\schedule-run.ps1
```

### 5. 設定 Windows 排程

詳見 `docs\SCHEDULE_SETUP.md`。

## 安全注意事項

**詳見 `SECURITY.md`。**

重點提醒：
- ❌ 不要把 `workflow-config.json`（含真實資料）提交到 Git
- ❌ 不要把筆記本 ID、Token、密碼放到任何檔案中
- ✅ 提交前執行 `scripts\check-secrets.ps1`
- ✅ 安裝 pre-commit hook：`scripts\install-hooks.ps1`

## AI Agent 對照

| 你的 AI Agent | 操作方式 | 說明文件 |
|--------------|---------|---------|
| OpenCode | MCP 工具 + CLI | `workflow\SKILL.md` |
| Claude Code | 僅 CLI | `workflow\AGENT_GUIDE.md` |
| Cursor | 僅 CLI | `workflow\AGENT_GUIDE.md` |
| Windsurf | 僅 CLI | `workflow\AGENT_GUIDE.md` |
| AntiGravity | 依實作 | `workflow\AGENT_GUIDE.md` |

## 目錄結構

```
YouTube-auto-knowledge/
├── README.md                  # 本文件
├── LICENSE                    # MIT 授權
├── SECURITY.md                # 安全性政策
├── .gitignore                 # Git 排除規則
├── workflow/
│   ├── SKILL.md               # AI Agent 操作說明（懶人包入口）
│   ├── AGENT_GUIDE.md         # AI Agent 工具對照表
│   └── workflow-config.example.json  # 設定檔範本
├── scripts/
│   ├── setup-agent.ps1        # 環境檢查腳本
│   ├── discover-videos.ps1    # YT 影片發現腳本
│   ├── schedule-run.ps1       # 排程執行腳本
│   ├── check-secrets.ps1      # 機密掃描腳本
│   └── install-hooks.ps1      # pre-commit hook 安裝
├── docs/
│   ├── USAGE.md               # 使用說明（本文件）
│   ├── DEVELOPMENT_LOG.md     # 開發日誌
│   └── SCHEDULE_SETUP.md      # Windows 排程設定
└── logs/                      # 執行紀錄（自動產生）
```

## 常見問題

**Q: 為什麼找不到新影片？**
- RSS Feed 可能暫時不穩，稍後重試
- 檢查 Channel ID 是否正確
- 改用 `-Mode ManualUrls` 手動指定網址

**Q: 成品是英文的怎麼辦？**
- 確認每個生成指令都有 `--language zh-TW`
- 排程模式已內建此參數

**Q: nlm login 失敗？**
- 確認有 Google 帳號且可存取 NotebookLM
- 檢查防火牆或代理設定
- 手動在瀏覽器開啟 https://notebooklm.google.com 確認可正常使用

**Q: 可以加更多頻道嗎？**
- 可以，直接編輯 `workflow-config.json` 的 `channels` 陣列
- 每個頻道需有 `channel_id`、`rss_url`、`playlist_id`
