# G-57 Fix V3 - Use S-1-5-18 (SYSTEM SID) + HighestAvailable + omit LogonType
# (与 AINewsCollector_6h / CronWatchdogV3_30min / HourlyPriceCollector 健康参考一致)
$ErrorActionPreference = "Stop"
$Workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$BackupDir = Join-Path $Workspace "data\system\cron-principal-backup-2026-06-05-12-12"
$LogFile = Join-Path $Workspace "data\system\g57-fix-principal.log"

function Log($level, $msg) {
    $entry = "[{0}] {1} - {2}" -f (Get-Date -Format "HH:mm:ss"), $level, $msg
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
}

Log "START" "===== G-57 V3 Fix Begin (use S-1-5-18 + HighestAvailable, no LogonType) ====="

$tasks = @('BridgeCollector2h','FomcD7Tracker','AINewsCollector_0400')

foreach ($n in $tasks) {
    Log "STEP" "===== $n ====="
    $backupPath = Join-Path $BackupDir "$n.xml"
    if (-not (Test-Path $backupPath)) {
        Log "ERROR" "No backup at $backupPath"
        continue
    }
    
    [xml]$xml = Get-Content $backupPath -Raw
    $ns = New-Object System.Xml.XmlNamespaceManager $xml.NameTable
    $ns.AddNamespace("t", "http://schemas.microsoft.com/windows/2004/02/mit/task")
    $principal = $xml.SelectSingleNode("/t:Task/t:Principals/t:Principal", $ns)
    
    if ($null -eq $principal) {
        Log "ERROR" "$n - no Principal node"
        continue
    }
    
    # === 1. 改 UserId -> S-1-5-18 (SYSTEM SID) ===
    $userId = $principal.SelectSingleNode("t:UserId", $ns)
    $oldUser = if ($userId) { $userId.InnerText } else { "(none)" }
    if ($null -eq $userId) {
        $userId = $xml.CreateElement("UserId", "http://schemas.microsoft.com/windows/2004/02/mit/task")
        $principal.AppendChild($userId) | Out-Null
    }
    $userId.InnerText = "S-1-5-18"
    
    # === 2. 移除 LogonType (默认 S4U, 跟健康参考一致) ===
    $logonType = $principal.SelectSingleNode("t:LogonType", $ns)
    $oldLogon = if ($logonType) { $logonType.InnerText } else { "(none)" }
    if ($null -ne $logonType) {
        $principal.RemoveChild($logonType) | Out-Null
    }
    
    # === 3. 改 RunLevel -> HighestAvailable ===
    $runLevel = $principal.SelectSingleNode("t:RunLevel", $ns)
    $oldRL = if ($runLevel) { $runLevel.InnerText } else { "(none, defaults LeastPrivilege)" }
    if ($null -eq $runLevel) {
        $runLevel = $xml.CreateElement("RunLevel", "http://schemas.microsoft.com/windows/2004/02/mit/task")
        $principal.AppendChild($runLevel) | Out-Null
    }
    $runLevel.InnerText = "HighestAvailable"
    
    # === 4. 移除 GroupId (如果存在) ===
    $groupId = $principal.SelectSingleNode("t:GroupId", $ns)
    if ($null -ne $groupId) {
        $principal.RemoveChild($groupId) | Out-Null
    }
    
    $modifiedXml = $xml.OuterXml
    $modifiedPath = Join-Path $BackupDir "$n.modified.v3.xml"
    $modifiedXml | Out-File $modifiedPath -Encoding UTF8
    
    Log "MOD" "$n - UserId $oldUser -> S-1-5-18"
    Log "MOD" "$n - LogonType $oldLogon -> (removed, default S4U)"
    Log "MOD" "$n - RunLevel $oldRL -> HighestAvailable"
    
    # 取消注册 (如果存在)
    $existing = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        try {
            Unregister-ScheduledTask -TaskName $n -Confirm:$false
            Log "UNREG" "$n - unregistered"
        } catch {
            Log "WARN" "$n - unregister: $_"
        }
    }
    
    # 重新注册
    try {
        Register-ScheduledTask -TaskName $n -Xml $modifiedXml | Out-Null
        Log "REG" "$n - re-registered"
    } catch {
        Log "ERROR" "$n - register failed: $_"
        continue
    }
    
    # 验证
    Start-Sleep -Seconds 1
    $v = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -eq $v) {
        Log "ERROR" "$n - verification failed"
        continue
    }
    $vp = $v.Principal
    $vline = "VERIFY {0}: LogonType={1}, UserId={2}, RunLevel={3}" -f $n, $vp.LogonType, $vp.UserId, $vp.RunLevel
    Log "OK" $vline
}

# 触发 3 个任务
Log "STEP" "===== Triggering 3 tasks ====="
foreach ($n in $tasks) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -eq $t) {
        Log "ERROR" "$n - not registered"
        continue
    }
    try {
        Start-ScheduledTask -TaskName $n
        Log "TRIGGER" "$n - started"
    } catch {
        Log "TRIGGER-FAIL" "$n - $_"
    }
    Start-Sleep -Seconds 2
}

# 等待 50s
Log "WAIT" "Sleeping 50s for tasks..."
Start-Sleep -Seconds 50

# 验证
Log "STEP" "===== Post-trigger verification ====="
foreach ($n in $tasks) {
    $info = Get-ScheduledTaskInfo -TaskName $n -ErrorAction SilentlyContinue
    if ($null -eq $info) {
        Log "NO-INFO" "$n"
        continue
    }
    $line = "POST {0}: LastRun={1}, LastResult=0x{2:X8}, NextRun={3}, Missed={4}" -f $n, $info.LastRunTime, $info.LastTaskResult, $info.NextRunTime, $info.NumberOfMissedRuns
    Log "POST" $line
}

Log "DONE" "G-57 V3 fix complete"
Write-Host ""
Write-Host "DONE - log: $LogFile" -ForegroundColor Green
