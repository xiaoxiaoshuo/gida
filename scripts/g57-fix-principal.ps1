# G-57 Fix Task Scheduler Principal for 3 broken tasks
# 修复 3 个派单方相关 cron: BridgeCollector2h, FomcD7Tracker, AINewsCollector_0400
# 根因: Principal = Interactive/Administrator/Limited → 改为 ServiceAccount/SYSTEM/Highest
# 派单方授权: G-57 子智能体, 2026-06-05 12:12 GMT+8

$ErrorActionPreference = "Stop"
$Workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$BackupDir = Join-Path $Workspace "data\system\cron-principal-backup-2026-06-05-12-12"
$LogFile = Join-Path $Workspace "data\system\g57-fix-principal.log"

# 创建备份目录
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

function Log($level, $msg) {
    $entry = "[{0}] {1} - {2}" -f (Get-Date -Format "HH:mm:ss"), $level, $msg
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
}

Log "START" "G-57 TaskScheduler Principal Fix Begin"

$tasks = @('BridgeCollector2h','FomcD7Tracker','AINewsCollector_0400')

foreach ($name in $tasks) {
    Log "STEP" "===== Processing $name ====="
    
    $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($null -eq $t) {
        Log "ERROR" "$name not found, skipping"
        continue
    }
    
    # 1) 备份当前状态
    $backupXml = Join-Path $BackupDir "$name.xml"
    Export-ScheduledTask -TaskName $name -TaskPath "\" | Out-File $backupXml -Encoding UTF8
    Log "BACKUP" "XML saved to $backupXml"
    
    # 2) 解析 XML, 改 Principal
    [xml]$xml = Get-Content $backupXml -Raw
    $ns = New-Object System.Xml.XmlNamespaceManager $xml.NameTable
    $ns.AddNamespace("t", "http://schemas.microsoft.com/windows/2004/02/mit/task")
    
    $principals = $xml.GetElementsByTagName("Principal")
    if ($principals.Count -eq 0) {
        Log "ERROR" "$name has no Principal element, cannot patch"
        continue
    }
    $p = $principals[0]
    
    # 记录改前
    $beforeLogonType = $p.LogonType
    $beforeUserId = $p.UserId
    $beforeRunLevel = $p.RunLevel
    
    # 改后 (XML 元素上 LogonType/UserId/RunLevel 是 attribute, 不是子节点)
    $p.SetAttribute("LogonType", "ServiceAccount")
    $p.SetAttribute("UserId", "SYSTEM")
    $p.SetAttribute("RunLevel", "Highest")
    
    # 移除可能存在的 GroupId 节点 (LogonType=Group 才有)
    $groupId = $p.SelectSingleNode("t:GroupId", $ns)
    if ($null -ne $groupId) {
        $p.RemoveChild($groupId) | Out-Null
        Log "CLEAN" "Removed GroupId node"
    }
    
    # 移除可能存在的 DisplayName (避免冲突)
    $displayName = $p.SelectSingleNode("t:DisplayName", $ns)
    if ($null -ne $displayName) {
        $p.RemoveChild($displayName) | Out-Null
        Log "CLEAN" "Removed DisplayName node"
    }
    
    $modifiedXml = $xml.OuterXml
    $modifiedXmlPath = Join-Path $BackupDir "$name.modified.xml"
    $modifiedXml | Out-File $modifiedXmlPath -Encoding UTF8
    Log "MODIFIED" "Patched: $beforeLogonType/$beforeUserId/$beforeRunLevel -> ServiceAccount/SYSTEM/Highest"
    Log "MODIFIED" "Modified XML saved to $modifiedXmlPath"
    
    # 3) 取消注册 + 重新注册
    try {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Log "UNREG" "$name unregistered"
    } catch {
        Log "WARN" "Unregister failed: $_"
    }
    
    try {
        Register-ScheduledTask -TaskName $name -Xml $modifiedXml | Out-Null
        Log "REG" "$name re-registered"
    } catch {
        Log "ERROR" "Re-register failed: $_"
        continue
    }
    
    # 4) 验证
    $verify = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($null -eq $verify) {
        Log "ERROR" "$name verification failed (task not found)"
        continue
    }
    
    $vp = $verify.Principal
    $vlog = "VERIFY {0}: LogonType={1}, UserId={2}, RunLevel={3}" -f $name, $vp.LogonType, $vp.UserId, $vp.RunLevel
    Log "OK" $vlog
    
    if ($vp.LogonType -ne "ServiceAccount" -or $vp.UserId -ne "SYSTEM" -or $vp.RunLevel -ne "Highest") {
        Log "ERROR" "Verification mismatch! Got: $($vp.LogonType)/$($vp.UserId)/$($vp.RunLevel)"
    } else {
        Log "OK" "$name Principal fix confirmed"
    }
}

Log "DONE" "G-57 Principal Fix Complete - 3 tasks processed"
Write-Host ""
Write-Host "===== Triggering 3 tasks =====" -ForegroundColor Cyan
foreach ($name in $tasks) {
    try {
        Start-ScheduledTask -TaskName $name
        Write-Host "  [TRIGGER] $name started" -ForegroundColor Green
        Log "TRIGGER" "$name manually triggered"
    } catch {
        Write-Host "  [TRIGGER FAIL] $name : $_" -ForegroundColor Red
        Log "TRIGGER-FAIL" "$name : $_"
    }
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "===== Waiting 45 sec for tasks to complete =====" -ForegroundColor Cyan
Start-Sleep -Seconds 45

Write-Host ""
Write-Host "===== Post-trigger verification =====" -ForegroundColor Cyan
foreach ($name in $tasks) {
    $info = Get-ScheduledTaskInfo -TaskName $name -ErrorAction SilentlyContinue
    if ($null -eq $info) {
        Write-Host "  $name : NO INFO"
        continue
    }
    Write-Host "  $name : LastRun=$($info.LastRunTime) LastResult=0x$('{0:X8}' -f $info.LastTaskResult) NextRun=$($info.NextRunTime)"
    Log "POST" "$name LastRun=$($info.LastRunTime) LastResult=0x$('{0:X8}' -f $info.LastTaskResult)"
}

Write-Host ""
Write-Host "G-57 fix complete. Log: $LogFile" -ForegroundColor Green
Log "END" "Script finished"
