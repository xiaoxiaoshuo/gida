$bundlePath = "C:\Users\Administrator\clawd\agents\workspace-gid\repo-2026-06-04_180812.bundle"
$tmpDir = Join-Path $env:TEMP "bundle-verify-$PID"
Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tmpDir | Out-Null
Set-Location $tmpDir
git init -q
Write-Host "--- Fetching from bundle into fresh repo ---"
git fetch "file:///$($bundlePath -replace '\\','/')" main 2>&1 | Out-Null
Write-Host "Branches:"
git branch -a
Write-Host ""
Write-Host "--- 6 commits reachable from bundle's main? ---"
$shas = @('01ecf8d', '57dad59', '44f38f0', 'a4393fb', 'c44f92c', '353e1e6')
foreach ($s in $shas) {
    git merge-base --is-ancestor $s main 2>$null
    $code = $LASTEXITCODE
    Write-Host "  $s  in-bundle-main = $code"
}
Write-Host ""
Write-Host "--- Bundle verify (full) ---"
git bundle verify $bundlePath 2>&1
Set-Location "C:\Users\Administrator\clawd\agents\workspace-gid"
Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
