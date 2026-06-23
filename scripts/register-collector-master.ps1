#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Register collector-master.ps1 as a scheduled task (30min interval, SYSTEM account)
.DESCRIPTION
    Creates and registers the CollectorMaster_30min scheduled task that runs
    collector-master.ps1 every 30 minutes with repetition for 365 days.
    
    Run as Administrator.
    Created: 2026-06-24 (Subagent G-109)
#>
#Requires -Version 5.1 -RunAsAdministrator

$taskName = "CollectorMaster_30min"
$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$scriptPath = "$workspace\scripts\collector-master.ps1"
$pwsh = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

Write-Host "=== Register CollectorMaster as Scheduled Task ===" -ForegroundColor Cyan
Write-Host "Task Name:  $taskName"
Write-Host "Script:     $scriptPath"
Write-Host "Interval:   30min"
Write-Host "Account:    SYSTEM"
Write-Host ""

# Check if script exists
if (!(Test-Path $scriptPath)) {
    Write-Error "Script not found: $scriptPath"
    exit 1
}

# Remove existing task if any
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing task '$taskName'..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create action
$action = New-ScheduledTaskAction -Execute $pwsh `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

# Create trigger: every 30 minutes starting now, repeat for 365 days
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration (New-TimeSpan -Days 365)

# Create principal (SYSTEM account, highest level)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest

# Create settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

# Register
Register-ScheduledTask -TaskName $taskName `
    -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings `
    -Description "v2 Phase1: Unified collector scheduler (F&G + HN) - 30min loop"

# Verify
$result = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($result) {
    $info = $result | Get-ScheduledTaskInfo
    Write-Host ""
    Write-Host "✅ Task '$taskName' registered successfully!" -ForegroundColor Green
    Write-Host "  State:       $($result.State)"
    Write-Host "  Next Run:    $($info.NextRunTime)"
    Write-Host "  Last Result: $($info.LastTaskResult)"
    Write-Host ""
    Write-Host "Manual test:"
    Write-Host "  Start-ScheduledTask -TaskName '$taskName'"
} else {
    Write-Error "❌ Task registration failed"
    exit 1
}
