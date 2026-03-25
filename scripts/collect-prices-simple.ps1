# collect-prices-simple.ps1 - 简化版价格采集 v3
# 直接抓取可解析的文本页面，不依赖HTML解析
# =========================================================

param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\market",
    [switch]$SaveRawHtml
)

$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Web
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$DateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Host "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
}

function Invoke-SimpleFetch {
    # 直接获取网页文本，绕过复杂HTML
    param([string]$Url, [int]$Timeout = 15)
    try {
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
            "Accept-Language" = "en-US,en;q=0.5"
        }
        $response = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
        return @{
            success = $true
            content = $response.Content
            status = $response.StatusCode
        }
    } catch {
        return @{
            success = $false
            error = $_.Exception.Message
            status = 0
        }
    }
}

Write-Log "========== 价格采集开始 =========="
Write-Log "时间: $DateStr"

$result = @{
    timestamp = $DateStr
    btc = $null
    eth = $null
    sol = $null
    vix = $null
    gold = $null
    oil = $null
}

# 策略1: 尝试直连API（CoinGecko等）
$apis = @{
    "BTC" = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"
    "ETH" = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"
    "SOL" = "https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd"
}

foreach ($symbol in $apis.Keys) {
    Write-Log "尝试API: $($apis[$symbol])..."
    $r = Invoke-SimpleFetch -Url $apis[$symbol] -Timeout 10
    if ($r.success -and $r.status -eq 200) {
        try {
            $json = $r.content | ConvertFrom-Json
            $price = $null
            if ($symbol -eq "BTC" -and $json.bitcoin) { $price = $json.bitcoin.usd }
            elseif ($symbol -eq "ETH" -and $json.ethereum) { $price = $json.ethereum.usd }
            elseif ($symbol -eq "SOL" -and $json.solana) { $price = $json.solana.usd }
            if ($price) {
                $result.$symbol = @{ price = $price; source = "coingecko_api" }
                Write-Log "$symbol = \$$price [API]" "OK"
            }
        } catch {
            Write-Log "JSON解析失败: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "$symbol API失败: $($r.error)" "ERROR"
    }
}

# 策略2: Bing搜索作为备选（保存原始文本供AI解析）
if (-not $result.btc) {
    Write-Log "备选: Bing搜索..."
    $queries = @{
        "BTC" = "Bitcoin BTC price USD today site:coinmarketcap.com OR site:coingecko.com"
        "ETH" = "Ethereum ETH price USD today site:coinmarketcap.com OR site:coingecko.com"
        "SOL" = "Solana SOL price USD today site:coinmarketcap.com OR site:coingecko.com"
    }
    
    $allText = @()
    foreach ($symbol in $queries.Keys) {
        if (-not $result.$symbol) {
            $encoded = [System.Web.HttpUtility]::UrlEncode($queries[$symbol])
            $url = "https://cn.bing.com/search?q=$encoded"
            $r = Invoke-SimpleFetch -Url $url
            if ($r.success) {
                # 保存原始文本
                $rawFile = "$OutputDir\raw_search_${symbol}_$Timestamp.txt"
                $r.content | Out-File -FilePath $rawFile -Encoding UTF8
                $allText += $r.content
                Write-Log "$symbol 搜索结果已保存: $rawFile" "OK"
            }
        }
    }
    
    # 合并保存，一次解析
    if ($allText.Count -gt 0) {
        $mergedFile = "$OutputDir\raw_search_all_$Timestamp.txt"
        $allText -join "`n`n" | Out-File -FilePath $mergedFile -Encoding UTF8
        Write-Log "合并文本已保存: $mergedFile"
    }
}

# 保存结果
$jsonFile = "$OutputDir\prices_$Timestamp.json"
$result | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonFile -Encoding UTF8
Write-Log "结果: $jsonFile"

$successCount = @($result.btc, $result.eth, $result.sol, $result.vix, $result.gold, $result.oil) | Where-Object { $_ -ne $null } | Measure-Object | Select-Object -ExpandProperty Count
Write-Log "成功采集: $successCount/6"

exit $(if ($successCount -gt 0) { 0 } else { 1 })
