# monitor_drain.ps1 - Health monitor for long-running drain jobs
# Runs every 30 min via Task Scheduler (registered by start_monitor.ps1)
# Checks NAS mount, drain task status, error counts, remounts if needed
# Sends push notifications via home HA if problems detected or daily summary

param([switch]$TestMode = $false)

$ProjectDir    = "C:\projects\unify-migration"
$LogDir        = "$ProjectDir\logs"
$StateFile     = "$LogDir\monitor_state.json"
$MonitorLog    = "$LogDir\monitor.log"
$TokenFile     = "$ProjectDir\ha.token"
$HaUrl         = "https://ha.fnchysan.uk"
$NotifyService = "mobile_app_iphone_caf"

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

# Logging helper
function WriteLog {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $msg"
    Write-Host $line
    Add-Content -Path $MonitorLog -Value $line
}

# Send notification to home HA mobile app
function SendAlert {
    param([string]$title, [string]$message)
    
    # Log the alert locally (always works)
    WriteLog "ALERT: $title - $message"
    
    # Send to HA mobile app
    if (-not (Test-Path $TokenFile)) {
        return
    }
    
    try {
        $token = (Get-Content $TokenFile -Raw).Trim()
        
        # HA API endpoint: /api/services/notify/{service_name}
        # For mobile_app_iphone_caf service, POST to that endpoint with title/message
        $body = @{
            title = $title
            message = $message
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$HaUrl/api/services/notify/mobile_app_iphone_caf" `
            -Method Post `
            -Headers @{Authorization = "Bearer $token"; "Content-Type" = "application/json"} `
            -Body $body `
            -ErrorAction Stop
        
        WriteLog "SENT to iPhone: $title"
    }
    catch {
        WriteLog "Failed to send to HA: $_"
    }
}

WriteLog "=== Monitor Start ==="

# Load previous state (first run: baseline only)
$isFirstRun = -not (Test-Path $StateFile)
if ($isFirstRun) {
    $state = @{
        G = @{ LastErrorCount = 0; LastLogSize = 0; CompletedAt = $null }
        H = @{ LastErrorCount = 0; LastLogSize = 0; CompletedAt = $null }
        K = @{ LastErrorCount = 0; LastLogSize = 0; CompletedAt = $null }
        LastDailyReport = [DateTime]::MinValue
    }
    WriteLog "First run - recording baseline"
} else {
    try {
        $state = Get-Content $StateFile -Raw | ConvertFrom-Json -AsHashtable
    }
    catch {
        WriteLog "Failed to load state: $_"
        $state = @{}
    }
}

# --- Check NAS reachability (both UNC path and drive letters) ---
$nasPath = "\\192.168.0.124\Personal-Drive"
$nasOk = (Test-Path $nasPath -ErrorAction SilentlyContinue) -and `
         (Test-Path "W:" -ErrorAction SilentlyContinue) -and `
         (Test-Path "X:" -ErrorAction SilentlyContinue) -and `
         (Test-Path "Y:" -ErrorAction SilentlyContinue)

if (-not $nasOk) {
    WriteLog "NAS NOT READY - UNC: $(Test-Path $nasPath -EA SilentlyContinue), W: $(Test-Path W: -EA SilentlyContinue), X: $(Test-Path X: -EA SilentlyContinue), Y: $(Test-Path Y: -EA SilentlyContinue)"
    WriteLog "NAS UNREACHABLE - attempting remount"
    
    # Clear stale mounts
    net use /delete W: /y 2>&1 | Out-Null
    net use /delete X: /y 2>&1 | Out-Null
    net use /delete Y: /y 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    
    # Remount
    & "$ProjectDir\scripts\mount_nas.ps1" 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    
    # Check again
    $nasOk = (Test-Path $nasPath -ErrorAction SilentlyContinue) -and `
             (Test-Path "W:" -ErrorAction SilentlyContinue)
    
    if ($nasOk) {
        WriteLog "NAS: remounted successfully (W: $(Test-Path W: -EA SilentlyContinue), X: $(Test-Path X: -EA SilentlyContinue), Y: $(Test-Path Y: -EA SilentlyContinue))"
    } else {
        WriteLog "NAS: STILL UNREACHABLE after remount"
        if (-not $isFirstRun) {
            SendAlert "CRITICAL: NAS Mount Failed" "Drive letters not accessible. Drain jobs will stall. Manual intervention needed."
        }
    }
} else {
    WriteLog "NAS: OK (all drives mounted)"
}

# --- Check drain tasks ---
$drains = @(
    @{ Drive = "G"; Task = "UnifyMigration-DrainG"; Log = "$LogDir\drain_g.log" }
    @{ Drive = "H"; Task = "UnifyMigration-DrainH"; Log = "$LogDir\drain_h.log" }
    @{ Drive = "K"; Task = "UnifyMigration-DrainK"; Log = "$LogDir\drain_k.log" }
)

$problemCount = 0

foreach ($d in $drains) {
    $drv      = $d.Drive
    $taskName = $d.Task
    $logPath  = $d.Log
    
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $task) {
        WriteLog "Drive $drv : TASK NOT FOUND"
        $problemCount++
        continue
    }
    
    $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
    $taskState = $task.State
    
    # Parse errors from log
    $errCount = 0
    if (Test-Path $logPath) {
        $errCount = @(Get-Content $logPath | Where-Object { $_ -match "ERROR \d+" }).Count
        $logSize = (Get-Item $logPath).Length
        $logLastUpdate = (Get-Item $logPath).LastWriteTime
        $hoursSinceUpdate = [math]::Round(((Get-Date) - $logLastUpdate).TotalHours, 1)
        
        WriteLog "Drive $drv : $taskState | Errors: $errCount | Updated: $hoursSinceUpdate hours ago"
        
        # Check for stall (no log update in 2 hours while running)
        if ($taskState -eq "Running" -and $hoursSinceUpdate -gt 2) {
            WriteLog "Drive $drv : WARNING - task appears stalled (no log update)"
            if (-not $isFirstRun) {
                $problemCount++
                SendAlert "WARNING: Drain $drv Stalled" "No log update in $hoursSinceUpdate hours. NAS may be disconnected."
            }
        }
        
        # Check for error increase
        $lastErrCount = if ($state.$drv) { $state.$drv.LastErrorCount } else { 0 }
        if ($errCount -gt $lastErrCount -and -not $isFirstRun) {
            $newErrors = $errCount - $lastErrCount
            WriteLog "Drive $drv : $newErrors new errors detected"
            $problemCount++
            SendAlert "WARNING: Drain $drv Errors" "Detected $newErrors new errors. Check logs: $logPath"
        }
        
        $state.$drv = @{ LastErrorCount = $errCount; LastLogSize = $logSize }
    } else {
        WriteLog "Drive $drv : $taskState (no log yet)"
    }
}

# --- Daily summary ---
$lastReport = if ($state.LastDailyReport) { [DateTime]$state.LastDailyReport } else { [DateTime]::MinValue }
$hoursSinceReport = ((Get-Date) - $lastReport).TotalHours
$sendDaily = (-not $isFirstRun) -and ($hoursSinceReport -ge 24) -and (Test-Path $TokenFile)

if ($sendDaily) {
    WriteLog "Sending daily summary"
    $summary = "Drain Status Summary`n"
    $summary += "NAS: $(if ($nasOk) { 'OK' } else { 'UNREACHABLE' })`n"
    $summary += "Issues detected: $problemCount`n"
    $summary += "Check logs: $LogDir"
    
    SendAlert "Drain Daily Status" $summary
    $state.LastDailyReport = (Get-Date).ToString("o")
}

# Save state
$state | ConvertTo-Json | Set-Content $StateFile

if ($isFirstRun) {
    WriteLog "Baseline recorded. Active monitoring begins next cycle."
}

WriteLog "=== Monitor Complete ==="
