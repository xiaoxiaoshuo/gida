# debug-fg-v3.ps1
$fgPage = Invoke-WebRequest 'https://alternative.me/crypto/fear-and-greed-index/' -TimeoutSec 12 -UseBasicParsing
$content = $fgPage.Content

# 找 "Now" 在原文中的位置
$nowIdx = $content.IndexOf('Now')
if ($nowIdx -ge 0) {
    $start = [Math]::Max(0, $nowIdx)
    $len = [Math]::Min(200, $content.Length - $nowIdx)
    Write-Host "After 'Now':"
    Write-Host $content.Substring($nowIdx, $len) -Replace '`n', ' '
}
Write-Host "---"
$yesterdayIdx = $content.IndexOf('Yesterday')
if ($yesterdayIdx -ge 0) {
    $start = [Math]::Max(0, $yesterdayIdx - 100)
    $len = [Math]::Min(100, $yesterdayIdx)
    Write-Host "Before 'Yesterday':"
    Write-Host $content.Substring($start, $yesterdayIdx - $start) -Replace '`n', ' '
}
