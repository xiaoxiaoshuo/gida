$task = Get-ScheduledTask -TaskName 'HourlyPriceCollector'
$triggers = $task.Triggers
foreach ($t in $triggers) {
    Write-Output "TriggerType: $($t.TriggerType)"
    Write-Output "Repetition: $($t.Repetition.Interval)"
    Write-Output "RepetitionDuration: $($t.Repetition.Duration)"
    Write-Output "StartBoundary: $($t.StartBoundary)"
    Write-Output "Enabled: $($t.Enabled)"
}
