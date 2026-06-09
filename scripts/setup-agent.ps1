<#
.SYNOPSIS
  YT 懶人包 — 環境檢查與安裝腳本。
  檢查 AI Agent 環境是否滿足 YT 工作流需求，若不滿足提供安裝指引。
#>

param(
  [string]$AgentType = "",
  [switch]$Repair
)

$scriptDir = Split-Path -LiteralPath $PSScriptRoot -Parent
$configPath = "$scriptDir\workflow\workflow-config.json"
$statePath = "$scriptDir\workflow\processed-state.json"

$passCount = 0
$failCount = 0
$warnCount = 0

function Write-Step($title) { Write-Host "`n==> $title" -ForegroundColor Cyan }
function Write-Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:passCount++ }
function Write-Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:failCount++ }
function Write-Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:warnCount++ }

Write-Host "========================================================" -ForegroundColor Magenta
Write-Host "  YT lazY 包 — 環境檢查" -ForegroundColor Magenta
Write-Host "  Agent : $AgentType" -ForegroundColor Magenta
Write-Host "========================================================" -ForegroundColor Magenta

# ---- 1. PowerShell 版本 ----
Write-Step "1. PowerShell 版本"
$psVer = $PSVersionTable.PSVersion.Major
if ($psVer -ge 5) {
  Write-Pass "PowerShell $psVer (需求 >= 5)"
} else {
  Write-Fail "PowerShell $psVer，需升級至 5.1 以上"
}

# ---- 2. 執行原則 ----
Write-Step "2. 執行原則 (ExecutionPolicy)"
$policy = Get-ExecutionPolicy
if ($policy -eq "Restricted") {
  Write-Fail "執行原則為 Restricted，無法執行 .ps1 腳本"
  if ($Repair) {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "  已設為 RemoteSigned" -ForegroundColor Green
  } else {
    Write-Host "  修復方式：Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
  }
} else {
  Write-Pass "執行原則：$policy"
}

# ---- 3. Python / uv ----
Write-Step "3. Python / uv 套件管理"
$hasUv = $null -ne (Get-Command "uv" -ErrorAction SilentlyContinue)
$hasPython = $null -ne (Get-Command "python" -ErrorAction SilentlyContinue)

if ($hasUv) {
  $uvVer = uv --version
  Write-Pass "uv 已安裝：$uvVer"
} elseif ($hasPython) {
  $pyVer = python --version 2>&1
  Write-Warn "Python 已安裝但無 uv：$pyVer"
  if ($Repair) {
    pip install uv 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "  uv 已透過 pip 安裝" -ForegroundColor Green }
    else { Write-Fail "pip install uv 失敗" }
  } else {
    Write-Host "  安裝指令：pip install uv" -ForegroundColor Gray
  }
} else {
  Write-Fail "Python 與 uv 皆未安裝"
  Write-Host "  安裝方式：" -ForegroundColor Gray
  Write-Host "  - winget install uv" -ForegroundColor Gray
  Write-Host "  - 或下載 https://docs.astral.sh/uv/" -ForegroundColor Gray
}

# ---- 4. nlm CLI ----
Write-Step "4. NotebookLM CLI (nlm)"
$hasNlm = $null -ne (Get-Command "nlm" -ErrorAction SilentlyContinue)
if ($hasNlm) {
  $nlmVer = nlm --version 2>&1
  Write-Pass "nlm CLI 已安裝：$nlmVer"
} else {
  Write-Fail "nlm CLI 未安裝"
  if ($Repair) {
    if ($hasUv) {
      uv tool install notebooklm-mcp-cli 2>&1 | Out-Null
      if ($LASTEXITCODE -eq 0) { Write-Host "  nlm 已透過 uv 安裝" -ForegroundColor Green }
      else { Write-Fail "uv tool install 失敗" }
    } elseif ($hasPython) {
      pip install notebooklm-mcp-cli 2>&1 | Out-Null
      if ($LASTEXITCODE -eq 0) { Write-Host "  nlm 已透過 pip 安裝" -ForegroundColor Green }
      else { Write-Fail "pip install 失敗" }
    } else {
      Write-Fail "無法安裝 nlm：缺少 Python 或 uv"
    }
  } else {
    Write-Host "  安裝指令：" -ForegroundColor Gray
    Write-Host "  - uv tool install notebooklm-mcp-cli" -ForegroundColor Gray
    Write-Host "  - pip install notebooklm-mcp-cli" -ForegroundColor Gray
  }
}

# ---- 5. nlm 登入狀態 ----
Write-Step "5. nlm 登入狀態"
if ($hasNlm) {
  $loginResult = nlm login --check 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Pass "nlm 已登入 ($loginResult)"
  } else {
    Write-Fail "nlm 未登入或 Token 已過期"
    if ($Repair) {
      nlm login 2>&1
      if ($LASTEXITCODE -eq 0) { Write-Host "  nlm 登入成功" -ForegroundColor Green }
      else { Write-Fail "nlm 登入失敗，請手動執行 nlm login" }
    } else {
      Write-Host "  修復方式：nlm login" -ForegroundColor Gray
      Write-Host "  （會自動開啟瀏覽器進行 Google 驗證）" -ForegroundColor Gray
    }
  }
} else {
  Write-Fail "請先安裝 nlm CLI"
}

# ---- 6. 設定檔 ----
Write-Step "6. 設定檔完整性"
if (Test-Path -LiteralPath $configPath) {
  try {
    $config = Get-Content -LiteralPath $configPath -Raw -Encoding utf8 | ConvertFrom-Json
    $hasChannels = ($config.channels | Measure-Object).Count -gt 0
    $hasNotebook = -not [string]::IsNullOrEmpty($config.notebook_id)
    if ($hasChannels -and $hasNotebook) {
      Write-Pass "設定檔完整（$($config.channels.Count) 個頻道，notebook_id 已設定）"
    } else {
      Write-Warn "設定檔存在但缺少 channels 或 notebook_id"
    }
  } catch {
    Write-Fail "設定檔格式錯誤：$_"
  }
} else {
  Write-Fail "設定檔不存在：$configPath"
}

# ---- 7. 腳本完整性 ----
Write-Step "7. 腳本完整性"
$requiredScripts = @(
  "$PSScriptRoot\discover-videos.ps1",
  "$PSScriptRoot\schedule-run.ps1"
)
$allScriptsExist = $true
foreach ($s in $requiredScripts) {
  if (-not (Test-Path -LiteralPath $s)) {
    Write-Fail "缺少腳本：$s"
    $allScriptsExist = $false
  }
}
if ($allScriptsExist) { Write-Pass "所有必要腳本存在" }

# ---- 8. 已處理狀態檔 ----
Write-Step "8. 已處理狀態"
if (Test-Path -LiteralPath $statePath) {
  try {
    $state = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
    Write-Pass "processed-state.json 存在（$($state.psobject.properties.Count) 筆記錄）"
  } catch {
    Write-Warn "processed-state.json 格式異常，將自動重建"
  }
} else {
  Write-Warn "processed-state.json 不存在（首次執行自動建立）"
}

# ---- 9. MCP 可用性（OpenCode 專屬）----
Write-Step "9. MCP 工具可用性"
if ($AgentType -eq "opencode" -or $AgentType -eq "OpenCode") {
  Write-Host "  以 OpenCode 執行 — 應有 notebooklm_* MCP 工具可用" -ForegroundColor Gray
  Write-Warn "MCP 工具可用性需由 OpenCode 自身確認"
} else {
  Write-Host "  Agent 類型：$AgentType — 將使用 nlm CLI 操作" -ForegroundColor Gray
  Write-Pass "CLI 模式，無需 MCP 檢查"
}

# ---- 總結 ----
Write-Host "`n========================================================" -ForegroundColor Magenta
Write-Host "  檢查結果：" -ForegroundColor Magenta
Write-Host "  PASS: $passCount  FAIL: $failCount  WARN: $warnCount" -ForegroundColor Magenta
Write-Host "========================================================" -ForegroundColor Magenta

if ($failCount -gt 0) {
  if ($Repair) {
    Write-Host "`n部分項目修復失敗，需手動處理。" -ForegroundColor Yellow
    exit 1
  } else {
    Write-Host "`n建議加 -Repair 參數自動修復可處理的項目：" -ForegroundColor Yellow
    Write-Host "  .\setup-agent.ps1 -AgentType $AgentType -Repair" -ForegroundColor Yellow
    exit 1
  }
} else {
  Write-Host "`n環境就緒，可以執行 YT 工作流！" -ForegroundColor Green
  exit 0
}
