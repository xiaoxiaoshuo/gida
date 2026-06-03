# Credential discovery v4 - direct cmd
Set-Content -Path "$env:TEMP\gidin.txt" -Value "protocol=https`nhost=github.com`n" -NoNewline
git credential fill < "$env:TEMP\gidin.txt"
Remove-Item "$env:TEMP\gidin.txt"
