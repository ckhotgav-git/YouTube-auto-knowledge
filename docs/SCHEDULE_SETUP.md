# YT 工作流排程 — Windows 工作排程器設定

## 建立排程工作

1. 開啟「工作排程器」（Task Scheduler）
2. 右鍵「工作排程器程式庫」→「建立基本工作...」
3. 名稱：`YT Workflow Pipeline`
4. 觸發程序：選「每週」，設定星期幾與時間
5. 動作：選「啟動程式」
   - 程式或指令碼：`powershell.exe`
   - 新增引數：
     ```
      -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\YouTube-auto-knowledge\scripts\schedule-run.ps1"
      ```
    - 開始位置：`C:\path\to\YouTube-auto-knowledge`

## 手動測試排程腳本

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\schedule-run.ps1"
```

## 注意事項
- 第一次執行前，請先在 terminal 執行 `nlm login` 確保認證有效
- 排程執行時若 auth 過期，腳本會報錯，需重新 `nlm login`
