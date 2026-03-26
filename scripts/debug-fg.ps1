# debug-fg-v2.ps1
$fgPage = Invoke-WebRequest 'https://alternative.me/crypto/fear-and-greed-index/' -TimeoutSec 12 -UseBasicParsing
$content = $fgPage.Content

# 找 "Now" 和 "Yesterday" 之间的内容
if ($content -match 'Now(.*?)Yesterday') {
    $between = $matches[1]
    Write-Host "Between Now and Yesterday:"
    Write-Host $between
    Write-Host "---"
    # 在这段中找第一个独立数字
    if ($between -match '^\s*([0-9]{1,2})\s*$') {
        Write-Host "Found: $($matches[1])"
    }
    # 找第一个数字
    $firstNum = [regex]::Match($between, '(\d+)')
    Write-Host "First number found: $($firstNum.Value)"
}
