# cron-watchdog-v3-wrapper.ps1
# G-56D 11:45 根因 B 修复
# 根因: 之前的 powershell.exe 进程 (在 SYSTEM 上下文) 被 kill 时未释放 Mutex,
#       留下 abandoned 状态, 导致 Task Scheduler 下一轮触发时 ID=203 失败 with 0x800710E0.
# 修复: wrapper 先检查 + 清理 abandoned mutex, 再 exec 真正的 v3 脚本
#
# 注意: 此 wrapper 必须在 powershell.exe 直接调用, 不嵌套 start-process
param(
    [switch]$Help
)

$ErrorActionPreference = "Continue"
$Workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$MutexName = "Local\GidaCronWatchdogV3_30min_Mutex"
$InnerScript = Join-Path $Workspace "scripts\cron-watchdog-v3-30min.ps1"
$LogFile = Join-Path $Workspace "data\system\cron-watchdog-v3-wrapper.log"

function Log-Evt($level, $event, $detail = "") {
    $entry = @{
        ts = (Get-Date -Format "o")
        pid = $PID
        level = $level
        event = $event
        detail = $detail
    } | ConvertTo-Json -Compress
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
    $color = switch ($level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "INFO"  { "Cyan" }
        "OK"    { "Green" }
        default { "White" }
    }
    Write-Host "[$($entry.ts)] $level $event : $detail" -ForegroundColor $color
}

if ($Help) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

# 步骤 1: 检查 mutex 是否在 abandoned 状态 (持有的进程已死)
# 1a) 尝试 OpenExisting
$mutex = $null
$existingOk = $false
try {
    $mutex = [System.Threading.Mutex]::OpenExisting($MutexName)
    $existingOk = $true
    Log-Evt "INFO" "mutex-exists" "Mutex is held (existing)"
} catch [System.Threading.WaitHandleCannotBeOpenedException] {
    Log-Evt "OK" "mutex-free" "No mutex present, clean start"
} catch {
    Log-Evt "WARN" "open-failed" "OpenExisting: $_"
}

# 1b) 如果 mutex 存在, 检查持有它的进程是否还活着
if ($existingOk) {
    $deadPid = $null
    try {
        # PowerShell 5.1 没有直接的 Mutex owner 查询, 用 sysinternals handle.exe 或 psapi
        # 退而求其次: 列出 powershell 进程, 看是否有相同脚本在跑
        $procs = Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
            $_.Id -ne $PID
        }
        $scriptName = Split-Path $InnerScript -Leaf
        $sameScript = $procs | Where-Object {
            ($_.MainWindowTitle -match 'v3-30min') -or
            ($_.StartTime -gt (Get-Date).AddMinutes(-30))
        }
        if (-not $sameScript) {
            Log-Evt "WARN" "orphan-detected" "Mutex held but no live v3 process found - LIKELY ABANDONED"
            $deadPid = "unknown"
        } else {
            Log-Evt "INFO" "alive-detected" "Mutex held by active process(es): $($sameScript.Id -join ',')"
        }
    } catch {
        Log-Evt "WARN" "proc-check-failed" $_.Exception.Message
    }

    # 1c) 释放 abandoned mutex: 用 job-bounded try WaitOne 兜底
    if ($deadPid) {
        Log-Evt "WARN" "recovering" "Attempting to recover abandoned mutex via WaitOne(1000, false)..."
        $recovered = $false
        $job = Start-Job -ScriptBlock {
            param($name)
            try {
                $m = New-Object System.Threading.Mutex($false, $name)
                if ($m.WaitOne(1000, $false)) {
                    try { $m.ReleaseMutex() | Out-Null } catch {}
                    $m.Dispose()
                    return $true
                }
                $m.Dispose()
                return $false
            } catch { return $false }
        } -ArgumentList $MutexName -ErrorAction SilentlyContinue

        if ($job -and (Wait-Job $job -Timeout 5)) {
            $recovered = Receive-Job $job
            Remove-Job $job -Force
            if ($recovered) {
                Log-Evt "OK" "recovered" "Abandoned mutex successfully acquired and released"
            } else {
                Log-Evt "WARN" "recover-failed" "WaitOne returned false even after 1s"
            }
        } else {
            Log-Evt "WARN" "recover-timeout" "Job timed out after 5s"
            if ($job) { Remove-Job $job -Force }
        }
    }
    if ($mutex) { try { $mutex.Dispose() } catch {} }
}

# 步骤 2: 启动真正的 v3 脚本 (wrapper 自己不持有 mutex, 让 v3 内部脚本获取)
# 用 start-process with -Wait 保证子进程被监控
Log-Evt "INFO" "launching" "Starting v3 script: $InnerScript"
$proc = Start-Process powershell -ArgumentList @(
    '-NoProfile'
    '-ExecutionPolicy', 'Bypass'
    '-File', $InnerScript
) -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $Workspace "data\system\v3-stdout.log") -RedirectStandardError (Join-Path $Workspace "data\system\v3-stderr.log") -WorkingDirectory $Workspace -ErrorAction SilentlyContinue

if (-not $proc) {
    Log-Evt "ERROR" "launch-failed" "Start-Process returned null"
    exit 2
}

Log-Evt "INFO" "spawned" "v3 process PID=$($proc.Id)"

# 步骤 3: 监控子进程, 最多等 90s
$timeout = 90
$waited = 0
while (-not $proc.HasExited -and $waited -lt $timeout) {
    Start-Sleep -Seconds 1
    $waited++
    if ($waited % 10 -eq 0) {
        Log-Evt "INFO" "waiting" "elapsed ${waited}s"
    }
}

if (-not $proc.HasExited) {
    Log-Evt "ERROR" "timeout" "v3 process did not exit within ${timeout}s, KILLING PID $($proc.Id)"
    try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    exit 3
}

$exitCode = $proc.ExitCode
Log-Evt "OK" "completed" "v3 exited with code $exitCode after ${waited}s"
exit $exitCode
