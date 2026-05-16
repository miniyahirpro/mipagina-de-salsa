param(
  [Parameter(Mandatory = $false)]
  [string]$CollectionsCsvPath = "c:\Users\manue\Downloads\patreon_astro_v15_FLAG_GENERAL\salida_astro_v15_flag_general\02_colecciones_links_video.csv",

  [Parameter(Mandatory = $false)]
  [string]$GeneralPostsCsvPath = "c:\Users\manue\Downloads\patreon_astro_v15_FLAG_GENERAL\salida_astro_v15_flag_general\03_posts_generales_links_video.csv",

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

function Get-LinkRank([string]$Url) {
  if ([string]::IsNullOrWhiteSpace($Url)) {
    return 99
  }

  try {
    $uri = [Uri]$Url
  } catch {
    return 99
  }

  $domain = $uri.Host.ToLowerInvariant()
  $path = $uri.AbsolutePath.Trim("/").ToLowerInvariant()

  if ($domain -eq "youtu.be") {
    return 0
  }

  if ($domain -like "*youtube.com") {
    if ($path -eq "watch" -or $path -like "live/*" -or $path -like "shorts/*") {
      return 0
    }
    if ($path -like "embed/*") {
      return 2
    }
  }

  if ($domain -like "*youtube-nocookie.com" -and $path -like "embed/*") {
    return 3
  }

  return 4
}

function Is-YouTubeLikeLink([string]$Url) {
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
  $title = $title -replace "^(YouTube|Vimeo|Livestream)\s+", ""
  return $title.Trim()
}

function Get-CleanCollectionName([string]$RawCollection) {
  $collection = Get-Text $RawCollection
  if (-not $collection) {
    return "Sin coleccion"
  }

  $collection = $collection -replace "^\s*\d+\.\s*", ""
  $collection = $collection -replace "\[[^\]]*\]", ""
  $collection = ($collection -replace "\s{2,}", " ").Trim()

  if (-not $collection) {
    return "Sin coleccion"
  }
  return $collection
}

function New-VideoObject {
  param(
    [string]$Section,
    [string]$Collection,
    [string]$PostTitle,
    [string]$PostUrl,
    [string]$RawVideoUrl,
    [string]$Source,
    [int]$Index
  )

  $youtubeId = Get-YouTubeId $RawVideoUrl
  $watchUrl = $null
  $embedUrl = $null
  $thumbnailUrl = $null
  $linkRank = Get-LinkRank $RawVideoUrl

  if ($youtubeId) {
    $watchUrl = "https://www.youtube.com/watch?v=$youtubeId"
    $embedUrl = "https://www.youtube.com/embed/$youtubeId"
    $thumbnailUrl = "https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg"
  } elseif ($RawVideoUrl) {
    if ((Is-YouTubeLikeLink $RawVideoUrl) -and $PostUrl) {
      $watchUrl = $PostUrl
    } else {
      $watchUrl = $RawVideoUrl
    }
  } elseif ($PostUrl) {
    $watchUrl = $PostUrl
  } else {
    return $null
  }

  return [PSCustomObject]@{
    section = $Section
    collection = $Collection
    title = $PostTitle
    description = if ($PostTitle.Length -gt 140) { $PostTitle.Substring(0, 140) + "..." } else { $PostTitle }
    source = $Source
    youtubeId = $youtubeId
    watchUrl = $watchUrl
    embedUrl = $embedUrl
    thumbnailUrl = $thumbnailUrl
    postUrl = $PostUrl
    rank = $linkRank
    index = $Index
  }
}

function Merge-PreferredVideo {
  param(
    [hashtable]$Map,
    [string]$Key,
    [object]$Candidate
  )

  if (-not $Map.ContainsKey($Key)) {
    $Map[$Key] = $Candidate
    return
  }

  $current = $Map[$Key]
  if ($Candidate.rank -lt $current.rank) {
    # Prefer direct YouTube links (watch/live/youtu.be) over embed/nocookie duplicates.
    $Map[$Key] = $Candidate
  }
}

if (-not (Test-Path -LiteralPath $CollectionsCsvPath)) {
  throw "No se encontro el CSV de colecciones: $CollectionsCsvPath"
}
if (-not (Test-Path -LiteralPath $GeneralPostsCsvPath)) {
  throw "No se encontro el CSV de posts generales: $GeneralPostsCsvPath"
}

$collectionRows = Import-Csv -Path $CollectionsCsvPath
$generalRows = Import-Csv -Path $GeneralPostsCsvPath

$collectionOrder = [ordered]@{}
$collectionMap = @{}
$collectionIndex = 0

foreach ($row in $collectionRows) {
  $collection = Get-CleanCollectionName (Get-Text $row.coleccion)
  $title = Get-CleanTitle (Get-Text $row.post_title)
  $postUrl = Get-Text $row.post_url
  $videoUrl = Get-Text $row.video_url
  $source = Get-Text $row.source

  if (-not $collectionOrder.Contains($collection)) {
    $collectionOrder[$collection] = $true
  }

  $video = New-VideoObject -Section "collections" -Collection $collection -PostTitle $title -PostUrl $postUrl -RawVideoUrl $videoUrl -Source $source -Index $collectionIndex
  if ($null -eq $video) {
    continue
  }

  $key = if ($video.youtubeId) {
    "collections|$collection|$postUrl|$($video.youtubeId)"
  } else {
    "collections|$collection|$postUrl|$($video.watchUrl)|$title"
  }

  Merge-PreferredVideo -Map $collectionMap -Key $key -Candidate $video
  $collectionIndex++
}

$orderedCollectionVideos = New-Object System.Collections.Generic.List[object]
foreach ($collectionName in $collectionOrder.Keys) {
  $videos = $collectionMap.Values | Where-Object { $_.collection -eq $collectionName } | Sort-Object index
  foreach ($v in $videos) {
    $orderedCollectionVideos.Add($v)
  }
}

$collectionGroups = New-Object System.Collections.Generic.List[object]
foreach ($collectionName in $collectionOrder.Keys) {
  $videos = $orderedCollectionVideos | Where-Object { $_.collection -eq $collectionName }
  $collectionGroups.Add([PSCustomObject]@{
      name = $collectionName
      count = $videos.Count
      videos = $videos
    })
}

$generalMap = @{}
$generalIndex = 0
foreach ($row in $generalRows) {
  $title = Get-CleanTitle (Get-Text $row.post_title)
  $postUrl = Get-Text $row.post_url
  $videoUrl = Get-Text $row.video_url
  $source = Get-Text $row.source

  $video = New-VideoObject -Section "general" -Collection "Clases en vivo" -PostTitle $title -PostUrl $postUrl -RawVideoUrl $videoUrl -Source $source -Index $generalIndex
  if ($null -eq $video) {
    continue
  }

  $key = if ($video.youtubeId) {
    "general|$postUrl|$($video.youtubeId)"
  } else {
    "general|$postUrl|$($video.watchUrl)|$title"
  }

  Merge-PreferredVideo -Map $generalMap -Key $key -Candidate $video
  $generalIndex++
}

$generalPosts = $generalMap.Values | Sort-Object index

$output = [PSCustomObject]@{
  generatedAt = (Get-Date).ToString("s")
  sourceCsv = [PSCustomObject]@{
    collections = $CollectionsCsvPath
    generalPosts = $GeneralPostsCsvPath
  }
  totalCollections = $collectionGroups.Count
  totalVideos = $orderedCollectionVideos.Count
  collections = $collectionGroups
  totalGeneralPosts = $generalPosts.Count
  generalPosts = $generalPosts
}

$json = $output | ConvertTo-Json -Depth 9
$js = @(
  "// Auto-generated by scripts/build-videos-data.ps1",
  "window.VIDEO_LIBRARY = $json;"
) -join "`n"

Set-Content -Path $OutFile -Value $js -Encoding UTF8

Write-Output "Archivo generado: $OutFile"
Write-Output "Colecciones: $($collectionGroups.Count)"
Write-Output "Videos de colecciones: $($orderedCollectionVideos.Count)"
Write-Output "Posts generales: $($generalPosts.Count)"
