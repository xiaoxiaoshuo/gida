# -*- coding: utf-8 -*-
"""Fix PowerShell $? variable expansion in regex patterns."""

import re

path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# The bug: pattern "(?:price|cost 最新|当前)[:\s]*\$?[\d,]+\.?\d*"
# When used in double-quoted string in PowerShell, $? expands to True
# causing the regex to have literal True in it, then \T is an invalid escape.
# 
# Fix: change double-quoted string to single-quoted, OR escape $ as $$
# We'll change the pattern to use 'USD' and a simpler match that doesn't need $?
# 
# The line we want to fix:
old = '        "(?:price|cost 最新|当前)[:\\s]*\\$?[\\d,]+\\.?\\d*",'
new = "        '(?:price|cost 最新|当前)[:\\s]*\\$?[\\d,]+\\.?\\d*',"

print("Old found:", old in content)
content2 = content.replace(old, new)
print("Changed:", old in content, "->", new in content2)

if content2 != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content2)
    print("Written!")
else:
    print("NOT CHANGED - investigating...")
    # Find the Extract-PriceValue function
    m = re.search(r'# ========== 价格提取.+?# ========== API降级', content, re.DOTALL)
    if m:
        print("Function content:")
        print(repr(m.group()))
