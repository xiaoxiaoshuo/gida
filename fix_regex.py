import re
with open('C:/Users/Administrator/clawd/agents/workspace-gid/scripts/collect-prices-simple.ps1', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the problematic patterns
start = content.find('# ========== 价格提取')
end = content.find('# ========== API降级')
func = content[start:end]
print("BEFORE:", repr(func[:300]))
print("---")

# Fix: replace the broken pattern line
# The line with '\$?[\d,]+\.?\d*' pattern is being corrupted
# Simplify to just match dollar amounts
func_fixed = re.sub(
    r'        "\(\?:price\|cost\|最新\|当前\)\[:\\s\]\*\\\?\\\?\[\d,\]\+\\\?\\\?\[\d\.\]\+",',
    '        "(?:price|cost 最新|当前)[:\\s]*[\\d,]+\\.?[\\d]*",',
    func
)
if func_fixed == func:
    print("Pattern not found, trying alternate")
    func_fixed = func.replace(
        '"(?:price|cost 最新|当前)[:\\s]*\\$?[\\d,]+\\.?\\d*"',
        '"(?:price|cost 最新|当前)[:\\s]*[\\d,]+\\.?[\\d]*"'
    )

print("AFTER:", repr(func_fixed[:300]))
content = content[:start] + func_fixed + content[end:]
with open('C:/Users/Administrator/clawd/agents/workspace-gid/scripts/collect-prices-simple.ps1', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
