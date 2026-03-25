#!/usr/bin/env python3

path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

result = []
i = 0
while i < len(lines):
    line = lines[i]
    # Skip the comment about patterns and the old $patterns = @( line
    if '$patterns = @(' in line and i > 0 and '优先找' in lines[i-1]:
        # Skip the old patterns block (5 lines)
        # Write the new block
        indent = line[:len(line) - len(line.lstrip())]
        result.append(indent + '$patterns = @(\n')
        result.append(indent + '    \'(?i:\' + $Symbol + \')[:\\s]*\\$[\d,]+\\.?\\d*\',\n')
        result.append(indent + '    \'(?i)(?:price|cost 最新|当前)[:\\s]*\\$?[\d,]+\\.?\\d*\',\n')
        result.append(indent + '    \'\\$[\d,]+\\.?\\d*\',\n')
        result.append(indent + '    \'(?i)USD[:\\s]*[\d,]+\\.?\\d*\',\n')
        result.append(indent + '    \'[\d,]+\\.?\\d*\\s*(?:USD|美元)\'\n')
        result.append(indent + ')\n')
        # Skip old lines (the $patterns = @( and the 5 pattern lines)
        i += 6  # skip past $patterns = @( and 5 pattern lines
        print('Replaced patterns block')
        continue
    result.append(line)
    i += 1

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(result)
print('Done')
