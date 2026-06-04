$files = @(
    'C:\Users\Administrator\clawd\agents\workspace-gid\INTEL\agent-G35F-farside-actual-market-close-2026-06-04-2210.md',
    'C:\Users\Administrator\clawd\agents\workspace-gid\data\market\us-equity-6-4-2130-1h-2026-06-04.md',
    'C:\Users\Administrator\clawd\agents\workspace-gid\data\crypto\farside-etf-6-4-actual-2026-06-04.md'
)
foreach ($f in $files) {
    $i = Get-Item $f
    Write-Output ("{0} : {1} bytes" -f $i.Name, $i.Length)
}
