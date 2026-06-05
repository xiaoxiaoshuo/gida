$procs = Get-Process powershell -ErrorAction SilentlyContinue | Select-Object Id, StartTime, CPU, WS, @{n='Cmd';e={(Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine}}
Write-Host "=== powershell processes ===" -ForegroundColor Cyan
foreach ($p in $procs) {
    Write-Host "  PID=$($p.Id) Start=$($p.StartTime) CPU=$($p.CPU) WS=$($p.WS)"
    if ($p.Cmd) {
        $cmdShort = $p.Cmd.Substring(0, [Math]::Min(150, $p.Cmd.Length))
        Write-Host "    Cmd: $cmdShort" -ForegroundColor Yellow
    }
}
