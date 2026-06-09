# 安全性政策 — YouTube Auto Knowledge

## ⚠️ 資料保密提醒

本工具會與以下外部服務互動：
- **YouTube**（讀取公開頻道資訊）
- **NotebookLM (Google)**（儲存與處理來源資料）

請注意：

### 1. 絕對不要在 Git 提交以下內容

| 資料類型 | 範例 | 風險 |
|---------|------|------|
| API Key | Google API Key, OpenAI Key | 他人盜用額度 |
| Token | GitHub Token, NotebookLM Token | 帳號被盜用 |
| 密碼 | 任何服務的密碼 | 帳號被盜用 |
| 私鑰 | SSH Private Key, SSL Key | 伺服器被入侵 |
| 環境變數檔 | `.env` 檔案 | 通常含密碼 |
| 個人 cookie | `cookies.txt` | 工作階段被竊取 |

### 2. 本專案內建保護機制

- **`.gitignore`** — 自動排除常見機密檔案模式
- **`scripts/check-secrets.ps1`** — 提交前掃描腳本，偵測潛在機密
- **設定檔範本化** — `workflow-config.example.json` 不含真實資料
- **AI Agent 操作約束** — SKILL.md 中明確定義不可寫入機密

### 3. 使用前建議執行

```powershell
# 安裝 pre-commit hook（每次 git commit 自動掃描）
powershell -ExecutionPolicy Bypass -File scripts\install-hooks.ps1
```

### 4. 若不小心洩漏了

1. **立即撤銷該憑證**（去對應服務重新產生）
2. **從 Git 歷史中清除**（使用 `git filter-repo` 或 `BFG Repo-Cleaner`）
3. **通知專案維護者**（若在公開 repo）

### 5. AI Agent 使用規範

當 AI Agent 執行此工作流時：
- ❌ 不得將 API Key、Token、密碼寫入任何檔案
- ❌ 不得將 `.env`、`*.key`、`*.pem` 等加入 Git
- ✅ 使用 `workflow-config.example.json` 作為範本，使用者自行填入真實資料
- ✅ 首次執行前先執行 `setup-agent.ps1` 檢查環境

---

*安全是每個使用者的責任，請謹慎保管您的憑證。*
