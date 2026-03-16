# health_check.ps1 - Simple NAS mount monitoring
# Run every 15 minutes via Task Scheduler
# If NAS unreachable: remount, log it, and continue

$ProjectDir = "C:\projects\unify-migration"
$LogDir     = "$ProjectDir\logs"
$HealthLog  = "$LogDir\health_check.log"

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$ts] $Message"
    Write-Host $msg
    Add-Content -Path $HealthLog -Value $msg
}

Log "=== Health Check ==="

# Check NAS reachability
$nas_path = "\\192.168.0.124\Personal-Drive"
if (Test-Path $nas_path -ErrorAction SilentlyContinue) {
    Log "NAS: OK"
} else {
    Log "NAS: UNREACHABLE - attempting remount"
    
    # Disconnect stale mounts
    net use /delete W: /y 2>&1 | Out-Null
    net use /delete X: /y 2>&1 | Out-Null
    net use /delete Y: /y 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    
    # Re-run mount script
    & "$ProjectDir\scripts\mount_nas.ps1"
    Start-Sleep -Seconds 3
    
    # Verify
    if (Test-Path $nas_path -ErrorAction SilentlyContinue) {
        Log "NAS: remounted successfully"
    } else {
        Log "NAS: STILL UNREACHABLE after remount - intervention needed"
    }
}

# Check drain tasks
foreach ($drive in @("G", "H", "K")) {
    $task_name = "UnifyMigration-Drain$drive"
    $task = Get-ScheduledTask -TaskName $task_name -ErrorAction SilentlyContinue
    
    if (-not $task) {
        Log "Drain $drive : TASK NOT FOUND"
        continue
    }
    
    $info = Get-ScheduledTaskInfo -TaskName $task_name -ErrorAction SilentlyContinue
    $status = $task.State
    $last_run = $info.LastRunTime
    
    Log "Drain $drive : $status (last run: $last_run)"
    
    # Check if task is hung (not updated in 2 hours)
    $last_run_age = (Get-Date) - $last_run
    if ($last_run_age.TotalHours -gt 2 -and $status -eq "Running") {
        Log "Drain $drive : WARNING - appears stalled (no update in 2 hours)"
    }
}

Log "Health check complete"
Log ""
