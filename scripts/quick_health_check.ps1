# quick_health_check.ps1 - Fast NAS mount check + stuck process detection (run every 5 minutes)
# Detects and remounts NAS if needed
# Detects and restarts drain tasks if their logs haven't updated in 2+ hours

$ProjectDir = "C:\projects\unify-migration"
$LogFile = "$ProjectDir\logs\health_check.log"
$LogDir = "$ProjectDir\logs"

function Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts | $msg" | Add-Content -Path $LogFile
}

# --- Check NAS mount ---
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

# --- Check for stuck drain processes (logs not updated in 2+ hours) ---
$drains = @(
    @{ Drive = "G"; Task = "UnifyMigration-DrainG"; Log = "$LogDir\drain_g.log" },
    @{ Drive = "H"; Task = "UnifyMigration-DrainH"; Log = "$LogDir\drain_h.log" },
    @{ Drive = "K"; Task = "UnifyMigration-DrainK"; Log = "$LogDir\drain_k.log" }
)

foreach ($d in $drains) {
    $task = Get-ScheduledTask -TaskName $d.Task -EA SilentlyContinue
    if (-not $task) { continue }
    
    if ($task.State -ne "Running") { continue }
    
    # Check log age
    if (Test-Path $d.Log) {
        $lastUpdate = (Get-Item $d.Log).LastWriteTime
        $hoursSinceUpdate = [math]::Round(((Get-Date) - $lastUpdate).TotalHours, 1)
        
        if ($hoursSinceUpdate -gt 2) {
            Log "ALERT: Drive $($d.Drive) log stale ($hoursSinceUpdate hours) - restarting task"
            
            Stop-ScheduledTask -TaskName $d.Task -ErrorAction SilentlyContinue | Out-Null
            Start-Sleep -Seconds 2
            Start-ScheduledTask -TaskName $d.Task -ErrorAction SilentlyContinue | Out-Null
            
            Log "RESTART: Drive $($d.Drive) task restarted"
        }
    }
}
