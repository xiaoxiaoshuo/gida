#!/usr/bin/env pwsh
<#
.SYNOPSIS
    collector-master.ps1 — v2 Unified Collector Scheduler (Phase 1)
.DESCRIPTION
    Simplified master scheduler that checks data freshness for each source
    and triggers collection scripts when data is stale.
    
    Sources managed:
    - fng: Fear & Greed Index (60min interval)
    - hn:  Hacker News Top 30 (60min interval)
    
    Uses config file to track last run times and a mutex to prevent re-entry.
    Designed to be called every 30min via Task Scheduler (System account).
    
    Created: 2026-06-24 (Subagent G-109)
.NOTES
    Version: 0.1 (v2 Phase 1)
    Workspace: C:\Users\Administrator\clawd\agents\workspace-gid
#>
#Requires -Version 5.1

$ErrorActionPreference = "Continue"
$base = "C:\Users\Administrator\clawd\agents\workspace-gid"
$configDir = "$base\system"
$configFile = "$configDir\collector-master-config.json"
$mutexName = "Local\GidaCollectorMaster_Mutex"

# Ensure config dir exists
if (!(Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

# ---- Mutex ----
$mutex = $null
$mutexHeld = $false
try {
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
    if ($mutex.WaitOne(0)) {
        $mutexHeld = $true
    } else {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] collector-master SKIP: another instance holds mutex" -ForegroundColor Yellow
        exit 0
    }
} catch [System.Threading.AbandonedMutexException] {
    $mutexHeld = $true
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] collector-master [mutex recovered from abandoned]" -ForegroundColor Yellow
} catch {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] WARN: mutex init failed: $_ (proceeding without lock)" -ForegroundColor Yellow
    $mutexHeld = $true
}

try {
    # ---- Config ----
    if (Test-Path $configFile) {
        $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        $config = New-Object PSObject
    }

    # ---- Source definitions ----
    $sources = @{
        "fng" = @{
            "script"   = "scripts/collect-fear-greed.ps1"
            "interval" = 60  # minutes
            "key"      = "fng_last"
        }
        "hn" = @{
            "script"   = "scripts/fetch-hn-top30-v2.ps1"
            "interval" = 60  # minutes
            "key"      = "hn_last"
        }
    }

    $now = Get-Date
    $anyTriggered = $false

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] collector-master: checking $($sources.Count) sources..."

    foreach ($s in $sources.Keys) {
        $src = $sources[$s]
        $fullScript = "$base\$($src.script)"

        # Read last run time from config
        $last = if ($config.$($src.key)) {
            try { [DateTime]$config.$($src.key) } catch { [DateTime]"2000-01-01" }
        } else {
            [DateTime]"2000-01-01"
        }

        $ageMinutes = ($now - $last).TotalMinutes
        $needsRun = $ageMinutes -ge $src.interval

        Write-Host "  [$s] last=$($last.ToString('yyyy-MM-dd HH:mm')) age=${ageMinutes:N0}min interval=$($src.interval)min → $(if($needsRun){'NEEDS RUN'}else{'FRESH'})"

        if ($needsRun) {
            if (Test-Path $fullScript) {
                Write-Host "  → Running: $($src.script)..." -ForegroundColor Cyan
                try {
                    & $fullScript
                    $exitCode = $LASTEXITCODE
                    if ($exitCode -and $exitCode -ne 0) {
                        Write-Warning "  → Script exited with code $exitCode"
                    } else {
                        Write-Host "  → Done (exit=$exitCode)" -ForegroundColor Green
                    }
                } catch {
                    Write-Warning "  → Script execution error: $_"
                }

                # Update config timestamp (even if script fails — prevents retry spam)
                $config | Add-Member -NotePropertyName $src.key -NotePropertyValue $now.ToString("yyyy-MM-dd HH:mm") -Force
                $anyTriggered = $true
            } else {
                Write-Warning "  → Script NOT FOUND: $fullScript — skipping (config not updated)"
            }
        }
    }

    # ---- Save config ----
    if ($anyTriggered) {
        $config | ConvertTo-Json -Compress | Set-Content $configFile -Encoding UTF8
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Config saved to $configFile" -ForegroundColor DarkGray
    }

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] collector-master complete (triggered: $anyTriggered)" -ForegroundColor Cyan

} finally {
    # Release mutex
    if ($mutexHeld -and $mutex) {
        try { $mutex.ReleaseMutex() | Out-Null } catch {}
        try { $mutex.Close() } catch {}
        try { $mutex.Dispose() } catch {}
        $mutexHeld = $false
    }
}
