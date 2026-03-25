# -*- coding: utf-8 -*-
"""Fix $? in Extract-PriceValue patterns - use HERE-string to avoid $ expansion."""

path = r'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find the Extract-PriceValue function
import re
m = re.search(r'(function Extract-PriceValue \{.*?\n\})', content, re.DOTALL)
if not m:
    print("Function not found!")
    exit(1)

func = m.group(1)
print("Found function, checking...")
print(func[:200])

# The patterns array - check if it uses double-quoted strings with \$?
# We want to use @'...'@ (here-string) or replace \$? with \$ 
# The safest fix: replace the whole patterns section with single-quoted version

# Let's just find the specific problematic line and replace it
old_dollar_q = '\\$?[\d,]+\\.?\\d*'
if old_dollar_q in func:
    print("Found \\$? pattern - will escape properly")
    # In PowerShell single-quoted strings, \ is literal, so \$ is literal \$
    # But we want $ to be literal $, so in single quotes, just use '$'
    # Replace the whole pattern line
    old_line = '        "(?:price|cost 最新|当前)[:\\\\s]*\\\\$?[\\\\d,]+\\\\.?\\\\d*",'
    new_line = "        '(?:price|cost 最新|当前)[:\\s]*\\$?[\\d,]+\\.?\\d*',"
    if old_line in content:
        content = content.replace(old_line, new_line)
        print("Fixed double-quoted pattern -> single-quoted")
    else:
        print("Exact line not found, trying to find and fix...")
        # Find the patterns section and replace it entirely
        old_block = '''$patterns = @(
        "(?:$Symbol)[:\\s]*\\$[\d,]+\\.?\\d*",
        "(?:price|cost 最新|当前)[:\\s]*\\$?[\d,]+\\.?\\d*",
        "\\$[\d,]+\\.?\\d*",
        "USD[:\\s]*[\d,]+\\.?\\d*",
        "[\\d,]+\\.?\\d*\\s*(?:USD|美元)"
    )'''
        new_block = '''$patterns = @(
        '(?:$Symbol)[:\\s]*\\$[\d,]+\\.?\\d*',
        '(?:price|cost 最新|当前)[:\\s]*\\$?[\d,]+\\.?\\d*',
        '\\$[\d,]+\\.?\\d*',
        'USD[:\\s]*[\d,]+\\.?\\d*',
        '[\\d,]+\\.?\\d*\\s*(?:USD|美元)'
    )'''
        if old_block in content:
            content = content.replace(old_block, new_block)
            print("Fixed entire patterns block to single quotes")
        else:
            print("Block not found either - trying line by line")
            # Find and replace each line
            lines = content.split('\n')
            new_lines = []
            for line in lines:
                if 'price|cost 最新|当前' in line and '\\$?' in line:
                    line = "        '(?:price|cost 最新|当前)[:\\s]*\\$?[\\d,]+\\.?\\d*',"
                    print("Fixed:", line)
                new_lines.append(line)
            content = '\n'.join(new_lines)
else:
    print("Pattern \\$? not found in function - checking what's there...")
    print("Function snippet:", func[func.find('patterns'):func.find('patterns')+300])

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done!")
