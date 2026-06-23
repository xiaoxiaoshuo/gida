#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Collect Fear & Greed Index from alternative.me and write to data files.
.DESCRIPTION
    Fetches the latest Fear & Greed Index value. Tries API first, falls back to web scraping.
    Writes to fear-greed_latest.json and updates macro.VIX in prices_latest.json.
    Created: 2026-06-24
#>
#Requires -Version 5.1

$ErrorActionPreference = "Stop"
$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$now = Get-Date
$timestamp = $now.ToString("yyyy-MM-dd HH:mm")
$isoTimestamp = $now.ToString("yyyy-MM-ddTHH:mm:ssK")

# ---- Config ----
$fngFile = "$workspace\data\market\fear-greed_latest.json"
$pricesFile = "$workspace\data\market\prices_latest.json"

# ---- Helper: try main API ----
function Fetch-FromAPI {
    Write-Host "[FNG] Trying alternative.me API..."
    try {
        $url = "https://alternative.me/api/crypto/fear-and-greed-index/latest"
        $apiResult = Invoke-RestMethod -Uri $url -TimeoutSec 15 -ErrorAction Stop
        # Handle different response shapes
        if ($apiResult.data -and $apiResult.data.value) {
            return @{
                value = [int]$apiResult.data.value
                classification = "$($apiResult.data.value_classification)"
                apiTimestamp = "$($apiResult.data.timestamp)"
                source = "alternative.me API (v2)"
            }
        } elseif ($apiResult -is [array] -and $apiResult[0].value) {
            return @{
                value = [int]$apiResult[0].value
                classification = "$($apiResult[0].value_classification)"
                apiTimestamp = "$($apiResult[0].timestamp)"
                source = "alternative.me API (array)"
            }
        } elseif ($apiResult.value) {
            return @{
                value = [int]$apiResult.value
                classification = "$($apiResult.value_classification)"
                apiTimestamp = "$($apiResult.timestamp)"
                source = "alternative.me API (v1)"
            }
        }
        Write-Warning "[FNG] API returned unexpected shape, trying v1 endpoint..."
    } catch {
        Write-Warning "[FNG] API v2 failed: $_"
    }
    
    # Fallback to v1 API
    try {
        $url = "https://api.alternative.me/fng/?limit=1"
        $apiResult = Invoke-RestMethod -Uri $url -TimeoutSec 15 -ErrorAction Stop
        if ($apiResult.data -and $apiResult.data[0].value) {
            return @{
                value = [int]$apiResult.data[0].value
                classification = "$($apiResult.data[0].value_classification)"
                apiTimestamp = "$($apiResult.data[0].timestamp)"
                source = "alternative.me API v1"
            }
        }
    } catch {
        Write-Warning "[FNG] API v1 also failed: $_"
    }
    return $null
}

# ---- Helper: web_fetch fallback ----
function Fetch-FromWeb {
    Write-Host "[FNG] Trying web fetch from alternative.me homepage..."
    try {
        $html = Invoke-WebRequest -Uri "https://alternative.me/crypto/fear-and-greed-index/" -TimeoutSec 30 -UseBasicParsing -ErrorAction Stop
        # Parse the page for the FNG value - look for the big number
        if ($html.Content -match '"value":\s*(\d+)') {
            $val = [int]$Matches[1]
        } elseif ($html.Content -match 'class="[^"]*fng-circle[^"]*"[^>]*>\s*(\d+)\s*<') {
            $val = [int]$Matches[1]
        } elseif ($html.Content -match '(\d+)\s*/\s*100') {
            $val = [int]$Matches[1]
        } else {
            # Try to find any number that looks like an FNG value (1-100)
            $nums = [regex]::Matches($html.Content, '\b([5-9][0-9]|100)\b') | ForEach-Object { $_.Groups[1].Value }
            if ($nums.Count -gt 0) {
                $val = [int]$nums[0]
            } else {
                return $null
            }
        }
        
        # Try to extract classification
        $classification = "Unknown"
        if ($html.Content -match '(Extreme Fear|Fear|Neutral|Greed|Extreme Greed)') {
            $classification = $Matches[1]
        }
        
        return @{
            value = $val
            classification = $classification
            apiTimestamp = $now.ToString("yyyy-MM-dd")
            source = "alternative.me web scrape"
        }
    } catch {
        Write-Warning "[FNG] Web fetch failed: $_"
    }
    return $null
}

# ---- Helper: write to fear-greed_latest.json ----
function Write-FngFile {
    param($data, $fetchedAt)
    
    # Convert Unix timestamp to readable date if needed
    $ts = $data.apiTimestamp
    if ($ts -match '^\d{9,10}$') {
        $epoch = [DateTime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)
        $ts = $epoch.AddSeconds([double]$ts).ToLocalTime().ToString("yyyy-MM-dd HH:mm")
    }
    
    $output = @{
        timestamp = $ts
        value = $data.value
        classification = $data.classification
        source = $data.source
        fetched_at = $fetchedAt
    }
    $json = $output | ConvertTo-Json -Compress
    $json | Out-File -FilePath $fngFile -Encoding utf8
    Write-Host "[FNG] Written to $fngFile : value=$($data.value) classification=$($data.classification)"
}

# ---- Helper: update prices_latest.json macro.VIX ----
function Update-PricesFile {
    param($data, $fetchedAt)
    
    if (-not (Test-Path $pricesFile)) {
        Write-Warning "[FNG] $pricesFile not found, skipping macro.VIX update"
        return
    }
    
    try {
        $prices = Get-Content $pricesFile -Raw -Encoding utf8 | ConvertFrom-Json
        
        # Build VIX entry with FNG data
        $vixEntry = @{
            value = $data.value
            source = "alternative.me_FNG"
            timestamp = $fetchedAt
            value_classification = $data.classification
            note = "FNG独立采集:v1 - F&G替代VIX作为情绪指标"
            confidence = "medium"
            raw = ""
        }
        
        $prices.macro.VIX = $vixEntry
        
        $prices | ConvertTo-Json -Depth 10 | Out-File -FilePath $pricesFile -Encoding utf8
        Write-Host "[FNG] Updated macro.VIX in $pricesFile"
    } catch {
        Write-Warning "[FNG] Failed to update prices_latest.json: $_"
    }
}

# ---- Main execution ----
Write-Host "=== Fear & Greed Index Collector v1 ==="
Write-Host "Time: $timestamp"

# Try API first
$result = Fetch-FromAPI

# Fallback to web
if (-not $result) {
    Write-Warning "[FNG] API failed, falling back to web scrape..."
    $result = Fetch-FromWeb
}

# Last resort: read last known value
if (-not $result) {
    Write-Warning "[FNG] All sources failed! Reading last known value..."
    if (Test-Path $fngFile) {
        try {
            $last = Get-Content $fngFile -Raw -Encoding utf8 | ConvertFrom-Json
            $age = [int]((Get-Date) - [DateTime]::ParseExact($last.fetched_at, "yyyy-MM-dd HH:mm", $null)).TotalHours
            $result = @{
                value = [int]$last.value
                classification = "$($last.classification)"
                apiTimestamp = "$($last.timestamp)"
                source = "stale($($age)h old): $($last.source)"
            }
            Write-Warning "[FNG] Using stale data ($age hrs old)"
        } catch {
            Write-Error "[FNG] CRITICAL: No data available at all!"
            exit 1
        }
    } else {
        Write-Error "[FNG] CRITICAL: No data file and no source available!"
        exit 1
    }
}

# Write output
Write-FngFile $result $timestamp
Update-PricesFile $result $timestamp

Write-Host "=== FNG Collection Complete ==="
Write-Host "Value: $($result.value) | Classification: $($result.classification)"
