#!/usr/bin/env pwsh
<#
.SYNOPSIS
    collector-master.ps1 — v0.2 Unified Collector Scheduler (All Sources)
.DESCRIPTION
    Unified master scheduler that checks data freshness for each source
    and triggers collection scripts when data is stale.

    Sources managed:
    - fng:   Fear & Greed Index        (60min interval)
    - hn:    Hacker News Top 30        (30min interval)
    - gh:    GitHub Trending           (4h  interval)
    - ai:    AI News                   (6h  interval)
    - macro: Macro Data                (4h  interval)

    Price collecting (HourlyPriceCollector) is a separate cron and NOT managed here.

    Uses config file to track last run times and a mutex to prevent re-entry.
    Designed to be called every 30min via Task Scheduler (System account).
    Each script execution has 180-second timeout protection.

    Created: 2026-06-24 (Subagent G-110)
.NOTES
    Version: 0.2 (v2 Phase 1 — All Sources)
    Workspace: C:\Users\Administrator\clawd\agents\workspace-gid
#>
#Requires -Version 5.1

$ErrorActionPreference = "Continue"
$base = "C:\Users\Administrator\clawd\agents\workspace-gid"
$configDir = "$base\system"
$configFile = "$configDir\collector-master-config.json"
$logDir = "$base\data\system"
$logFile = "$logDir\collector-master.log"
$mutexName = "Local\GidaCollectorMaster_Mutex"

# ---- Ensure directories exist ----
foreach ($d in @($configDir, $logDir)) {
    if (!(Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# ---- Logging helper ----
function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$ts [$Level] $Message"
    Write-Host $line
    try { Add-Content -Path $logFile -Value $line -Encoding UTF8 } catch {}
}

# ---- Mutex ----
$mutex = $null
$mutexHeld = $false
try {
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
    if ($mutex.WaitOne(0)) {
        $mutexHeld = $true
    } else {
        Write-Log "SKIP" "Another instance holds mutex — exiting"
        exit 0
    }
} catch [System.Threading.AbandonedMutexException] {
    $mutexHeld = $true
    Write-Log "WARN" "Mutex recovered from abandoned state"
} catch {
    Write-Log "WARN" "Mutex init failed: $_ (proceeding without lock)"
    $mutexHeld = $true
}

try {
    # ---- Config load ----
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Write-Log "ERROR" "Failed to parse config JSON: $_ — reinitializing"
            $config = New-Object PSObject
        }
    } else {
        Write-Log "INFO" "Config not found at $configFile — initializing new config"
        $config = New-Object PSObject
    }

    # ---- Source definitions (v0.2 - All Sources) ----
    $sources = @{
        "fng" = @{
            "script"   = "scripts/collect-fear-greed.ps1"
            "interval" = 60   # minutes
            "key"      = "fng_last"
            "desc"     = "Fear & Greed Index"
            "timeout"  = 180  # seconds
        }
        "hn" = @{
            "script"   = "scripts/fetch-hn-top30-v2.ps1"
            "interval" = 30   # minutes
            "key"      = "hn_last"
            "desc"     = "Hacker News Top 30"
            "timeout"  = 180
        }
        "gh" = @{
            "script"   = "scripts/gh-trending-browser-v5.ps1"
            "interval" = 240  # 4 hours
            "key"      = "gh_last"
            "desc"     = "GitHub Trending"
            "timeout"  = 180
        }
        "ai" = @{
            "script"   = "scripts/merge-ai-news.ps1"
            "interval" = 360  # 6 hours
            "key"      = "ai_last"
            "desc"     = "AI News"
            "timeout"  = 180
        }
        "macro" = @{
            "script"   = "scripts/macro-data-collector.ps1"
            "interval" = 240  # 4 hours
            "key"      = "macro_last"
            "desc"     = "Macro Data"
            "timeout"  = 180
        }
    }

    $now = Get-Date
    $anyTriggered = $false
    $results = @()  # track per-source results for structured log

    Write-Log "INFO" "Collector-master v0.2 starting — checking $($sources.Count) sources"

    foreach ($s in $sources.Keys) {
        $src = $sources[$s]
        $fullScript = "$base\$($src.script)"

        # Read last run time from config
        $lastStr = if ($config.$($src.key)) { "$($config.$($src.key))" } else { $null }
        $last = if ($lastStr) {
            try { [DateTime]$lastStr } catch { [DateTime]"2000-01-01" }
        } else {
            [DateTime]"2000-01-01"
        }

        $ageMinutes = ($now - $last).TotalMinutes
        $needsRun = $ageMinutes -ge $src.interval

        $statusLine = "[$s] ($($src.desc)) last=$($last.ToString('yyyy-MM-dd HH:mm')) age=$("{0:N1}" -f $ageMinutes)min interval=$($src.interval)min → $(if($needsRun){'NEEDS RUN'}else{'FRESH'})"
        Write-Host "  $statusLine"

        if (-not $needsRun) { continue }

        if (-not (Test-Path $fullScript)) {
            Write-Log "ERROR" "[$s] Script NOT FOUND: $fullScript — skipping"
            $results += @{ "source" = $s; "status" = "NOT_FOUND"; "reason" = "script missing" }
            continue
        }

        Write-Log "RUN" "[$s] Executing: $($src.script) (timeout=$($src.timeout)s)"

        # ---- Execute with timeout via PowerShell job ----
        $job = $null
        $scriptBlock = {
            param($ScriptPath)
            try {
                & $ScriptPath
                $ec = $LASTEXITCODE
                if ($ec -and $ec -ne 0) {
                    return "EXIT_CODE=$ec"
                }
                return "OK"
            } catch {
                return "ERROR=$($_.Exception.Message)"
            }
        }

        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $fullScript
        $completed = $job | Wait-Job -Timeout $src.timeout

        if (-not $completed) {
            # Timeout
            $job | Stop-Job -ErrorAction SilentlyContinue
            $job | Remove-Job -Force -ErrorAction SilentlyContinue
            Write-Log "TIMEOUT" "[$s] Script timed out after $($src.timeout)s — skipped, config NOT updated"
            $results += @{ "source" = $s; "status" = "TIMEOUT"; "reason" = "exceeded $($src.timeout)s" }
            # Do NOT update config timestamp on timeout — allow retry next cycle
            continue
        }

        # Collect result
        try {
            $jobResult = $job | Receive-Job -ErrorAction SilentlyContinue
        } catch {
            $jobResult = "RECEIVE_ERROR=$($_.Exception.Message)"
        }
        $job | Remove-Job -Force -ErrorAction SilentlyContinue

        if ($jobResult -eq "OK") {
            Write-Log "OK" "[$s] Completed successfully"
            $results += @{ "source" = $s; "status" = "OK" }
        } else {
            Write-Log "WARN" "[$s] Script finished with: $jobResult"
            $results += @{ "source" = $s; "status" = "WARN"; "reason" = $jobResult }
        }

        # Update config timestamp (even on WARN — prevents retry spam, but NOT on timeout)
        $config | Add-Member -NotePropertyName $src.key -NotePropertyValue $now.ToString("yyyy-MM-dd HH:mm") -Force
        $anyTriggered = $true
    }

    # ---- Save config ----
    if ($anyTriggered) {
        $config | ConvertTo-Json -Compress | Set-Content $configFile -Encoding UTF8
        Write-Log "INFO" "Config saved to $configFile"
    }

    # ---- Structured summary log ----
    $runSummary = @{
        "ts"       = $now.ToString("yyyy-MM-dd HH:mm:ss")
        "triggered" = $anyTriggered
        "sources"  = $results
    }
    $summaryJson = $runSummary | ConvertTo-Json -Compress
    try { Add-Content -Path $logFile -Value "#SUMMARY $summaryJson" -Encoding UTF8 } catch {}

    Write-Log "INFO" "Collector-master complete (triggered: $anyTriggered, executed: $($results.Count))"

} finally {
    # ---- Release mutex ----
    if ($mutexHeld -and $mutex) {
        try { $mutex.ReleaseMutex() | Out-Null } catch {}
        try { $mutex.Close() } catch {}
        try { $mutex.Dispose() } catch {}
        $mutexHeld = $false
    }
}
