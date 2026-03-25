#!/usr/bin/env python3
path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Lines 250-273 (0-indexed: 249-272) need replacement
# Keep lines 248-249 (comment and Invoke-SafeFetch call) and 274 onwards

new_block = []
new_block.append('        if ($r.ok) {\n')
new_block.append('            # Kitco格式: ### 4,523.10 或 Bid 4,523.10\n')
new_block.append('            if ($r.content -match \'Bid\\s*[#\\s]*([1-4][0-9]{3}\\.[0-9]{2})\') {\n')
new_block.append('                $priceStr = $matches[1] -replace \',\', \'\'\n')
new_block.append('                $price = [double]$priceStr\n')
new_block.append('                if ($price -gt 500) {\n')
new_block.append('                    Write-Log "  GOLD Kitco抓取成功: $price" "INFO"\n')
new_block.append('                    return @{\n')
new_block.append('                        value = $price; source = "kitco.com"; confidence = "high"\n')
new_block.append('                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr\n')
new_block.append('                    }\n')
new_block.append('                }\n')
new_block.append('            }\n')
new_block.append('            # 备用: 直接找4位数黄金价格\n')
new_block.append('            if ($r.content -match \'(?<![0-9,])([1-4][0-9]{3}\\.[0-9]{2})(?![0-9,])\') {\n')
new_block.append('                $price = [double]$matches[1]\n')
new_block.append('                if ($price -gt 500 -and $price -lt 10000) {\n')
new_block.append('                    Write-Log "  GOLD Kitco备用正则成功: $price" "INFO"\n')
new_block.append('                    return @{\n')
new_block.append('                        value = $price; source = "kitco.com"; confidence = "high"\n')
new_block.append('                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr\n')
new_block.append('                    }\n')
new_block.append('                }\n')
new_block.append('            }\n')
new_block.append('        }\n')

# Replace lines 250-274 (0-indexed: 249-273) = keep 0-249, new_block, 274+
result = lines[:250] + new_block + lines[274:]
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(result)
print('Done - replaced lines 250-274 with new block')
