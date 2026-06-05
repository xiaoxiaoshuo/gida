$j = Get-Content 'C:\Users\Administrator\clawd\agents\workspace-gid\data\market\prices_latest.json' -Raw | ConvertFrom-Json
Write-Host "macro.VIX.value:" $j.macro.VIX.value
Write-Host "macro.FNG exists:" ($j.macro.PSObject.Properties.Name -contains "FNG")
Write-Host "macro.PSObject.Properties:" ($j.macro.PSObject.Properties | ForEach-Object { $_.Name }) -join ', '
Write-Host "macro.VIX.value_classification:" $j.macro.VIX.value_classification
