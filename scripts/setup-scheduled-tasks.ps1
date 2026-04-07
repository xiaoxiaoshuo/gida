# setup-scheduled-tasks.ps1 - 创建每日/每小时定时采集任务
# 用途: 一键注册 Windows Task Scheduler 定时任务
# ============================================================

param(
    [switch]$Remove,  # 删除已注册的任务
    [switch]$DryRun   # 只显示将要执行的操作，不实际注册
)

$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"

function Write-Host {
    param([string]$Message, [string]$Level = "INFO")
    $colors = @{ INFO = "Cyan"; WARN = "Yellow"; ERROR = "Red"; SUCCESS = "Green" }
    $color = $colors[$Level]
    Microsoft.PowerShell.Utility\Write-Host "[$Level] $Message" -ForegroundColor $color
}

$tasks = @(
    @{
        Name = "HourlyPriceCollector"
        Description = "每小时采集BTC/ETH/SOL/黄金/原油价格快照"
        Script = "$RepoRoot\scripts\hourly-price-collector.ps1"
        Trigger = $null  # 特殊处理: 重复间隔
    },
    @{
        Name = "DailyCollector_AM"
        Description = "每日08:00采集宏观数据+AI新闻+GitHub Trending"
        Script = "$RepoRoot\scripts\daily-collector.ps1"
        Trigger = "08:00"
    },
    @{
        Name = "DailyCollector_PM"
        Description = "每日20:00采集宏观数据+AI新闻+GitHub Trending"
        Script = "$RepoRoot\scripts\daily-collector.ps1"
        Trigger = "20:00"
    }
)

if ($Remove) {
    Write-Host "========== 删除定时任务 ==========" -Level INFO
    foreach ($task in $tasks) {
        $existing = Get-ScheduledTask -TaskName $task.Name -ErrorAction SilentlyContinue
        if ($existing) {
            if ($DryRun) {
                Write-Host "[DRYRUN] 将删除任务: $($task.Name)" -Level WARN
            } else {
                Unregister-ScheduledTask -TaskName $task.Name -Confirm:$false
                Write-Host "已删除: $($task.Name)" -Level SUCCESS
            }
        } else {
            Write-Host "任务不存在，跳过: $($task.Name)" -Level WARN
        }
    }
    Write-Host "========== 完成 ==========" -Level INFO
    exit 0
}

Write-Host "========== 注册定时任务 ==========" -Level INFO

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "警告: 建议以管理员身份运行以确保任务注册成功" -Level WARN
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"`$Script`""
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

# --- 每小时任务 ---
$hourlyTask = $tasks[0]
Write-Host "处理: $($hourlyTask.Name)..." -Level INFO
if ($DryRun) {
    Write-Host "[DRYRUN] 将创建每小时任务: $($hourlyTask.Name)" -Level INFO
} else {
    $existing = Get-ScheduledTask -TaskName $hourlyTask.Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  任务已存在，先删除..." -Level WARN
        Unregister-ScheduledTask -TaskName $hourlyTask.Name -Confirm:$false
    }
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($hourlyTask.Script)`""
    # 每小时 :05 执行
    $trigger = New-ScheduledTaskTrigger -Once -At "05:00" -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration ([TimeSpan]::MaxValue)
    Register-ScheduledTask -TaskName $hourlyTask.Name -Action $action -Trigger $trigger -Settings $settings -Description $hourlyTask.Description | Out-Null
    Write-Host "  已注册每小时任务: $($hourlyTask.Name) (每小时的05分执行)" -Level SUCCESS
}

# --- 每日任务 (AM + PM) ---
foreach ($t in @($tasks[1], $tasks[2])) {
    Write-Host "处理: $($t.Name)..." -Level INFO
    if ($DryRun) {
        Write-Host "[DRYRUN] 将创建每日任务: $($t.Name) at $($t.Trigger)" -Level INFO
        continue
    }
    $existing = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  任务已存在，先删除..." -Level WARN
        Unregister-ScheduledTask -TaskName $t.Name -Confirm:$false
    }
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($t.Script)`""
    $trigger = New-ScheduledTaskTrigger -Daily -At $t.Trigger
    Register-ScheduledTask -TaskName $t.Name -Action $action -Trigger $trigger -Settings $settings -Description $t.Description | Out-Null
    Write-Host "  已注册每日任务: $($t.Name) (每日 $($t.Trigger))" -Level SUCCESS
}

Write-Host ""
Write-Host "========== 验证注册结果 ==========" -Level INFO
Get-ScheduledTask | Where-Object { $_.TaskName -like "*Collector*" } | ForEach-Object {
    $info = Get-ScheduledTaskInfo -TaskName $_.TaskName
    Write-Host "  [$($_.TaskName)] State=$($_.State) NextRun=$($info.NextRunTime)" -Level INFO
}

Write-Host ""
Write-Host "========== 完成 ==========" -Level INFO
Write-Host "查看任务: Get-ScheduledTask | Where-Object { `$_.TaskName -like '*Collector*' }" -Level INFO
Write-Host "手动运行: Start-ScheduledTask -TaskName 'HourlyPriceCollector'" -Level INFO
Write-Host "删除任务: .\scripts\setup-scheduled-tasks.ps1 -Remove" -Level INFO
