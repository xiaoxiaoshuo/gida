# Cron Watchdog GFW Health Fix — 2026-06-24

**Date**: 2026-06-24 07:39 CST
**Agent**: Subagent G-109
**Status**: ✅ Fixed

## Bug

**File**: `scripts/cron-watchdog-v3-30min.ps1`, line ~184

**Original code**:
```powershell
$probe = cmd /c "openssl s_client -connect github.com:443 -servername github.com < NUL" 2>&1 | Out-String
```

**Error**: `The term 'cmd' is not recognized as the name of a cmdlet, function, script file, or operable program.`

**Root cause**: In PowerShell, `cmd` is an external executable, not a cmdlet. When the PATH resolution fails in some contexts (e.g., SYSTEM account, non-interactive), PowerShell cannot find `cmd.exe`. This causes `Test-GFWHealth` to always fail with a parse error, contributing to false ALERTs.

## Fix

**Line 184** — replaced `cmd` with full path:
```powershell
$probe = "$env:windir\system32\cmd.exe" /c "openssl s_client -connect github.com:443 -servername github.com < NUL" 2>&1 | Out-String
```

## Verification
- Parse check: ✅ Syntax valid
- Path resolution: `$env:windir` = `C:\WINDOWS`
- Full path: `C:\WINDOWS\system32\cmd.exe` → **Exists: True**
- No other instances of bare `cmd` found in the file
