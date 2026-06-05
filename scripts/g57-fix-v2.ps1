# G-57 Fix V2 - 修复 Principal 节点 (正确处理 child elements)
$ErrorActionPreference = "Stop"
$Workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$BackupDir = Join-Path $Workspace "data\system\cron-principal-backup-2026-06-05-12-12"
$LogFile = Join-Path $Workspace "data\system\g57-fix-principal.log"

function Log($level, $msg) {
    $entry = "[{0}] {1} - {2}" -f (Get-Date -Format "HH:mm:ss"), $level, $msg
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
}

# 先验证 3 个任务是不是已被删除
Log "CHECK" "===== Pre-state check ====="
$tasks = @('BridgeCollector2h','FomcD7Tracker','AINewsCollector_0400')
foreach ($n in $tasks) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -eq $t) {
        Log "MISSING" "$n - NOT registered (need restore)"
    } else {
        $p = $t.Principal
        Log "EXISTS" "$n - Present, P=[$($p.LogonType)/$($p.UserId)/$($p.RunLevel)]"
    }
}

# Re-register from backup XML, patching Principal child elements
Log "STEP" "===== Re-registering 3 tasks from backup XML ====="
foreach ($n in $tasks) {
    $backupPath = Join-Path $BackupDir "$n.xml"
    if (-not (Test-Path $backupPath)) {
        Log "ERROR" "No backup XML for $n at $backupPath"
        continue
    }
    
    # 重新加载原始备份
    [xml]$xml = Get-Content $backupPath -Raw
    
    # 找 Principal 节点
    $ns = New-Object System.Xml.XmlNamespaceManager $xml.NameTable
    $ns.AddNamespace("t", "http://schemas.microsoft.com/windows/2004/02/mit/task")
    $principal = $xml.SelectSingleNode("/t:Task/t:Principals/t:Principal", $ns)
    if ($null -eq $principal) {
        Log "ERROR" "$n - no Principal node found in backup"
        continue
    }
    
    $logonNode = $principal.SelectSingleNode("t:LogonType", $ns)
    $userIdNode = $principal.SelectSingleNode("t:UserId", $ns)
    $runLevelNode = $principal.SelectSingleNode("t:RunLevel", $ns)
    
    $beforeLogon = if ($logonNode) { $logonNode.InnerText } else { "(none)" }
    $beforeUserId = if ($userIdNode) { $userIdNode.InnerText } else { "(none)" }
    $beforeRunLevel = if ($runLevelNode) { $runLevelNode.InnerText } else { "(none, defaults Limited)" }
    
    # 改写 LogonType 子节点 inner text
    if ($null -eq $logonNode) {
        $logonNode = $xml.CreateElement("LogonType", "http://schemas.microsoft.com/windows/2004/02/mit/task")
        $principal.AppendChild($logonNode) | Out-Null
    }
    $logonNode.InnerText = "ServiceAccount"
    
    # 改写 UserId 子节点 inner text
    if ($null -eq $userIdNode) {
        $userIdNode = $xml.CreateElement("UserId", "http://schemas.microsoft.com/windows/2004/02/mit/task")
        $principal.AppendChild($userIdNode) | Out-Null
    }
    $userIdNode.InnerText = "SYSTEM"
    
    # 改写或添加 RunLevel 子节点
    if ($null -eq $runLevelNode) {
        $runLevelNode = $xml.CreateElement("RunLevel", "http://schemas.microsoft.com/windows/2004/02/mit/task")
        $principal.AppendChild($runLevelNode) | Out-Null
    }
    $runLevelNode.InnerText = "Highest"
    
    # 移除可能存在的 GroupId (LogonType=Group 才有, 但有些旧 XML 残留)
    $groupId = $principal.SelectSingleNode("t:GroupId", $ns)
    if ($null -ne $groupId) {
        $principal.RemoveChild($groupId) | Out-Null
    }
    
    $modifiedXml = $xml.OuterXml
    $modifiedPath = Join-Path $BackupDir "$n.modified.v2.xml"
    $modifiedXml | Out-File $modifiedPath -Encoding UTF8
    
    Log "MOD" "$n - $beforeLogon/$beforeUserId/$beforeRunLevel -> ServiceAccount/SYSTEM/Highest"
    
    # 取消注册 (如果存在) + 重新注册
    $existing = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        try {
            Unregister-ScheduledTask -TaskName $n -Confirm:$false
            Log "UNREG" "$n - unregistered"
        } catch {
            Log "WARN" "$n - unregister warn: $_"
        }
    }
    
    try {
        Register-ScheduledTask -TaskName $n -Xml $modifiedXml | Out-Null
        Log "REG" "$n - re-registered"
    } catch {
        Log "ERROR" "$n - register failed: $_"
        continue
    }
    
    # 验证
    $v = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -eq $v) {
        Log "ERROR" "$n - verification: task not found"
        continue
    }
    $vp = $v.Principal
    $vline = "VERIFY {0}: LogonType={1}, UserId={2}, RunLevel={3}" -f $n, $vp.LogonType, $vp.UserId, $vp.RunLevel
    Log "OK" $vline
    
    if ($vp.LogonType -ne "ServiceAccount" -or $vp.UserId -ne "SYSTEM" -or $vp.RunLevel -ne "Highest") {
        Log "ERROR" "$n - Principal mismatch after fix"
    }
}

# 触发 3 个任务
Log "STEP" "===== Triggering 3 tasks ====="
foreach ($n in $tasks) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -eq $t) {
        Log "ERROR" "$n - cannot trigger, not registered"
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
Log "WAIT" "Sleeping 50s for tasks to complete..."
Start-Sleep -Seconds 50

# 验证
Log "STEP" "===== Post-trigger verification ====="
foreach ($n in $tasks) {
    $info = Get-ScheduledTaskInfo -TaskName $n -ErrorAction SilentlyContinue
    if ($null -eq $info) {
        Log "NO-INFO" "$n - no task info"
        continue
    }
    $line = "POST {0}: LastRun={1}, LastResult=0x{2:X8}, NextRun={3}, Missed={4}" -f $n, $info.LastRunTime, $info.LastTaskResult, $info.NextRunTime, $info.NumberOfMissedRuns
    Log "POST" $line
}

Log "DONE" "G-57 V2 fix script complete"
Write-Host ""
Write-Host "DONE - see log: $LogFile" -ForegroundColor Green
