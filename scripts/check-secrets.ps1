<#
.SYNOPSIS
  機密資料掃描腳本 — 檢查即將提交的檔案是否含有潛在機密。
  可作為 pre-commit hook 使用。

.LINK
  SECURITY.md
#>

param(
  [string[]]$Paths = @("."),
  [switch]$CommitHook   # 作為 pre-commit hook 執行
)

$foundIssues = 0
$secretPatterns = @(
  # API Keys 常見格式
  '(?i)api[_-]?key\s*[:=]\s*["'']?[A-Za-z0-9_\-]{20,}',
  '(?i)api[_-]?secret\s*[:=]\s*["'']?[A-Za-z0-9_\-]{20,}',
  # Google / YouTube
  'AIza[0-9A-Za-z\-_]{35}',
  # AWS
  '(?i)AKIA[0-9A-Z]{16}',
  '(?i)aws[_-]?access[_-]?key[_-]?id',
  '(?i)aws[_-]?secret[_-]?access[_-]?key',
  # GitHub Token
  'ghp_[0-9a-zA-Z]{36}',
  'gho_[0-9a-zA-Z]{36}',
  'github[_-]?token',
  # OpenAI
  'sk-[0-9a-zA-Z]{20,}',
  # JWT / Bearer
  '(?i)bearer\s+[A-Za-z0-9_\-\.]{20,}',
  # Private Key
  '-----BEGIN\s+(RSA|DSA|EC|OPENSSH|PGP)\s+PRIVATE\s+KEY-----',
  # Password
  '(?i)password\s*[:=]\s*["'']?.{8,}',
  '(?i)passwd\s*[:=]\s*["'']?.{8,}',
  # Connection strings
  '(?i)connection[_-]?string\s*[:=]\s*["'']?.{20,}',
  # Token general
  '(?i)token\s*[:=]\s*["'']?[A-Za-z0-9_\-\.]{20,}'
)

$skipPatterns = @(
  '\.gitignore$',
  'SECURITY\.md$',
  'check-secrets\.ps1$',
  '\.md$'   # Markdown 文件通常只是說明
)

function Should-Skip($file) {
  foreach ($pattern in $skipPatterns) {
    if ($file -match $pattern) { return $true }
  }
  return $false
}

Write-Host "==> Scanning for secrets in staged files..." -ForegroundColor Cyan

$targetFiles = @()
if ($CommitHook) {
  # 作為 pre-commit hook：只掃 staged 檔案
  $targetFiles = & git diff --cached --name-only --diff-filter=ACM 2>$null
} else {
  # 手動掃描
  foreach ($base in $Paths) {
    $targetFiles += Get-ChildItem -LiteralPath $base -Recurse -File | Where-Object {
      -not (Should-Skip($_.FullName))
    } | ForEach-Object { $_.FullName }
  }
}

foreach ($file in $targetFiles) {
  if (-not (Test-Path -LiteralPath $file)) { continue }
  if ($CommitHook) {
    $content = & git show ":$file" 2>$null
    if (-not $content) { continue }
  } else {
    $content = Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
  }

  $lineNum = 0
  foreach ($line in ($content -split "`n")) {
    $lineNum++
    foreach ($pattern in $secretPatterns) {
      if ($line -match $pattern) {
        Write-Host "  [WARN] $file:$lineNum - 偵測到可能的機密 ($($Matches[0].Substring(0, [Math]::Min(30, $Matches[0].Length))))" -ForegroundColor Yellow
        $foundIssues++
        break
      }
    }
  }
}

if ($foundIssues -gt 0) {
  Write-Host "`n⚠ 發現 $foundIssues 個潛在機密！" -ForegroundColor Yellow
  Write-Host "  請檢查以上檔案，確認不包含真實機密資料。" -ForegroundColor Yellow
  Write-Host "  如有疑慮，請參考 SECURITY.md 處理方式。" -ForegroundColor Yellow
  if ($CommitHook) {
    Write-Host "`n  若要強制提交，請使用: git commit --no-verify" -ForegroundColor Red
  }
  exit 1
} else {
  Write-Host "  [PASS] 未偵測到機密資料" -ForegroundColor Green
  exit 0
}
