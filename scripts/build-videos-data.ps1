param(
  [Parameter(Mandatory = $false)]
  [string]$CsvPath = "c:\Users\manue\Downloads\patreon_astro_v15_FLAG_GENERAL\salida_astro_v15_flag_general\02_colecciones_links_video.csv",

  [Parameter(Mandatory = $false)]
  [string]$OutFile = (Join-Path $PSScriptRoot "..\videos-data.js")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Text([object]$Value) {
  if ($null -eq $Value) {
    return ""
  }
  return "$Value".Trim()
}

function Get-YouTubeId([string]$Url) {
  if ([string]::IsNullOrWhiteSpace($Url)) {
    return $null
  }

  try {
    $uri = [Uri]$Url
  } catch {
    return $null
  }

  $domain = $uri.Host.ToLowerInvariant()
  $path = $uri.AbsolutePath.Trim("/")

  if ($domain -eq "youtu.be") {
    $candidate = $path.Split("/")[0]
    if ($candidate -match "^[A-Za-z0-9_-]{11}$") {
      return $candidate
    }
    return $null
  }

  if ($domain -like "*youtube.com" -or $domain -like "*youtube-nocookie.com") {
    $candidate = $null

    if ($path -eq "watch") {
      $queryText = $uri.Query.TrimStart("?")
      foreach ($pair in $queryText.Split("&", [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $parts = $pair.Split("=", 2)
        if ($parts.Count -eq 2 -and $parts[0] -eq "v") {
          $candidate = [Uri]::UnescapeDataString($parts[1])
          break
        }
      }
    } elseif ($path -like "embed/*") {
      $candidate = $path.Substring(6).Split("/")[0]
    } elseif ($path -like "shorts/*") {
      $candidate = $path.Substring(7).Split("/")[0]
    } elseif ($path -like "live/*") {
      $candidate = $path.Substring(5).Split("/")[0]
    }

    if ($candidate -and $candidate -match "^[A-Za-z0-9_-]{11}$") {
      return $candidate
    }
  }

  return $null
}

function Is-YouTubeLink([string]$Url) {
  if ([string]::IsNullOrWhiteSpace($Url)) {
    return $false
  }

  try {
    $uri = [Uri]$Url
  } catch {
    return $false
  }

  $domain = $uri.Host.ToLowerInvariant()
  return ($domain -eq "youtu.be" -or $domain -like "*youtube.com" -or $domain -like "*youtube-nocookie.com")
}

function Get-CleanTitle([string]$RawTitle) {
  $title = Get-Text $RawTitle
  if (-not $title) {
    return "Sin titulo"
  }

  # Some rows start with source prefixes from scraping.
  $title = $title -replace "^(YouTube|Vimeo|Livestream)\s+", ""
  return $title.Trim()
}

function Get-CleanCollectionName([string]$RawCollection) {
  $collection = Get-Text $RawCollection
  if (-not $collection) {
    return "Sin coleccion"
  }

  # Remove leading numeric labels such as "1. "
  $collection = $collection -replace "^\s*\d+\.\s*", ""
  # Remove bracketed IDs such as "[18438]"
  $collection = $collection -replace "\[[^\]]*\]", ""
  # Collapse repeated spaces left by cleanup
  $collection = ($collection -replace "\s{2,}", " ").Trim()

  if (-not $collection) {
    return "Sin coleccion"
  }

  return $collection
}

if (-not (Test-Path -LiteralPath $CsvPath)) {
  throw "No se encontro el CSV: $CsvPath"
}

$rows = Import-Csv -Path $CsvPath
$videos = New-Object System.Collections.Generic.List[object]
$dedupe = @{}
$collectionOrder = @{}
$collectionNames = New-Object System.Collections.Generic.List[string]
$index = 0

foreach ($row in $rows) {
  $collection = Get-CleanCollectionName (Get-Text $row.coleccion)
  $postTitle = Get-CleanTitle (Get-Text $row.post_title)
  $postUrl = Get-Text $row.post_url
  $source = Get-Text $row.source
  $rawVideoUrl = Get-Text $row.video_url

  if (-not $collectionOrder.ContainsKey($collection)) {
    $collectionOrder[$collection] = $collectionNames.Count
    $collectionNames.Add($collection)
  }

  $youtubeId = Get-YouTubeId $rawVideoUrl
  $watchUrl = $null
  $embedUrl = $null
  $thumbnailUrl = $null

  if ($youtubeId) {
    $watchUrl = "https://www.youtube.com/watch?v=$youtubeId"
    $embedUrl = "https://www.youtube.com/embed/$youtubeId"
    $thumbnailUrl = "https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg"
  } elseif ($rawVideoUrl) {
    if ((Is-YouTubeLink $rawVideoUrl) -and $postUrl) {
      # Broken or partial YouTube URL, use Patreon post as safer fallback.
      $watchUrl = $postUrl
    } else {
      $watchUrl = $rawVideoUrl
    }
  } elseif ($postUrl) {
    $watchUrl = $postUrl
  } else {
    continue
  }

  $dedupeKey = if ($youtubeId) {
    "$collection|$postUrl|$youtubeId"
  } else {
    "$collection|$postUrl|$watchUrl|$postTitle"
  }

  if ($dedupe.ContainsKey($dedupeKey)) {
    continue
  }
  $dedupe[$dedupeKey] = $true

  $videos.Add([PSCustomObject]@{
      index = $index
      collection = $collection
      title = $postTitle
      description = if ($postTitle.Length -gt 130) { $postTitle.Substring(0, 130) + "..." } else { $postTitle }
      source = $source
      youtubeId = $youtubeId
      watchUrl = $watchUrl
      embedUrl = $embedUrl
      thumbnailUrl = $thumbnailUrl
      postUrl = $postUrl
    })
  $index++
}

$groups = New-Object System.Collections.Generic.List[object]
foreach ($name in $collectionNames) {
  $items = $videos | Where-Object { $_.collection -eq $name } | Sort-Object index
  $groups.Add([PSCustomObject]@{
      name = $name
      count = $items.Count
      videos = $items
    })
}

$output = [PSCustomObject]@{
  generatedAt = (Get-Date).ToString("s")
  sourceCsv = $CsvPath
  totalCollections = $groups.Count
  totalVideos = $videos.Count
  collections = $groups
}

$json = $output | ConvertTo-Json -Depth 8
$js = @(
  "// Auto-generated by scripts/build-videos-data.ps1",
  "window.VIDEO_LIBRARY = $json;"
) -join "`n"

Set-Content -Path $OutFile -Value $js -Encoding UTF8

Write-Output "Archivo generado: $OutFile"
Write-Output "Colecciones: $($groups.Count)"
Write-Output "Videos: $($videos.Count)"
