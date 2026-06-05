$headers = @{
  'Accept' = 'application/vnd.github.v3+json'
  'User-Agent' = 'gida'
}
$uri = 'https://api.github.com/search/repositories?q=stars:%3E1000+pushed:%3E2026-05-25&sort=stars&per_page=15'
$out = 'C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\_raw_test.json'
try {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $resp = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 25
  $sw.Stop()
  $ms = [int]$sw.ElapsedMilliseconds
  Write-Host ("HTTP_OK: total_count={0} items={1} ms={2}" -f $resp.total_count, $resp.items.Count, $ms)
  $resp | ConvertTo-Json -Depth 4 -Compress | Out-File -FilePath $out -Encoding UTF8
  $size = (Get-Item $out).Length
  Write-Host ("SAVED: {0} bytes" -f $size)
  $resp.items | Select-Object -First 5 | ForEach-Object {
    $lang = if ($_.language) { $_.language } else { 'N/A' }
    $desc = if ($_.description) { $_.description.Substring(0,[Math]::Min(60,$_.description.Length)) } else { '' }
    Write-Host (" - {0} [{1}★] {2} | {3}" -f $_.full_name, $_.stargazers_count, $lang, $desc)
  }
} catch {
  Write-Host ("HTTP_FAIL: {0}" -f $_.Exception.Message)
  exit 1
}
