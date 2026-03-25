#!/usr/bin/env python3
path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the GOLD section start and end
in_gold = False
gold_start = -1
gold_end = -1
brace_count = 0
for i, line in enumerate(lines):
    if 'if ($Name -eq "GOLD")' in line:
        in_gold = True
        gold_start = i
        brace_count = 0
    if in_gold:
        brace_count += line.count('{') - line.count('}')
        if brace_count == 0 and gold_start < i:
            gold_end = i
            break

print(f'GOLD section: lines {gold_start+1} to {gold_end+1}')

# Build replacement lines
new_gold = []
new_gold.append('    if ($Name -eq "GOLD") {\n')
new_gold.append('        # 策略1: Kitco Live Gold\n')
new_gold.append('        $r = Invoke-SafeFetch -Url "https://www.kitco.com/charts/livegold.html" -Timeout 15\n')
new_gold.append('        if ($r.ok) {\n')
new_gold.append('            if ($r.content -match \'Bid\\s*</div>\\s*<div[^>]*>\\s*<span[^>]*>([\\d,]+\\.?\\d*)</span>\') {\n')
new_gold.append('                $priceStr = $matches[1] -replace \',\', \'\'\n')
new_gold.append('                $price = [double]$priceStr\n')
new_gold.append('                if ($price -gt 500) {\n')
new_gold.append('                    Write-Log "  GOLD Kitco抓取成功: $price" "INFO"\n')
new_gold.append('                    return @{\n')
new_gold.append('                        value = $price; source = "kitco.com"; confidence = "high"\n')
new_gold.append('                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr\n')
new_gold.append('                    }\n')
new_gold.append('                }\n')
new_gold.append('            }\n')
new_gold.append('            if ($r.content -match \'(?<![0-9,])([1-4][0-9]{3}\\.[0-9]{2})(?![0-9,])\') {\n')
new_gold.append('                $price = [double]$matches[1]\n')
new_gold.append('                if ($price -gt 500 -and $price -lt 10000) {\n')
new_gold.append('                    Write-Log "  GOLD Kitco备用正则成功: $price" "INFO"\n')
new_gold.append('                    return @{\n')
new_gold.append('                        value = $price; source = "kitco.com"; confidence = "high"\n')
new_gold.append('                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr\n')
new_gold.append('                    }\n')
new_gold.append('                }\n')
new_gold.append('            }\n')
new_gold.append('        }\n')
new_gold.append('        Write-Log "  GOLD Kitco解析失败，尝试goldprice.org..." "WARN"\n')
new_gold.append('        # 策略2: goldprice.org\n')
new_gold.append('        $r2 = Invoke-SafeFetch -Url "https://goldprice.org/gold-price-hong-kong.html" -Timeout 15\n')
new_gold.append('        if ($r2.ok) {\n')
new_gold.append('            if ($r2.content -match \'Spot Gold Price:\\s*USD\\s*([0-9,]+\\.?[0-9]*)\') {\n')
new_gold.append('                $priceStr = $matches[1] -replace \',\', \'\'\n')
new_gold.append('                $price = [double]$priceStr\n')
new_gold.append('                if ($price -gt 500) {\n')
new_gold.append('                    Write-Log "  GOLD goldprice.org抓取成功: $price" "INFO"\n')
new_gold.append('                    return @{\n')
new_gold.append('                        value = $price; source = "goldprice.org"; confidence = "high"\n')
new_gold.append('                        unit = "USD/oz"; raw_len = $r2.len; timestamp = $DateStr\n')
new_gold.append('                    }\n')
new_gold.append('                }\n')
new_gold.append('            }\n')
new_gold.append('        }\n')
new_gold.append('        Write-Log "  GOLD 所有专业网站失败，降级到Bing..." "WARN"\n')
new_gold.append('    }\n')

result = lines[:gold_start] + new_gold + lines[gold_end+1:]
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(result)
print('Done - replaced', gold_end - gold_start + 1, 'lines with', len(new_gold), 'lines')
