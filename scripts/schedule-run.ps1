<#
.SYNOPSIS
  Headless YT Workflow runner for Windows Task Scheduler.
  Corrected flow: YT sources → report → report as source → artifacts.
#>

param(
  [string]$ConfigPath = "$PSScriptRoot\..\workflow\workflow-config.json",
  [string]$LogDir = "$PSScriptRoot\..\logs"
)

$ErrorActionPreference = "Stop"
$nlCLI = "nlm"
$logFile = "$LogDir\schedule-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

$logDir = Split-Path -Parent $logFile
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-Log($msg) {
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  "$timestamp $msg" | Out-File -LiteralPath $logFile -Encoding utf8 -Append
  Write-Host $msg
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$notebookId = $config.notebook_id
$defaults = $config.defaults
$reportFormat = $defaults.report_format
$artifacts = $defaults.artifacts

Write-Log "==========================================="
Write-Log "YT Workflow Pipeline — Scheduled Run"
Write-Log "Notebook: $notebookId"
Write-Log "==========================================="

# ---- Step 1: Discover ----
Write-Log "[1/7] Discovering new videos..."
$discovered = & "$PSScriptRoot\discover-videos.ps1" -ConfigPath $ConfigPath -MaxVideos $defaults.max_videos_per_run -Mode scheduled 2>&1
$result = $discovered | Out-String | ConvertFrom-Json

if ($result.total_found -eq 0) {
  Write-Log "  No new videos found. Exiting."
  exit 0
}
Write-Log "  Found $($result.total_found) new video(s)."

# ---- Step 2: Add sources (dedup by checking existing) ----
Write-Log "[2/7] Adding sources to NotebookLM..."
Write-Log "  (Checking for duplicates...)"
$existingResult = & $nlCLI get notebook $notebookId 2>&1
$existingTitles = @()
if ($LASTEXITCODE -eq 0) {
  $existingJson = $existingResult | Out-String | ConvertFrom-Json
  foreach ($s in $existingJson.value.sources) { $existingTitles += $s.title }
}

$sourceIds = @()
foreach ($v in $result.new_videos) {
  $isDup = $false
  foreach ($et in $existingTitles) {
    if ($et -match [regex]::Escape(($v.title -replace '^.{0,20}', ''))) { $isDup = $true; break }
  }
  if ($isDup) { Write-Log "  Skipping (exists): $($v.title)"; continue }

  Write-Log "  Adding: $($v.title)"
  $lines = & $nlCLI add url $notebookId $v.url 2>&1
  if ($LASTEXITCODE -eq 0) {
    $sid = ""; foreach ($l in $lines) { if ($l -match 'Source ID:\s*(\S+)') { $sid = $Matches[1]; break } }
    $sourceIds += $sid; Write-Log "    + $sid"
    Start-Sleep -Seconds 3
  } else { Write-Log "    ! Failed" }
}

if ($sourceIds.Count -eq 0) { Write-Log "  No new sources. Exiting."; exit 0 }

# ---- Step 3: Generate report ----
Write-Log "[3/7] Generating report ($reportFormat)..."
switch ($reportFormat) {
  "briefing_doc"  { $reportArgs = @("report", "create", $notebookId, "--format", "Briefing Doc", "--language", "zh-TW", "--confirm") }
  "study_guide"   { $reportArgs = @("report", "create", $notebookId, "--format", "Study Guide", "--language", "zh-TW", "--confirm") }
  default         { $reportArgs = @("report", "create", $notebookId, "--format", "Briefing Doc", "--language", "zh-TW", "--confirm") }
}

$reportResult = & $nlCLI $reportArgs 2>&1
$reportId = ""
if ($LASTEXITCODE -eq 0) {
  foreach ($l in $reportResult) { if ($l -match '(?:Report|Artifact)\s*ID:\s*(\S+)' -or $l -match '(\S{8}-\S{4}-\S{4}-\S{4}-\S{12})') { $reportId = $Matches[1] } }
  Write-Log "  ✓ Report created"
} else { Write-Log "  ✗ Failed: $reportResult" }

# ---- Step 4: Download report and add as source ----
Write-Log "[4/7] Adding report as source for downstream artifacts..."
$reportText = ""
if ($reportId) {
  $reportText = & $nlCLI download report $notebookId $reportId 2>&1
}
if (-not $reportText) {
  Write-Log "  (Report download unavailable, will use notebook-level generation)"
  $reportSourceId = $null
} else {
  $reportTitle = "Workflow Report - $(Get-Date -Format 'yyyy-MM-dd')"
  $lines = & $nlCLI add text $notebookId "`"$reportTitle`"" $reportText 2>&1
  if ($LASTEXITCODE -eq 0) {
    $reportSourceId = ""; foreach ($l in $lines) { if ($l -match 'Source ID:\s*(\S+)') { $reportSourceId = $Matches[1]; break } }
    Write-Log "  ✓ Report added as source: $reportSourceId"
  } else {
    Write-Log "  ✗ Failed to add report as source"
    $reportSourceId = $null
  }
}

# ---- Step 5: Generate artifacts from report source ----
Write-Log "[5/7] Generating artifacts..."
$cmdMap = @{ slide_deck = "slides"; video = "video"; audio = "audio"; infographic = "infographic" }
foreach ($artifact in $artifacts) {
  $cmd = $cmdMap[$artifact]
  if (-not $cmd) { continue }
  Write-Log "  Generating $artifact..."
  $artArgs = @($cmd, "create", $notebookId, "--language", "zh-TW", "--confirm")
  if ($reportSourceId) { $artArgs += "--source-ids"; $artArgs += $reportSourceId }
  $artResult = & $nlCLI $artArgs 2>&1
  Write-Log "    $(if ($LASTEXITCODE -eq 0) { 'OK' } else { "FAILED" })"
}

# ---- Step 6: Update processed state ----
Write-Log "[6/7] Updating processed state..."
$statePath = if ([System.IO.Path]::IsPathRooted($config.processed_state_path)) { [System.Environment]::ExpandEnvironmentVariables($config.processed_state_path) } else { Join-Path (Split-Path -Parent $ConfigPath | Split-Path -Parent) $config.processed_state_path }
$stateDir = Split-Path -Parent $statePath
if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$existingState = @{}
if (Test-Path -LiteralPath $statePath) {
  $raw = Get-Content -LiteralPath $statePath -Raw -ErrorAction SilentlyContinue
  if ($raw) { ($raw | ConvertFrom-Json).psobject.properties | ForEach-Object { $existingState[$_.Name] = $_.Value } }
}
$now = (Get-Date -Format "o")
foreach ($v in $result.new_videos) {
  $existingState[$v.video_id] = @{ title = $v.title; url = $v.url; channel = $v.channel; processed = $now }
}
$existingState | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $statePath -Encoding utf8
Write-Log "  ✓ State saved ($($existingState.Count) total)"

# ---- Step 7: Done ----
Write-Log "[7/7] Pipeline complete!"
Write-Log "==========================================="
Write-Log "Summary: $($result.total_found) videos, $reportFormat report"
Write-Log "Artifacts: [$($artifacts -join ', ')]"
Write-Log "Notebook: https://notebooklm.google.com/notebook/$notebookId"
Write-Log "Log: $logFile"
Write-Log "==========================================="
