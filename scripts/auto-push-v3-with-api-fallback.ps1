# auto-push-v3-with-api-fallback.ps1 (DRAFT)
# 智能双策略回退推送: git push → REST API → 等待窗口
# Author: gida-intel subagent (2026-06-04 02:25 GFW jitters)
# Status: DRAFT — 待 1-2 周实测后转 v3 正式版
# =========================================================

[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [string]$RemoteUrl = "https://github.com/xiaoxiaoshuo/gida.git",
    [int]$GitPushMaxRetries = 2,
    [int]$GitPushRetryDelay = 15,
    [int]$ApiMaxRetries = 2,
    [int]$ApiRetryDelay = 10,
    [int]$ProbeTimeoutSec = 10,
    [switch]$SkipApiFallback = $false,
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Continue"
$DateStamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$LogFile = "$RepoRoot\memory\$(Get-Date -Format 'yyyy-MM-dd').md"
$RateLimitFile = "$RepoRoot\.last_push_time"
$MinPushIntervalMinutes = 10

# ========== Logging ==========
function Write-Log {
    param([string]$Level, [string]$Msg)
    $ts = Get-Date -Format "HH:mm:ss"
    $entry = "$ts [$Level] $Msg"
    Write-Host $entry
    try {
        Add-Content -Path $LogFile -Value "  - $entry" -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Log-Info  { param($m) Write-Log "INFO"  $m }
function Log-Warn  { param($m) Write-Log "WARN"  $m }
function Log-Error { param($m) Write-Log "ERROR" $m }
function Log-OK    { param($m) Write-Log "OK"    $m }

# ========== Rate limit (push every 10 min) ==========
function Test-PushRateLimit {
    if (Test-Path $RateLimitFile) {
        $last = Get-Content $RateLimitFile -Raw -ErrorAction SilentlyContinue
        if ($last -and $last.Trim()) {
            try {
                $lastTime = [DateTime]::Parse($last.Trim())
                $elapsed = ((Get-Date) - $lastTime).TotalMinutes
                if ($elapsed -lt $MinPushIntervalMinutes) {
                    Log-Info "速率限制：距上次推送 $([math]::Round($elapsed,1)) 分钟 (< ${MinPushIntervalMinutes}m), 跳过"
                    return $false
                }
            } catch {}
        }
    }
    Set-Content -Path $RateLimitFile -Value (Get-Date -Format "yyyy-MM-dd HH:mm") -Force
    return $true
}

# ========== GFW 探测: 三种网络栈 ==========
# 返回 hashtable: @{WinHTTP=ok/fail; OpenSSL=ok/fail; Schannel=ok/fail; Recommendation=...}
function Test-StackConnectivity {
    $r = @{ WinHTTP = "unknown"; OpenSSL = "unknown"; Schannel = "unknown"; Timestamp = (Get-Date -Format "HH:mm:ss") }
    
    # WinHTTP: Invoke-WebRequest (api.github.com)
    try {
        $resp = Invoke-WebRequest -Uri 'https://api.github.com/rate_limit' -UseBasicParsing -TimeoutSec $ProbeTimeoutSec
        $r.WinHTTP = if ($resp.StatusCode -eq 200) { "ok" } else { "fail:$($resp.StatusCode)" }
    } catch {
        $r.WinHTTP = "fail"
    }
    
    # OpenSSL: git ls-remote (主推送栈)
    try {
        $out = git ls-remote --heads $RemoteUrl 2>&1
        if ($LASTEXITCODE -eq 0 -and $out -match "refs/heads/") {
            $r.OpenSSL = "ok"
        } else {
            $r.OpenSSL = "fail:$($LASTEXITCODE)"
        }
    } catch {
        $r.OpenSSL = "fail"
    }
    
    # Schannel: curl.exe
    try {
        $curlOut = & curl.exe -sS -o $null -w "%{http_code}" --max-time $ProbeTimeoutSec https://api.github.com/rate_limit 2>&1
        if ($curlOut -match "^\d{3}$" -and $curlOut.StartsWith("2")) {
            $r.Schannel = "ok"
        } else {
            $r.Schannel = "fail:$curlOut"
        }
    } catch {
        $r.Schannel = "fail"
    }
    
    # 决策
    if ($r.OpenSSL -eq "ok") {
        $r.Recommendation = "git-push"
    } elseif ($r.WinHTTP -eq "ok") {
        $r.Recommendation = "api-fallback"
    } else {
        $r.Recommendation = "wait-window"
    }
    
    return $r
}

# ========== PAT discovery (NO hardcoded fallback) ==========
function Get-Pat {
    $sources = @($env:GITHUB_TOKEN, $env:GH_TOKEN, $env:GIDA_TOKEN)
    foreach ($s in $sources) {
        if ($s -and $s.Trim().Length -gt 10) { return $s.Trim() }
    }
    
    # 尝试 git credential fill (wincred 后端)
    $tmpIn = [System.IO.Path]::GetTempFileName()
    $tmpOut = [System.IO.Path]::GetTempFileName()
    try {
        "protocol=https`nhost=github.com`n" | Set-Content -Path $tmpIn -NoNewline
        $env:GIT_TERMINAL_PROMPT = "0"
        cmd /c "git credential fill < `"$tmpIn`" > `"$tmpOut`" 2>nul"
        $content = Get-Content $tmpOut -Raw -ErrorAction SilentlyContinue
        if ($content -match "(?m)^password=(.+)$") {
            return $matches[1].Trim()
        }
    } finally {
        Remove-Item -Force $tmpIn, $tmpOut -ErrorAction SilentlyContinue
    }
    return $null
}

# ========== API push: PUT /repos/{owner}/{repo}/contents/{path} ==========
# 注意: 这条路径会绕过本地 git 历史, 每次 PUT 在远端生成新 commit.
#       如果本地有未推送 commit, 推荐优先用 git push (data integrity).
function Push-FileViaApi {
    param(
        [string]$Pat,
        [string]$Owner = "xiaoxiaoshuo",
        [string]$Repo = "gida",
        [string]$RelPath,           # 相对路径, e.g. "data/market/prices_latest.json"
        [string]$AbsPath,           # 绝对路径
        [string]$CommitMessage = "chore: API push $DateStamp"
    )
    
    $apiBase = "https://api.github.com"
    $hdr = @{
        "Authorization" = "token $Pat"
        "User-Agent" = "gida-auto-push-v3"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    # 1) GET 当前 SHA (if file exists)
    $getUri = "$apiBase/repos/$Owner/$Repo/contents/$($RelPath -replace '\\','/')"
    $existingSha = $null
    try {
        $getResp = Invoke-WebRequest -Uri $getUri -Headers $hdr -UseBasicParsing -TimeoutSec $ProbeTimeoutSec
        if ($getResp.StatusCode -eq 200) {
            $existing = $getResp.Content | ConvertFrom-Json
            $existingSha = $existing.sha
            Log-Info "  GET existing sha: $($existingSha.Substring(0,12))..."
        } elseif ($getResp.StatusCode -eq 404) {
            Log-Info "  File not on remote, will create"
        }
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        if ($code -ne 404) {
            Log-Warn "  GET failed (status=$code): $($_.Exception.Message)"
        }
    }
    
    # 2) Base64 encode content
    $bytes = [System.IO.File]::ReadAllBytes($AbsPath)
    $b64 = [Convert]::ToBase64String($bytes)
    
    # 3) PUT
    $body = @{
        message = "$CommitMessage (file: $RelPath)"
        content = $b64
        branch = "main"
    }
    if ($existingSha) { $body.sha = $existingSha }
    
    $bodyJson = $body | ConvertTo-Json -Depth 5
    
    for ($i = 1; $i -le $ApiMaxRetries; $i++) {
        try {
            $putResp = Invoke-WebRequest -Uri $getUri -Method Put -Headers $hdr -Body $bodyJson -UseBasicParsing -TimeoutSec $ProbeTimeoutSec -ContentType "application/json"
            if ($putResp.StatusCode -in 200, 201) {
                $respContent = $putResp.Content | ConvertFrom-Json
                Log-OK "  PUT OK: $($respContent.commit.sha.Substring(0,12)) (file: $RelPath)"
                return $true
            } else {
                Log-Warn "  PUT unexpected status: $($putResp.StatusCode)"
            }
        } catch {
            Log-Warn "  PUT attempt $i failed: $($_.Exception.Message)"
        }
        if ($i -lt $ApiMaxRetries) { Start-Sleep -Seconds $ApiRetryDelay }
    }
    return $false
}

# ========== 列出待推送文件 (含未跟踪) ==========
function Get-PendingFiles {
    Set-Location $RepoRoot
    $statusOut = git status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) { return @() }
    
    $files = @()
    foreach ($line in $statusOut) {
        if ($line -match '^\s*([AM?!\.]{1,2})\s+(.+)$') {
            $files += [PSCustomObject]@{
                Status = $matches[1].Trim()
                Path = $matches[2].Trim()
            }
        }
    }
    return $files
}

# ========== 推送策略 A: git push (with retry) ==========
function Invoke-GitPush {
    Set-Location $RepoRoot
    for ($i = 1; $i -le $GitPushMaxRetries; $i++) {
        Log-Info "git push 尝试 $i/$GitPushMaxRetries..."
        $pushOut = git push origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log-OK "git push 成功"
            return $true
        }
        # 区分: push protection (可修复) vs 网络失败 (回退)
        if ($pushOut -match "GH013|Push cannot contain secrets|repository rule violations") {
            Log-Error "git push 被 Push Protection 拦截: $($pushOut -join ' ')"
            Log-Error "需要清理文件中的 secret 后重试, API fallback 也无法绕过"
            return $false
        }
        Log-Warn "git push 失败: $($pushOut -join ' ')"
        if ($i -lt $GitPushMaxRetries) { Start-Sleep -Seconds $GitPushRetryDelay }
    }
    return $false
}

# ========== 推送策略 B: REST API 推送 ==========
function Invoke-ApiPush {
    if ($SkipApiFallback) {
        Log-Info "API fallback 已禁用 (--SkipApiFallback)"
        return $false
    }
    
    $pat = Get-Pat
    if (-not $pat) {
        Log-Warn "无 PAT 可用 (GITHUB_TOKEN/GH_TOKEN/git credential 均为空)"
        return $false
    }
    Log-Info "PAT 已就绪 (长度: $($pat.Length) chars)"
    
    $files = Get-PendingFiles
    if ($files.Count -eq 0) {
        Log-Info "无未提交文件, API push 无需执行"
        return $true
    }
    
    $allOk = $true
    foreach ($f in $files) {
        $abs = Join-Path $RepoRoot $f.Path
        if (-not (Test-Path $abs)) {
            Log-Warn "  跳过 (不存在): $($f.Path)"
            continue
        }
        Log-Info "  Pushing: $($f.Path) [$($f.Status)]"
        $ok = Push-FileViaApi -Pat $pat -RelPath $f.Path -AbsPath $abs
        if (-not $ok) { $allOk = $false }
    }
    
    if ($allOk) {
        Log-OK "API push 全部成功"
    } else {
        Log-Warn "API push 部分失败"
    }
    return $allOk
}

# ========== 推送策略 C: 等待 GFW 窗口 ==========
# 仅记录, 不实际 sleep (cron 会在 9:00/14:00 重试)
function Invoke-WaitWindow {
    Log-Info "策略 C: 等待白天 GFW 窗口 (9:00 / 14:00 cron)"
    $now = Get-Date
    $candidates = @(
        (Get-Date -Hour 9 -Minute 0 -Second 0),
        (Get-Date -Hour 14 -Minute 0 -Second 0)
    ) | Where-Object { $_ -gt $now }
    
    if ($candidates.Count -eq 0) {
        $next = (Get-Date).AddDays(1).Date.AddHours(9)
        Log-Info "  下次窗口: $($next.ToString('yyyy-MM-dd HH:mm')) (明日 09:00)"
    } else {
        Log-Info "  下次窗口: $($candidates[0].ToString('yyyy-MM-dd HH:mm'))"
    }
    Log-Info "  本次跳过, 变更已本地保留"
}

# ========== Main ==========
function Main {
    Set-Location $RepoRoot
    
    Log-Info "=== auto-push-v3 启动 ($DateStamp) ==="
    Log-Info "Repo: $RepoRoot"
    Log-Info "Remote: $RemoteUrl"
    
    # 速率限制
    if (-not (Test-PushRateLimit)) { return }
    
    # 变更检查
    $files = Get-PendingFiles
    if ($files.Count -eq 0) {
        Log-Info "无变更, 退出"
        return
    }
    Log-Info "待推送: $($files.Count) 个文件"
    foreach ($f in $files) {
        Log-Info "  [$($f.Status)] $($f.Path)"
    }
    
    # 探测
    Log-Info "--- GFW 探测 ---"
    $probe = Test-StackConnectivity
    Log-Info "  WinHTTP (PS Invoke-WebRequest): $($probe.WinHTTP)"
    Log-Info "  OpenSSL (git):                 $($probe.OpenSSL)"
    Log-Info "  Schannel (curl):               $($probe.Schannel)"
    Log-Info "  推荐策略:                      $($probe.Recommendation)"
    
    # 提交 (如尚未提交)
    $aheadOfRemote = (git rev-list --count origin/main..HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or $aheadOfRemote -eq 0) {
        # 有未提交文件, 但未 commit
        Log-Info "提交变更..."
        if ($DryRun) {
            Log-Info "  [DRY-RUN] 跳过 git add/commit"
        } else {
            git add -A 2>&1 | Out-Null
            $commitMsg = "chore: 定时更新 $DateStamp"
            git commit -m $commitMsg 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Log-Error "git commit 失败"
                return
            }
            Log-OK "已提交: $commitMsg"
        }
    } else {
        Log-Info "已有 $aheadOfRemote 个未推送 commit"
    }
    
    # 策略执行
    $ok = $false
    if ($probe.Recommendation -eq "git-push") {
        $ok = Invoke-GitPush
        if (-not $ok -and -not $SkipApiFallback) {
            Log-Info "git push 失败, 回退到 API..."
            $ok = Invoke-ApiPush
        }
    } elseif ($probe.Recommendation -eq "api-fallback") {
        Log-Info "OpenSSL 阻断, 直接走 API 路径"
        $ok = Invoke-ApiPush
    } else {
        Log-Info "所有网络栈均失败"
        Invoke-WaitWindow
        return
    }
    
    if ($ok) {
        Log-OK "=== 推送完成 ==="
    } else {
        Log-Error "=== 推送失败, 已尝试所有策略 ==="
        Invoke-WaitWindow
    }
}

# 入口
Main
