@echo off
echo Starting AI News Collector at %TIME% >> C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\cron_log.txt
"D:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -NoLogo -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\fetch-hn-top30.ps1" >> C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\cron_hn.log 2>&1
echo HN Done at %TIME%, Exit: %ERRORLEVEL% >> C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\cron_log.txt
"D:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -NoLogo -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\gh-trending-v3.ps1" >> C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\cron_gh.log 2>&1
echo GH Done at %TIME%, Exit: %ERRORLEVEL% >> C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\cron_log.txt
echo All Done at %TIME% >> C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\cron_log.txt