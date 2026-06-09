# YouTube Auto Knowledge 📚

> 自動掃描 YouTube 頻道 → NotebookLM 分析 → 繁體中文報告 + 簡報 + 錄音 + 影片 + 資訊圖表

**讓 AI Agent 幫你自動整理 YouTube 知識！**

---

## 功能

- 🎯 **自動發現** — 掃描指定 YouTube 頻道的最新影片
- 🤖 **AI 驅動** — 支援 OpenCode、Claude Code、Cursor、Windsurf 等多種 AI Agent
- 📄 **文字報告** — 自動生成 Briefing Doc 或 Study Guide
- 🎬 **多種成品** — 簡報、影片、Podcast、資訊圖表一次產出
- 🌏 **繁體中文** — 所有內容預設繁體中文輸出
- 🔒 **安全第一** — 內建機密掃描，防止 API Key 與密碼外洩

## 快速開始

```powershell
# 1. 安裝 NotebookLM CLI
uv tool install notebooklm-mcp-cli

# 2. 登入
nlm login

# 3. 設定頻道（複製範本後編輯）
copy workflow\workflow-config.example.json workflow\workflow-config.json

# 4. 告訴你的 AI Agent：
#    「執行 YT 懶人包」
```

## 系統需求

- **Windows 10/11**（PowerShell 腳本依賴）
- **PowerShell 5.1+**
- **uv** 或 **Python 3.8+**
- **NotebookLM 帳號**（Google 帳號）

## 目錄結構

```
YouTube-auto-knowledge/
├── workflow/          # AI Agent 操作說明與設定
├── scripts/           # 自動化腳本
├── docs/              # 文件
└── logs/              # 執行紀錄
```

## 作者

- **點哥** — 原始構想與需求
- **[未來腦力研究社](https://www.youtube.com/@user-io6to2ls9y)** — 開發與維護

## 授權

[MIT](LICENSE)

## 安全性

使用前請詳閱 [SECURITY.md](SECURITY.md)。本專案已內建：
- `.gitignore` 自動排除機密檔案
- `check-secrets.ps1` 提交前掃描
- pre-commit hook 自動安裝

## 免責聲明

本工具僅供學習與研究使用。使用者應自行遵守 YouTube 與 Google NotebookLM 的服務條款。
