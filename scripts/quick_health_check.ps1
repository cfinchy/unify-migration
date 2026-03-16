# quick_health_check.ps1 - Fast NAS mount check (run every 5 minutes)
# Detects and remounts if needed. Minimal overhead.

$ProjectDir = "C:\projects\unify-migration"
$LogFile = "$ProjectDir\logs\health_check.log"

function Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts | $msg" | Add-Content -Path $LogFile
}

# Check if all drives are mounted
$drivesMounted = (Test-Path "W:" -EA SilentlyContinue) -and `
                 (Test-Path "X:" -EA SilentlyContinue) -and `
                 (Test-Path "Y:" -EA SilentlyContinue)

if (-not $drivesMounted) {
    Log "ALERT: NAS not mounted - attempting remount"
    
    # Clear and remount
    net use /delete W: /y 2>&1 | Out-Null
    net use /delete X: /y 2>&1 | Out-Null
    net use /delete Y: /y 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    
    & "$ProjectDir\scripts\mount_nas.ps1" 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    
    if ((Test-Path "W:" -EA SilentlyContinue)) {
        Log "SUCCESS: NAS remounted"
    } else {
        Log "FAILED: NAS remount unsuccessful"
    }
} else {
    Log "OK: NAS mounted (W: X: Y:)"
}
