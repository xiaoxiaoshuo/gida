#!/usr/bin/env python3
path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old = '        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing'
new = '        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing -AllowInsecureRedirect'
if old in content:
    content = content.replace(old, new, 1)
    print('Added AllowInsecureRedirect')
else:
    print('Pattern not found for Invoke-WebRequest')
    
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')
