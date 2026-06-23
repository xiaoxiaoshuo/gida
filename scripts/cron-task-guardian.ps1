<#
.SYNOPSIS
    Gida Cron Task Guardian — 每30min检查所有Gida任务的Enabled状态
.DESCRIPTION
    检测\HourlyPriceCollector, \BridgeCollector2h, \CronWatchdogV3_30min
    等核心任务是否被意外Disable。
    若发现Disabled → 自动Enable并记录日志。
    日志输出到 data/system/task-guardian.log
#>

$LogPath = Join-Path $PSScriptRoot "..\data\system\task-guardian.log"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# 关键任务列表（排除 v1 CronWatchdog 因其与v3冲突）
$CriticalTasks = @(
    "HourlyPriceCollector",
    "BridgeCollector2h",
    "CronWatchdogV3_30min"
)

# 写入日志辅助
function Write-GuardianLog {
    param([string]$Message)
    $Line = "[$Timestamp] $Message"
    Add-Content -Path $LogPath -Value $Line -Encoding UTF8
    Write-Host $Line
}

Write-GuardianLog "=== Guardian 启动 ==="

try {
    # 查询所有任务
    $Tasks = schtasks /Query /FO CSV /V 2>$null | ConvertFrom-Csv

    foreach ($TaskName in $CriticalTasks) {
        $TaskFullPath = "\$TaskName"
        $TaskObj = $Tasks | Where-Object { $_.TaskName -eq $TaskFullPath }

        if (-not $TaskObj) {
            Write-GuardianLog "⚠ 任务 $TaskFullPath 不存在，跳过"
            continue
        }

        $Status = $TaskObj.Status

        if ($Status -eq "Disabled") {
            Write-GuardianLog "❗ 发现 $TaskName 状态=Disabled → 正在启用..."
            try {
                Enable-ScheduledTask -TaskPath "\" -TaskName $TaskName -ErrorAction Stop
                Write-GuardianLog "✅ 已启用 $TaskName"
            }
            catch {
                Write-GuardianLog "❌ 启用 $TaskName 失败: $_"
            }
        }
        elseif ($Status -eq "Ready") {
            Write-GuardianLog "✓ $TaskName 状态=Ready，正常"
        }
        else {
            Write-GuardianLog "? $TaskName 状态=$Status，非预期，请关注"
        }
    }
}
catch {
    Write-GuardianLog "❌ 查询任务时出错: $_"
}

Write-GuardianLog "=== Guardian 完成 ==="
Write-GuardianLog ""
