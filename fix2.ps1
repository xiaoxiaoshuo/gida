$path = 'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
$content = Get-Content $path -Raw

$old = @"
    # 优先找 "Symbol: `$price" 或 "Symbol price: `$price" 格式
    `$patterns = @(
        "(?:`$Symbol)[:\s]*`$[\d,]+\.?\d*",
        "(?:price|cost 最新|当前)[:\s]*`$?[\d,]+\.?\d*",
        "`$[\d,]+\.?\d*",
        "USD[:\s]*[\d,]+\.?\d*",
        "[\d,]+\.?\d*\s*(?:USD|美元)"
    )
"@

$new = @"
    # 优先找 "Symbol: `$price" 或 "Symbol price: `$price" 格式
    `$symPat = [regex]::Escape(`$Symbol)
    `$patterns = @(
        '(?i:' + `$symPat + ')[:\s]*' + [char]36 + '[\d,]+\.?\d*',
        '(?i)(?:price|cost 最新|当前)[:\s]*' + [char]36 + '?[\d,]+\.?\d*',
        [char]36 + '[\d,]+\.?\d*',
        '(?i)USD[:\s]*[\d,]+\.?\d*',
        '[\d,]+\.?\d*\s*(?:USD|美元)'
    )
"@

if ($content -match [regex]::Escape($old)) {
    $content = $content -replace [regex]::Escape($old), $new
    Set-Content -Path $path -Value $content -NoNewline -Encoding UTF8
    Write-Host "Fixed"
} else {
    Write-Host "NOT found - trying simple replace"
    # Just do a simple string replacement
    $content = $content -replace '\$Symbol', '$symPat'
    # Now replace the patterns line
    $oldPattern = "`"(?:`$Symbol)[:\s]*`$[\d,]+\.?\d*`""
    $newPattern = "'(?i:' + `$symPat + ')[:\s]*' + [char]36 + '[\d,]+\.?\d*'"
    Set-Content -Path $path -Value $content -NoNewline -Encoding UTF8
    Write-Host "Applied simple fix"
}
