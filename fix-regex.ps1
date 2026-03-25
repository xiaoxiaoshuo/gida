$path = 'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1'
$content = Get-Content $path -Raw
# Fix the regex patterns by replacing with single-quoted strings
$old = @'
    $patterns = @(
        "(?:$Symbol)[:\s]*\$[\d,]+\.?\d*",
        "(?:price|cost 最新|当前)[:\s]*\$?[\d,]+\.?\d*",
        "\$[\d,]+\.?\d*",
        "USD[:\s]*[\d,]+\.?\d*",
        "[\d,]+\.?\d*\s*(?:USD|美元)"
    )
'@
$new = @'
    $patterns = @(
        '(?i:' + $Symbol + ')[:\s]*' + '$' + '[\d,]+\.?\d*',
        '(?i)(?:price|cost 最新|当前)[:\s]*' + '$' + '?[\d,]+\.?\d*',
        '$' + '[\d,]+\.?\d*',
        '(?i)USD[:\s]*[\d,]+\.?\d*',
        '[\d,]+\.?\d*\s*(?:USD|美元)'
    )
'@
if ($content -match [regex]::Escape($old.Trim())) {
    $content = $content -replace [regex]::Escape($old.Trim()), $new.Trim()
    Set-Content -Path $path -Value $content -NoNewline -Encoding UTF8
    Write-Host "Fixed patterns"
} else {
    Write-Host "Pattern not found"
    # Show what we're looking for
    Write-Host "OLD start: $($old.Trim().Substring(0,50))"
    Write-Host "Looking in content around line 48:"
    $lines = Get-Content $path
    $lines[46..52] | ForEach-Object { Write-Host $_ }
}
