#!/usr/bin/env python3

path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

result = []
i = 0
while i < len(lines):
    line = lines[i]
    # Look for $patterns = @( following a comment about '优先找'
    if '$patterns = @(' in line and i > 0 and '优先找' in lines[i-1]:
        # Keep the comment line and replace the $patterns block
        indent = line[:len(line) - len(line.lstrip())]
        result.append(lines[i-1])  # keep comment
        result.append(indent + '$patterns = @(\n')
        result.append(indent + '    \'(?i:\' + $Symbol + \')[:\\s]*\\$[\d,]+\\.?\\d*\',\n')
        result.append(indent + '    \'(?i)(?:price|cost 最新|当前)[:\\s]*\\$?[\d,]+\\.?\\d*\',\n')
        result.append(indent + '    \'\\$[\d,]+\\.?\\d*\',\n')
        result.append(indent + '    \'(?i)USD[:\\s]*[\d,]+\\.?\\d*\',\n')
        result.append(indent + '    \'[\d,]+\\.?\\d*\\s*(?:USD|美元)\'\n')
        result.append(indent + ')\n')
        i += 7  # skip old comment + $patterns = @( + 5 pattern lines + )
        print('Replaced patterns block at line', i)
        continue
    result.append(line)
    i += 1

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(result)
print('Done')
