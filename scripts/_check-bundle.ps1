$shas = @('01ecf8d', '57dad59', '44f38f0', 'a4393fb', 'c44f92c', '353e1e6')
Set-Location "C:\Users\Administrator\clawd\agents\workspace-gid"
Write-Host "--- 6 commits reachable from HEAD? ---"
foreach ($s in $shas) {
    git merge-base --is-ancestor $s HEAD 2>$null
    $code = $LASTEXITCODE
    Write-Host "  $s  ancestor-of-HEAD = $code"
}

# Also verify via fresh fetch from bundle
$tmpDir = Join-Path $env:TEMP "bundle-check-$PID"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
Set-Location $tmpDir
git init -q 2>$null
git fetch "C:\Users\Administrator\clawd\agents\workspace-gid\repo-2026-06-04_180812.bundle" main 2>&1 | Out-Null
Write-Host ""
Write-Host "--- Fresh fetch from bundle: HEAD log ---"
git log --oneline -7 main
Write-Host ""
Write-Host "--- 6 commits reachable from bundle's main? ---"
foreach ($s in $shas) {
    git merge-base --is-ancestor $s main 2>$null
    $code = $LASTEXITCODE
    Write-Host "  $s  in-bundle-main = $code"
}
Set-Location "C:\Users\Administrator\clawd\agents\workspace-gid"
Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
