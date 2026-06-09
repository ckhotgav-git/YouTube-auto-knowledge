<#
.SYNOPSIS
  安裝 Git pre-commit hook，每次提交前自動掃描機密。
#>

$hookDir = ".git\hooks"
$hookPath = "$hookDir\pre-commit"

if (-not (Test-Path -LiteralPath $hookDir)) {
  Write-Host "❌ 這不是一個 Git 倉庫，或 .git 不存在" -ForegroundColor Red
  exit 1
}

$hookContent = @'
#!/usr/bin/env pwsh
# pre-commit hook — 自動掃描機密資料
$result = & powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\check-secrets.ps1" -CommitHook 2>&1
if ($LASTEXITCODE -ne 0) {
  exit 1
}
'@

Set-Content -LiteralPath $hookPath -Value $hookContent -Encoding utf8
Write-Host "✅ pre-commit hook 已安裝：$hookPath" -ForegroundColor Green
Write-Host "   每次 git commit 前會自動掃描機密資料。" -ForegroundColor Green
