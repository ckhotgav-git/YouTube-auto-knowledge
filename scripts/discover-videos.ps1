param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigPath,

  [string]$KeywordFilter = "",

  [int]$MaxVideos = 5,

  [string]$Mode = "interactive",

  [string]$ManualUrls = ""
)

$ErrorActionPreference = "Stop"

# ---- Load config ----
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$processedStatePath = [System.Environment]::ExpandEnvironmentVariables($config.processed_state_path)

# ---- Load processed state ----
$processed = @{}
if (Test-Path -LiteralPath $processedStatePath) {
  $raw = Get-Content -LiteralPath $processedStatePath -Raw | ConvertFrom-Json
  $raw.psobject.properties | ForEach-Object { $processed[$_.Name] = $_.Value }
}

$ns = @{
  a     = "http://www.w3.org/2005/Atom"
  yt    = "http://www.youtube.com/xml/schemas/2015"
  media = "http://search.yahoo.com/mrss/"
}

function Get-Field($entryXml, $xpath) {
  $result = Select-Xml -Content $entryXml -XPath $xpath -Namespace $ns
  if ($result) { return $result.Node.InnerText }
  return ""
}

function Fetch-RssWithRetry($url, $maxRetries = 3) {
  for ($i = 1; $i -le $maxRetries; $i++) {
    try {
      $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
      $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 15
      if ($response.StatusCode -eq 200 -and $response.Content -match '<feed') {
        return $response.Content
      }
    } catch {
      if ($i -lt $maxRetries) {
        $wait = $i * 5
        Start-Sleep -Seconds $wait
      }
    }
  }
  return $null
}

# ---- Parse manual URLs ----
$newVideos = @()

if ($ManualUrls -ne "") {
  $urls = $ManualUrls -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  foreach ($url in $urls) {
    if ($url -match 'v=([a-zA-Z0-9_-]{11})') {
      $videoId = $Matches[1]
      if (-not $processed.ContainsKey($videoId)) {
        $newVideos += @{
          video_id    = $videoId
          title       = "[Pending fetch] $url"
          url         = $url
          published   = ""
          channel     = "manual"
          description = ""
        }
      }
    }
  }
  $result = @{
    new_videos    = $newVideos
    total_found   = $newVideos.Count
    scanned_at    = (Get-Date -Format "o")
    all_video_ids = $newVideos | ForEach-Object { $_.video_id }
    source        = "manual"
  }
  Write-Output ($result | ConvertTo-Json -Depth 3)
  return
}

# ---- Per-channel limit ----
$perChannelMax = $config.defaults.max_per_channel
if (-not $perChannelMax) { $perChannelMax = $MaxVideos }

# ---- Discover via RSS ----
foreach ($ch in $config.channels) {
  $channelId = $ch.channel_id
  $channelNewCount = 0

  # Try channel_id RSS (with retry)
  $rssUrl = "https://www.youtube.com/feeds/videos.xml?channel_id=$channelId"
  $feedXml = Fetch-RssWithRetry -url $rssUrl

  # Fallback: try playlist_id (UULF prefix for long-form only)
  if (-not $feedXml -and $channelId -match '^UC') {
    $playlistId = "UULF" + $channelId.Substring(2)
    $rssUrl = "https://www.youtube.com/feeds/videos.xml?playlist_id=$playlistId"
    $feedXml = Fetch-RssWithRetry -url $rssUrl
  }

  if (-not $feedXml) {
    Write-Warning "RSS unavailable for '$($ch.name)' (tried both channel_id and playlist_id)"
    continue
  }

  $entryNodes = Select-Xml -Content $feedXml -XPath "//a:entry" -Namespace $ns
  if (-not $entryNodes) { continue }

  foreach ($entryNode in $entryNodes) {
    $entryXml = $entryNode.Node.OuterXml
    $videoId = Get-Field $entryXml "//yt:videoId"
    if (-not $videoId) { continue }
    if ($processed.ContainsKey($videoId)) { continue }

    $title = Get-Field $entryXml "//a:title"
    $url = "https://youtube.com/watch?v=$videoId"
    $published = Get-Field $entryXml "//a:published"
    $description = Get-Field $entryXml "//media:group/media:description"

    if ($KeywordFilter -ne "") {
      $keywords = $KeywordFilter -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
      if ($keywords.Count -gt 0) {
        $text = "$title $description".ToLower()
        $matched = $false
        foreach ($kw in $keywords) {
          if ($text -match [regex]::Escape($kw.ToLower())) { $matched = $true; break }
        }
        if (-not $matched) { continue }
      }
    }

    $descPreview = if ($description) { $description.Substring(0, [Math]::Min(200, $description.Length)) } else { "" }

    $newVideos += @{
      video_id    = $videoId
      title       = $title
      url         = $url
      published   = $published
      channel     = $ch.name
      description = $descPreview
    }

    $channelNewCount++
    if ($channelNewCount -ge $perChannelMax) { break }
  }

  if ($newVideos.Count -ge $MaxVideos) { break }
}

# ---- Output as JSON ----
$result = @{
  new_videos    = $newVideos
  total_found   = $newVideos.Count
  scanned_at    = (Get-Date -Format "o")
  all_video_ids = $newVideos | ForEach-Object { $_.video_id }
  source        = if ($ManualUrls) { "manual" } else { "rss" }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
