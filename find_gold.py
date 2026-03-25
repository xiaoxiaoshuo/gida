#!/usr/bin/env python3
path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the GOLD section start
for i, line in enumerate(lines):
    if 'if ($Name -eq "GOLD")' in line:
        print(f'GOLD starts at line {i+1}')
        # print 30 lines from there
        for j in range(i, min(i+35, len(lines))):
            print(f'{j+1}: {repr(lines[j])}')
        break
