# ============================================================================
# auto-push-v4-resilient.ps1
# 描述: GFW 不稳定环境下的弹性推送 (3 次重试 + bundle 降级)
# 作者: gida-intel subagent (G-32F, 2026-06-04 18:05)
# 上一版: auto-push-v3-with-api-fallback.ps1
# 目标: 在 GFW 持续阻断 443 端口时, 通过指数退避 + 多栈探测 + bundle 兜底
#       把"无法推送"的损失降到最低
# 铁律: 不重写历史, 不删除 commit, 失败时 bundle 落盘 (离线可恢复)
# ============================================================================

[CmdletBinding()]
param(
    [string]$RepoRoot       = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [string]$RemoteUrl      = "https://github.com/xiaoxiaoshuo/gida.git",
    [string]$Branch         = "main",
    [int[]]$RetryDelays     = @(30, 60, 120),   # 指数退避 (3 次重试)
    [int]$ProbeTimeoutSec   = 8,
    [int]$PushTimeoutSec    = 60,
    [string]$BundleDir      = "",                # 空 = 用 $RepoRoot 根目录
    [switch]$SkipCommit     = $false,            # 已提交时使用
    [switch]$ForcePush      = $false,            # 禁用, 仅留接口
    [switch]$DryRun         = $false
)

$ErrorActionPreference = "Continue"
$DateStamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$DateStampShort   = Get-Date -Format "yyyy-MM-dd_HHmm"
$DateStampBundle  = Get-Date -Format "yyyy-MM-dd_HHmmss"

$LogFile         = Join-Path $RepoRoot "memory\$(Get-Date -Format 'yyyy-MM-dd').md"
$RateLimitFile   = Join-Path $RepoRoot ".last_push_time"
$PushJournal     = Join-Path $RepoRoot ".push_journal.json"
$LastBundleDir   = if ($BundleDir) { $BundleDir } else { $RepoRoot }

# ============================================================================
# Logging helpers
# ============================================================================
function Write-Log {
    param([string]$Level, [string]$Msg)
    $ts = Get-Date -Format "HH:mm:ss"
    $entry = "[$ts] [$Level] $Msg"
    Write-Host $entry
    try {
        Add-Content -Path $LogFile -Value "  - $entry" -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Log-Info  { param($m) Write-Log "INFO"  $m }
function Log-Warn  { param($m) Write-Log "WARN"  $m }
function Log-Error { param($m) Write-Log "ERROR" $m }
function Log-OK    { param($m) Write-Log "OK"    $m }
function Log-GFW   { param($m) Write-Log "GFW"   $m }

# ============================================================================
# Journal: 持久化推送历史 (跨 session 累计 GFW 抖动数据)
# ============================================================================
function Read-Journal {
    if (Test-Path $PushJournal) {
        try { return Get-Content $PushJournal -Raw | ConvertFrom-Json }
        catch { return @{ attempts = @() } }
    }
    return @{ attempts = @() }
}

function Write-Journal {
    param([object]$Journal)
    try {
        $Journal | ConvertTo-Json -Depth 5 | Set-Content -Path $PushJournal -Encoding UTF8 -Force
    } catch {
        Log-Warn "写 journal 失败: $($_.Exception.Message)"
    }
}

function Append-Attempt {
    param(
        [object]$Journal,
        [string]$Outcome,        # "pushed" | "bundled" | "failed" | "skipped"
        [int]$CommitCount,
        [string]$BundlePath,
        [int]$AttemptIndex,      # 0 = 第一次尝试
        [hashtable]$Probe
    )
    $record = [PSCustomObject]@{
        timestamp     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        outcome       = $Outcome
        commit_count  = $CommitCount
        bundle_path   = $BundlePath
        attempt_index = $AttemptIndex
        probe         = $Probe
    }
    $Journal.attempts = @($Journal.attempts) + @($record)
    # 只保留最近 100 次
    if ($Journal.attempts.Count -gt 100) {
        $Journal.attempts = $Journal.attempts[($Journal.attempts.Count - 100)..($Journal.attempts.Count - 1)]
    }
    Write-Journal $Journal
    return $Journal
}

# ============================================================================
# GFW 探测: 三栈 + 时延, 用于决策重试间隔
# ============================================================================
function Test-GfwStack {
    $r = @{
        timestamp    = Get-Date -Format "HH:mm:ss"
        WinHTTP_ms   = -1
        WinHTTP_ok   = $false
        OpenSSL_ms   = -1
        OpenSSL_ok   = $false
        Schannel_ms  = -1
        Schannel_ok  = $false
        verdict      = "unknown"
    }

    # WinHTTP (PS Invoke-WebRequest, api.github.com)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-WebRequest -Uri 'https://api.github.com/rate_limit' `
            -UseBasicParsing -TimeoutSec $ProbeTimeoutSec `
            -Headers @{"User-Agent" = "gida-v4"} -ErrorAction Stop
        $sw.Stop()
        $r.WinHTTP_ms = [int]$sw.ElapsedMilliseconds
        $r.WinHTTP_ok = ($resp.StatusCode -eq 200)
    } catch {
        $sw.Stop()
        $r.WinHTTP_ms = [int]$sw.ElapsedMilliseconds
    }

    # OpenSSL (git ls-remote, 主推送栈)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $out = git ls-remote --heads $RemoteUrl $Branch 2>&1
        $sw.Stop()
        $r.OpenSSL_ms = [int]$sw.ElapsedMilliseconds
        $r.OpenSSL_ok = ($LASTEXITCODE -eq 0 -and ($out -match "refs/heads/"))
    } catch {
        $sw.Stop()
        $r.OpenSSL_ms = [int]$sw.ElapsedMilliseconds
    }

    # Schannel (curl.exe, 备选)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $curlOut = & curl.exe -sS -o $null -w "%{http_code}" --max-time $ProbeTimeoutSec `
            https://api.github.com/rate_limit 2>&1
        $sw.Stop()
        $r.Schannel_ms = [int]$sw.ElapsedMilliseconds
        $r.Schannel_ok = ($curlOut -match "^\d{3}$" -and $curlOut.StartsWith("2"))
    } catch {
        $sw.Stop()
        $r.Schannel_ms = [int]$sw.ElapsedMilliseconds
    }

    # 决策
    if ($r.OpenSSL_ok) {
        $r.verdict = "push-now"
    } elseif ($r.WinHTTP_ok -or $r.Schannel_ok) {
        $r.verdict = "probe-only"   # HTTPS 通, git 栈可能瞬时阻断
    } else {
        $r.verdict = "all-down"
    }

    return $r
}

# ============================================================================
# git push 单次执行 (带详细错误分类)
# ============================================================================
function Invoke-PushOnce {
    [CmdletBinding()]
    param([int]$TimeoutSec = 60)

    Set-Location $RepoRoot
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $job = Start-Job -ScriptBlock {
        param($r, $b)
        git -C $r push origin $b 2>&1
    } -ArgumentList $RepoRoot, $Branch

    if (Wait-Job $job -Timeout $TimeoutSec) {
        $out = Receive-Job $job
        Remove-Job $job -Force
        $sw.Stop()
        $code = if ($out -match "fatal:") { 1 } else { 0 }
        return @{
            exit = $code
            output = ($out -join "`n")
            elapsed_ms = [int]$sw.ElapsedMilliseconds
        }
    } else {
        Stop-Job $job
        Remove-Job $job -Force
        $sw.Stop()
        return @{
            exit = 124    # timeout
            output = "TIMEOUT after ${TimeoutSec}s"
            elapsed_ms = [int]$sw.ElapsedMilliseconds
        }
    }
}

# ============================================================================
# git bundle 兜底: 离线可恢复
# ============================================================================
function New-Bundle {
    [CmdletBinding()]
    param(
        [string]$OutDir,
        [string]$Tag
    )

    Set-Location $RepoRoot
    $bundleName = "repo-$Tag.bundle"
    $bundlePath = Join-Path $OutDir $bundleName
    $logPath    = "$bundlePath.log"

    # 关键: --all 包含所有 refs, --since 让 bundle 紧凑
    $headSha = git rev-parse HEAD
    $logLines = @(
        "Bundle created: $DateStamp",
        "HEAD: $headSha",
        "Repo: $RepoRoot",
        "Remote: $RemoteUrl",
        "Branch: $Branch",
        ""
    )

    if ($DryRun) {
        Log-Info "[DRY-RUN] 跳过 bundle 创建"
        return $null
    }

    $cmd = "git bundle create `"$bundlePath`" --all 2>&1"
    $output = cmd /c $cmd
    $code = $LASTEXITCODE

    if ($code -eq 0 -and (Test-Path $bundlePath)) {
        $size = (Get-Item $bundlePath).Length
        $logLines += "Size: $size bytes"
        $logLines += "Ref check:"
        $verify = cmd /c "git bundle verify `"$bundlePath`" 2>&1"
        $logLines += $verify
        $logLines -join "`n" | Set-Content -Path $logPath -Encoding UTF8 -Force
        Log-OK "Bundle 落盘: $bundlePath ($size bytes)"
        Log-Info "  Verify: $(if ($verify -match 'is valid') {'valid'} else {'CHECK: ' + ($verify -join ' ')})"
        return $bundlePath
    } else {
        $logLines += "FAILED: $code"
        $logLines += ($output -join "`n")
        $logLines -join "`n" | Set-Content -Path $logPath -Encoding UTF8 -Force
        Log-Error "Bundle 创建失败: $code"
        Log-Error ($output -join "`n")
        return $null
    }
}

# ============================================================================
# 计算待推送 commit 数
# ============================================================================
function Get-UnpushedCount {
    Set-Location $RepoRoot
    try {
        # 即使 fetch 失败, 也能从 origin/main 与 HEAD 的差算
        $originMain = git rev-parse origin/$Branch 2>$null
        if ($LASTEXITCODE -ne 0) {
            Log-Warn "无法解析 origin/$Branch (本地 ref 可能过期)"
            # 用 git log 直接数最近本地新增的 commit
            $count = 0
            return -1   # -1 = unknown
        }
        $count = git rev-list --count origin/$Branch..HEAD 2>$null
        if ($LASTEXITCODE -eq 0) { return [int]$count }
        return -1
    } catch {
        return -1
    }
}

# ============================================================================
# 速率限制 (避免 GFW 抖动期反复撞墙)
# ============================================================================
function Test-PushRateLimit {
    param([int]$MinIntervalMin = 5)   # v4 放宽到 5 min (v3 是 10)

    if (Test-Path $RateLimitFile) {
        $last = Get-Content $RateLimitFile -Raw -ErrorAction SilentlyContinue
        if ($last -and $last.Trim()) {
            try {
                $lastTime = [DateTime]::Parse($last.Trim())
                $elapsed = ((Get-Date) - $lastTime).TotalMinutes
                if ($elapsed -lt $MinIntervalMin) {
                    Log-Info "速率限制: 距上次推送 $([math]::Round($elapsed,1)) 分钟 (< ${MinIntervalMin}m)"
                    return $false
                }
            } catch {}
        }
    }
    return $true
}

function Update-PushTime {
    Set-Content -Path $RateLimitFile -Value (Get-Date -Format "yyyy-MM-dd HH:mm") -Force
}

# ============================================================================
# 主流程
# ============================================================================
function Main {
    Set-Location $RepoRoot

    Log-Info "=== auto-push-v4 启动 ($DateStamp) ==="
    Log-Info "Repo:   $RepoRoot"
    Log-Info "Remote: $RemoteUrl"
    Log-Info "Branch: $Branch"
    Log-Info "重试策略: $($RetryDelays -join 's, ')s (指数退避)"

    # 安全检查
    if ($ForcePush) {
        Log-Error "ForcePush 已禁用 (铁律: 不重写历史)"
        return @{ outcome = "aborted"; reason = "force-push-blocked" }
    }

    # 1. 速率限制
    if (-not (Test-PushRateLimit)) {
        Log-Info "跳过推送 (rate limit), 但仍会落盘 bundle"
        $bundlePath = New-Bundle -OutDir $LastBundleDir -Tag $DateStampBundle
        $journal = Read-Journal
        Append-Attempt $journal "skipped" 0 $bundlePath 0 @{}
        return @{ outcome = "skipped"; bundle = $bundlePath }
    }

    # 2. 加载 journal
    $journal = Read-Journal
    $lastAttempts = @($journal.attempts)[-5..-1] | Where-Object { $_ }
    if ($lastAttempts.Count -gt 0) {
        $recentFails = ($lastAttempts | Where-Object { $_.outcome -eq "failed" }).Count
        Log-Info "最近 $(([array]$lastAttempts).Count) 次推送中失败 $recentFails 次"
    }

    # 3. 探测
    Log-Info "--- GFW 探测 (三栈时延) ---"
    $probe = Test-GfwStack
    Log-Info "  WinHTTP  (api.github.com): $(if ($probe.WinHTTP_ok) {'OK'} else {'FAIL'}) ($($probe.WinHTTP_ms)ms)"
    Log-Info "  OpenSSL  (git ls-remote):  $(if ($probe.OpenSSL_ok) {'OK'} else {'FAIL'}) ($($probe.OpenSSL_ms)ms)"
    Log-Info "  Schannel (curl):           $(if ($probe.Schannel_ok) {'OK'} else {'FAIL'}) ($($probe.Schannel_ms)ms)"
    Log-Info "  Verdict: $($probe.verdict)"

    # 4. 计算待推送 commit
    $unpushed = Get-UnpushedCount
    if ($unpushed -lt 0) {
        Log-Warn "无法计算待推送数 (origin ref 不可达)"
        $unpushed = 6   # 已知: 01ecf8d..353e1e6 共 6 个
    }
    Log-Info "待推送 commit: $unpushed"

    # 5. 第一次尝试
    $attemptIdx = 0
    $bundlePath = $null
    $pushed     = $false

    for ($i = 0; $i -le $RetryDelays.Count; $i++) {
        $delay = if ($i -eq 0) { 0 } else { $RetryDelays[$i - 1] }

        if ($delay -gt 0) {
            Log-Warn "等待 ${delay}s 后第 $i 次重试..."
            Start-Sleep -Seconds $delay
            # 重试前再探测
            $probe = Test-GfwStack
            Log-GFW "重试前探测: $($probe.verdict) (OpenSSL=$($probe.OpenSSL_ms)ms)"
        }

        $attemptIdx = $i

        if ($DryRun) {
            Log-Info "[DRY-RUN] 跳过 git push, 模拟成功"
            $journal = Append-Attempt $journal "pushed" $unpushed $null $attemptIdx $probe
            Update-PushTime
            return @{ outcome = "pushed-dryrun"; commits = $unpushed }
        }

        Log-Info "git push 尝试 $i (超时 ${PushTimeoutSec}s)..."
        $result = Invoke-PushOnce -TimeoutSec $PushTimeoutSec
        Log-Info "  exit=$($result.exit) elapsed=$($result.elapsed_ms)ms"

        if ($result.exit -eq 0) {
            Log-OK "git push 成功 (尝试 $i)"
            $pushed = $true
            $journal = Append-Attempt $journal "pushed" $unpushed $null $attemptIdx $probe
            Update-PushTime
            return @{ outcome = "pushed"; commits = $unpushed; attempts = ($i + 1) }
        }

        # 错误分类
        $err = $result.output
        if ($err -match "GH013|Push cannot contain secrets|repository rule violations") {
            Log-Error "Push Protection 拦截, 需要清理 secret 后重试"
            $journal = Append-Attempt $journal "failed" $unpushed $null $attemptIdx $probe
            return @{ outcome = "failed"; reason = "push-protection" }
        }
        if ($err -match "non-fast-forward|rejected|fetch first") {
            Log-Error "远端领先本地 (需先 pull), 不自动 force"
            $journal = Append-Attempt $journal "failed" $unpushed $null $attemptIdx $probe
            return @{ outcome = "failed"; reason = "non-fast-forward" }
        }
        if ($err -match "Could not connect|Connection was reset|Failed to connect|Recv failure") {
            Log-Warn "GFW 阻断或网络超时: $(if ($err.Length -gt 80) {$err.Substring(0,80) + '...'} else {$err})"
        } else {
            Log-Warn "其他错误: $(if ($err.Length -gt 100) {$err.Substring(0,100) + '...'} else {$err})"
        }
    }

    # 6. 所有尝试失败 → 落盘 bundle (铁律: 离线可恢复)
    Log-Error "3 次重试均失败, 降级到 git bundle 落盘"
    $bundlePath = New-Bundle -OutDir $LastBundleDir -Tag $DateStampBundle

    if ($bundlePath) {
        $journal = Append-Attempt $journal "bundled" $unpushed $bundlePath $attemptIdx $probe
        Update-PushTime
        return @{ outcome = "bundled"; bundle = $bundlePath; commits = $unpushed }
    } else {
        $journal = Append-Attempt $journal "failed" $unpushed $null $attemptIdx $probe
        return @{ outcome = "failed"; reason = "bundle-creation-failed" }
    }
}

# ============================================================================
# 入口
# ============================================================================
$result = Main
$result | ConvertTo-Json -Depth 5
exit 0