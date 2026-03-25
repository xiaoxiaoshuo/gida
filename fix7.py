#!/usr/bin/env python3
path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old = '''    if ($Name -eq "GOLD") {
        # 策略1: Kitco Live Gold (HTML含 Bid\\n### 4,523.10)
        $r = Invoke-SafeFetch -Url "https://www.kitco.com/charts/livegold.html" -Timeout 15
        if ($r.ok) {
            if ($r.content -match 'Bid\\s*</div>\\s*<div[^>]*>\\s*<span[^>]*>[\\d,]+</span>\\s*<[^>]*>\\s*([0-9,]+\\.?[0-9]*)') {
                $priceStr = $matches[1] -replace ',', ''
                $price = [double]$priceStr
                if ($price -gt 500) {
                    Write-Log "  GOLD Kitco直接抓取成功: $price" "INFO"
                    return @{
                        value = $price; source = "kitco.com"; confidence = "high"
                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr
                    }
                }
            }
            # 备用正则：Bid\\n### 4,523.10 格式
            if ($r.content -match '(?s)Bid.*?([0-9]{3,4}\\.[0-9]{2})') {
                $priceStr = $matches[1] -replace ',', ''
                $price = [double]$priceStr
                if ($price -gt 500 -and $price -lt 10000) {
                    Write-Log "  GOLD Kitco备用正则成功: $price" "INFO"
                    return @{
                        value = $price; source = "kitco.com"; confidence = "high"
                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr
                    }
                }
            }
        }
        Write-Log "  GOLD Kitco解析失败，尝试goldprice.org..." "WARN"

        # 策略2: goldprice.org JSON API
        $r2 = Invoke-SafeFetch -Url "https://goldprice.org/gold-price-hong-kong.html" -Timeout 15
        if ($r2.ok) {
            if ($r2.content -match 'Spot Gold Price:\\s*USD\\s*([0-9,]+\\.?[0-9]*)') {
                $priceStr = $matches[1] -replace ',', ''
                $price = [double]$priceStr
                if ($price -gt 500) {
                    Write-Log "  GOLD goldprice.org抓取成功: $price" "INFO"
                    return @{
                        value = $price; source = "goldprice.org"; confidence = "high"
                        unit = "USD/oz"; raw_len = $r2.len; timestamp = $DateStr
                    }
                }
            }
        }
        Write-Log "  GOLD 所有专业网站失败，降级到Bing..." "WARN"
    }'''

new = '''    if ($Name -eq "GOLD") {
        # 策略1: Kitco Live Gold (HTML含 Bid ### 4,523.10)
        $r = Invoke-SafeFetch -Url "https://www.kitco.com/charts/livegold.html" -Timeout 15
        if ($r.ok) {
            if ($r.content -match 'Bid\\s*</div>\\s*<div[^>]*>\\s*<span[^>]*>([\\d,]+\\.?\\d*)</span>') {
                $priceStr = $matches[1] -replace ',', ''
                $price = [double]$priceStr
                if ($price -gt 500) {
                    Write-Log "  GOLD Kitco直接抓取成功: $price" "INFO"
                    return @{
                        value = $price; source = "kitco.com"; confidence = "high"
                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr
                    }
                }
            }
            # 备用：直接找4位数千分位数字
            if ($r.content -match '(?<![0-9,])([1-4][0-9]{3}\\.[0-9]{2})(?![0-9,])') {
                $price = [double]$matches[1]
                if ($price -gt 500 -and $price -lt 10000) {
                    Write-Log "  GOLD Kitco备用正则成功: $price" "INFO"
                    return @{
                        value = $price; source = "kitco.com"; confidence = "high"
                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr
                    }
                }
            }
        }
        Write-Log "  GOLD Kitco解析失败，尝试goldprice.org..." "WARN"

        # 策略2: goldprice.org
        $r2 = Invoke-SafeFetch -Url "https://goldprice.org/gold-price-hong-kong.html" -Timeout 15
        if ($r2.ok) {
            if ($r2.content -match 'Spot Gold Price:\\s*USD\\s*([0-9,]+\\.?[0-9]*)') {
                $priceStr = $matches[1] -replace ',', ''
                $price = [double]$priceStr
                if ($price -gt 500) {
                    Write-Log "  GOLD goldprice.org抓取成功: $price" "INFO"
                    return @{
                        value = $price; source = "goldprice.org"; confidence = "high"
                        unit = "USD/oz"; raw_len = $r2.len; timestamp = $DateStr
                    }
                }
            }
        }
        Write-Log "  GOLD 所有专业网站失败，降级到Bing..." "WARN"
    }'''

if old in content:
    content = content.replace(old, new, 1)
    print('SUCCESS: replaced GOLD section')
else:
    print('NOT FOUND - checking with simpler search')
    idx = content.find('Kitco直接抓取成功')
    if idx > 0:
        print('Found at', idx)
        print(repr(content[idx-200:idx+50]))
    else:
        print('Not found at all')
        
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
