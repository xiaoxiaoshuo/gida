# Use Get-Content to pipe into git
$input = "protocol=https`nhost=github.com`n"
$tmp = "$env:TEMP\gidin.txt"
Set-Content -Path $tmp -Value $input -NoNewline
$content = Get-Content $tmp -Raw
$content | git credential fill
Remove-Item $tmp
