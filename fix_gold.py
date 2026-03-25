#!/usr/bin/env python3
path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Lines 251-274 contain the Kitco GOLD patterns to fix
# Replace lines 251-262 (the ### pattern block)
# Keep lines 263-273 (the Bid.* pattern that might work)

# New version: replace the first if block with combined pattern
new_lines_251_to_273 = []
new_lines_251_to_273.append('            # Kitco提取格式: ### 4,523.10 或 Bid / ### 4,523.10\n')
new_lines_251_to_273.append('            if ($r.content -match \'(?:Bid|Name gold\\s*)[#\\s]*([1-4][0-9]{3}\\.[0-9]{2})\' -or\n')
new_lines_251_to_273.append('                $r.content -match \'^#+\\s*([1-4][0-9]{3}\\.[0-9]{2})\') {\n')
new_lines_251_to_273.append('                $priceStr = $matches[1] -replace \',\', \'\'\n')
new_lines_251_to_273.append('                $price = [double]$priceStr\n')
new_lines_251_to_273.append('                if ($price -gt 500) {\n')
new_lines_251_to_273.append('                    Write-Log "  GOLD Kitco抓取成功: $price" "INFO"\n')
new_lines_251_to_273.append('                    return @{\n')
new_lines_251_to_273.append('                        value = $price; source = "kitco.com"; confidence = "high"\n')
new_lines_251_to_273.append('                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr\n')
new_lines_251_to_273.append('                    }\n')
new_lines_251_to_273.append('                }\n')
new_lines_251_to_273.append('            }\n')
new_lines_251_to_273.append('            # 备用正则：Bid 后面跟4位数价格\n')
new_lines_251_to_273.append('            if ($r.content -match \'Bid\\s*[#\\s]*([1-4][0-9]{3}\\.[0-9]{2})\') {\n')
new_lines_251_to_273.append('                $priceStr = $matches[1] -replace \',\', \'\'\n')
new_lines_251_to_273.append('                $price = [double]$priceStr\n')
new_lines_251_to_273.append('                if ($price -gt 500 -and $price -lt 10000) {\n')
new_lines_251_to_273.append('                    Write-Log "  GOLD Kitco备用正则成功: $price" "INFO"\n')
new_lines_251_to_273.append('                    return @{\n')
new_lines_251_to_273.append('                        value = $price; source = "kitco.com"; confidence = "high"\n')
new_lines_251_to_273.append('                        unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr\n')
new_lines_251_to_273.append('                    }\n')
new_lines_251_to_273.append('                }\n')
new_lines_251_to_273.append('            }\n')

# Replace lines 250-274 (0-indexed: 249-273)
result = lines[:249] + new_lines_251_to_273 + lines[274:]
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(result)
print('Done')
