#!/usr/bin/env python3

path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Simply replace the problematic double-quoted regex lines with single-quoted ones
old = '''        "(?:$Symbol)[:\s]*\\$[\d,]+\\.?\\d*",'''
new = '''        '(?:' + $Symbol + ')[:\s]*\\$[\d,]+\\.?\\d*','''

if old in content:
    content = content.replace(old, new, 1)
    print('Fixed line 1: (?:$Symbol)...')
else:
    print('Line 1 not found')

old2 = '''        "(?:price|cost 最新|当前)[:\s]*\\$?[\d,]+\\.?\\d*",'''
new2 = '''        '(?i)(?:price|cost 最新|当前)[:\s]*\\$?[\d,]+\\.?\\d*','''
if old2 in content:
    content = content.replace(old2, new2, 1)
    print('Fixed line 2: price|cost...')
else:
    print('Line 2 not found')

old3 = '''        "\\$[\d,]+\\.?\\d*",'''
new3 = '''        '\\$[\d,]+\\.?\\d*','''
if old3 in content:
    content = content.replace(old3, new3, 1)
    print('Fixed line 3: \\$...')
else:
    print('Line 3 not found')

old4 = '''        "USD[:\s]*[\d,]+\\.?\\d*",'''
new4 = '''        '(?i)USD[:\s]*[\d,]+\\.?\\d*','''
if old4 in content:
    content = content.replace(old4, new4, 1)
    print('Fixed line 4: USD...')
else:
    print('Line 4 not found')

old5 = '''        "[\d,]+\\.?\\d*\\s*(?:USD|美元)"'''
new5 = '''        '[\d,]+\\.?\\d*\\s*(?:USD|美元)' '''
if old5 in content:
    content = content.replace(old5, new5, 1)
    print('Fixed line 5: [\\d,]...USD')
else:
    print('Line 5 not found')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')
