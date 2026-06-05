# G-57 Fix V4 - Use full powershell.exe path (SYSTEM context can't find "powershell.exe" on PATH)
$ErrorActionPreference = "Stop"
$Workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$BackupDir = Join-Path $Workspace "data\system\cron-principal-backup-2026-06-05-12-12"
$LogFile = Join-Path $Workspace "data\system\g57-fix-principal.log"
$PSFullPath = "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe"

function Log($level, $msg) {
    $entry = "[{0}] {1} - {2}" -f (Get-Date -Format "HH:mm:ss"), $level, $msg
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
}

Log "START" "===== G-57 V4 Fix: full powershell.exe path + ensure Principal correct ====="

$tasks = @('BridgeCollector2h','FomcD7Tracker','AINewsCollector_0400')

foreach ($n in $tasks) {
    Log "STEP" "===== $n ====="
    $backupPath = Join-Path $BackupDir "$n.xml"
    [xml]$xml = Get-Content $backupPath -Raw
    $ns = New-Object System.Xml.XmlNamespaceManager $xml.NameTable
    $ns.AddNamespace("t", "http://schemas.microsoft.com/windows/2004/02/mit/task")
    
    # 1) Principal: UserId=S-1-5-18, RunLevel=HighestAvailable, no LogonType
    $principal = $xml.SelectSingleNode("/t:Task/t:Principals/t:Principal", $ns)
    $userId = $principal.SelectSingleNode("t:UserId", $ns)
    if ($null -eq $userId) {
        $userId = $xml.CreateElement("UserId", "http://schemas.microsoft.com/windows/2004/02/mit/task")
        $principal.AppendChild($userId) | Out-Null
    }
    $userId.InnerText = "S-1-5-18"
    
    $logonType = $principal.SelectSingleNode("t:LogonType", $ns)
    if ($null -ne $logonType) { $principal.RemoveChild($logonType) | Out-Null }
    
    $runLevel = $principal.SelectSingleNode("t:RunLevel", $ns)
    if ($null -eq $runLevel) {
        $runLevel = $xml.CreateElement("RunLevel", "http://schemas.microsoft.com/windows/2004/02/mit/task")
        $principal.AppendChild($runLevel) | Out-Null
    }
    $runLevel.InnerText = "HighestAvailable"
    
    $groupId = $principal.SelectSingleNode("t:GroupId", $ns)
    if ($null -ne $groupId) { $principal.RemoveChild($groupId) | Out-Null }
    
    Log "MOD" "$n - Principal -> UserId=S-1-5-18, RunLevel=HighestAvailable, no LogonType"
    
    # 2) Command: 改 powershell.exe 为全路径
    $cmd = $xml.SelectSingleNode("/t:Task/t:Actions/t:Exec/t:Command", $ns)
    if ($null -ne $cmd) {
        $oldCmd = $cmd.InnerText
        if ($oldCmd -eq "powershell.exe" -or $oldCmd -eq "powershell") {
            $cmd.InnerText = $PSFullPath
            Log "MOD" "$n - Command '$oldCmd' -> '$PSFullPath'"
        } else {
            Log "INFO" "$n - Command unchanged: $oldCmd"
        }
    } else {
        Log "WARN" "$n - no Command node found"
    }
    
    $modifiedXml = $xml.OuterXml
    $modifiedPath = Join-Path $BackupDir "$n.modified.v4.xml"
    $modifiedXml | Out-File $modifiedPath -Encoding UTF8
    
    # Unregister + Re-register
    $existing = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Unregister-ScheduledTask -TaskName $n -Confirm:$false
        Log "UNREG" "$n - unregistered"
    }
    
    Register-ScheduledTask -TaskName $n -Xml $modifiedXml | Out-Null
    Log "REG" "$n - re-registered"
    
    # Verify
    $v = Get-ScheduledTask -TaskName $n
    $vp = $v.Principal
    $va = $v.Actions[0]
    Log "VERIFY" "$n - Principal: [$($vp.LogonType)/$($vp.UserId)/$($vp.RunLevel)]"
    Log "VERIFY" "$n - Action: Command=$($va.Execute), Args=$($va.Arguments)"
}

# Trigger
Log "STEP" "===== Triggering 3 tasks ====="
foreach ($n in $tasks) {
    try {
        Start-ScheduledTask -TaskName $n
        Log "TRIGGER" "$n - started"
    } catch {
        Log "TRIGGER-FAIL" "$n - $_"
    }
    Start-Sleep -Seconds 2
}

Log "WAIT" "Sleeping 60s..."
Start-Sleep -Seconds 60

# Verify results
Log "STEP" "===== Post-trigger verification ====="
foreach ($n in $tasks) {
    $info = Get-ScheduledTaskInfo -TaskName $n
    $line = "POST {0}: LastRun={1}, LastResult=0x{2:X8} ({3}), NextRun={4}" -f $n, $info.LastRunTime, $info.LastTaskResult, $info.LastTaskResult, $info.NextRunTime
    Log "POST" $line
}

Log "DONE" "G-57 V4 fix complete"
Write-Host ""
Write-Host "DONE - log: $LogFile" -ForegroundColor Green
