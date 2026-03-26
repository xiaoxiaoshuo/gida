# debug-fg-gold.ps1
# 诊断 F&G 和 GOLD 提取问题
$ErrorActionPreference = 'SilentlyContinue'

# F&G 诊断
Write-Host "=== F&G Diagnostic ==="
try {
    $fgPage = Invoke-WebRequest 'https://alternative.me/crypto/fear-and-greed-index/' -TimeoutSec 12 -UseBasicParsing
    $content = $fgPage.Content -replace "`r`n", "`n"
    
    Write-Host "Content length: $($content.Length)"
    
    # 找 Now 和 10 附近的内容
    if ($content -match 'Now.{0,100}?(\d+).{0,50}?Yesterday') {
        Write-Host "Match1: $($matches[0])"
        Write-Host "Value: $($matches[1])"
    }
    
    # 简化搜索
    if ($content -match 'Extreme Fear.{0,50}?10') {
        Write-Host "Match2: $($matches[0])"
    }
    
    # 找所有 数字 10 的位置
    $positions = @()
    for ($i = 0; $i -lt $content.Length - 1; $i++) {
        if ($content[$i] -eq '1' -and $content[$i+1] -eq '0') {
            $start = [Math]::Max(0, $i-30)
            $end = [Math]::Min($content.Length, $i+35)
            $positions += $content.Substring($start, $end).Replace("`n", " ")
        }
    }
    Write-Host "Positions of '10':"
    $positions | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" }
} catch {
    Write-Host "F&G Error: $($_.Exception.Message)"
}

# GOLD 诊断
Write-Host "`n=== GOLD Diagnostic ==="
try {
    $goldPage = Invoke-WebRequest 'https://goldprice.org/' -TimeoutSec 12 -UseBasicParsing
    $gContent = $goldPage.Content -replace "`r`n", " "
    
    # 找所有>4000的数字并显示周围上下文
    $allMatches = [regex]::Matches($gContent, '\d{4,5}(?:\.\d+)?')
    $validNums = $allMatches | Where-Object { $_.Value -replace ',', '' -match '^\d{4,5}$' } | Select-Object -First 5
    foreach ($m in $validNums) {
        $start = [Math]::Max(0, $m.Index-20)
        $end = [Math]::Min($gContent.Length, $m.Index+30)
        Write-Host "Found $($m.Value): ...$($gContent.Substring($start,$end-$start))..."
    }
} catch {
    Write-Host "GOLD Error: $($_.Exception.Message)"
}
