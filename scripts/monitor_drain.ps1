# monitor_drain.ps1 - Periodic health check for all drain tasks
# Runs every 30 min via Task Scheduler (registered by start_monitor.ps1)
# Sends push notification via home HA on any problem, completion, or daily summary
# Always writes to logs\monitor.log regardless of alert state
#
# Requires:
#   C:\projects\unify-migration\ha.token  (home HA GPS logger token, gitignored)

$ProjectDir    = "C:\projects\unify-migration"
$LogDir        = "$ProjectDir\logs"
$StateFile     = "$LogDir\monitor_state.json"
$MonitorLog    = "$LogDir\monitor.log"
$TokenFile     = "$ProjectDir\ha.token"
$HaUrl         = "https://ha.fnchysan.uk"          # Home HA (stable instance, same as network reports)
$NotifyService = "mobile_app_iphone_caf"            # same service used by Network Daily Report

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

# ---------------------------------------------------------------------------
# Load previous state (PS5-compatible — no -AsHashtable)
# First run: record baseline without alerting (avoids false positives on
# legacy errors already in logs before monitoring started)
# ---------------------------------------------------------------------------
$isFirstRun = -not (Test-Path $StateFile)

$defaultState = [PSCustomObject]@{
    G = [PSCustomObject]@{ ErrorCount=0; AlertedStall=$false; AlertedStop=$false; Completed=$false }
    H = [PSCustomObject]@{ ErrorCount=0; AlertedStall=$false; AlertedStop=$false; Completed=$false }
    K = [PSCustomObject]@{ ErrorCount=0; AlertedStall=$false; AlertedStop=$false; Completed=$false }
    LastDailyReport = $null
}
if (-not $isFirstRun) {
    try   { $state = Get-Content $StateFile -Raw | ConvertFrom-Json }
    catch { $state = $defaultState; $isFirstRun = $true }
} else { $state = $defaultState }

# ---------------------------------------------------------------------------
$Drains = @(
    [PSCustomObject]@{ Drive="G"; Task="UnifyMigration-DrainG"; Log="$LogDir\drain_g.log"; TotalGB=4192 }
    [PSCustomObject]@{ Drive="H"; Task="UnifyMigration-DrainH"; Log="$LogDir\drain_h.log"; TotalGB=3358 }
    [PSCustomObject]@{ Drive="K"; Task="UnifyMigration-DrainK"; Log="$LogDir\drain_k.log"; TotalGB=2700 }
)

$alerts  = New-Object System.Collections.Generic.List[string]
$okLines = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------------------
# Helper: parse bytes copied from the last robocopy summary block in a log
# Robocopy summary format: "   Bytes :  4.192 g    1.500 g    ..."
#                           columns:    Total      Copied     Skipped ...
# Returns string like "1.50 GB / 4192 GB (36%)" or "" if not parseable
# ---------------------------------------------------------------------------
function Get-DrainProgress {
    param([string]$LogPath, [int]$TotalGB)
    if (-not (Test-Path $LogPath)) { return "" }
    $lines       = Get-Content $LogPath -ErrorAction SilentlyContinue
    $bytesSummary = $lines | Where-Object { $_ -match "^\s+Bytes\s*:" } | Select-Object -Last 1
    if (-not $bytesSummary) { return "" }

    # Extract two numeric fields after "Bytes :" — total and copied
    $vals = [regex]::Matches($bytesSummary, '([\d\.]+)\s*([gGmMkK]?)')
    if ($vals.Count -lt 2) { return "" }

    function To-GB { param($val, $unit)
        switch ($unit.ToLower()) {
            "g" { [double]$val }
            "m" { [double]$val / 1024 }
            "k" { [double]$val / 1048576 }
            default { [double]$val / 1073741824 }
        }
    }

    $copiedGB = To-GB $vals[1].Groups[1].Value $vals[1].Groups[2].Value
    $copiedGB = [math]::Round($copiedGB, 1)
    $pct      = if ($TotalGB -gt 0) { [math]::Round($copiedGB / $TotalGB * 100, 0) } else { 0 }
    return "${copiedGB} GB / ${TotalGB} GB (${pct}%)"
}

# ---------------------------------------------------------------------------
# NAS reachability
# ---------------------------------------------------------------------------
$nasOk = Test-Path "\\192.168.0.124\Personal-Drive" -ErrorAction SilentlyContinue
if (-not $nasOk) {
    if (-not $isFirstRun) { $alerts.Add("CRITICAL: NAS \\192.168.0.124\Personal-Drive UNREACHABLE") }
    $okLines.Add("NAS: UNREACHABLE")
} else {
    $okLines.Add("NAS: OK")
}

# ---------------------------------------------------------------------------
# Per-drive checks
# ---------------------------------------------------------------------------
foreach ($d in $Drains) {
    $drv = $d.Drive
    $s   = $state.$drv

    if ($s.Completed) { $okLines.Add("Drive $drv : Completed"); continue }

    $task = Get-ScheduledTask -TaskName $d.Task -ErrorAction SilentlyContinue
    $info = if ($task) { Get-ScheduledTaskInfo -TaskName $d.Task -ErrorAction SilentlyContinue } else { $null }

    # Task vanished from scheduler entirely
    if (-not $task) {
        if (-not $isFirstRun) { $alerts.Add("CRITICAL: Drive $drv - task NOT FOUND in scheduler") }
        $okLines.Add("Drive $drv : MISSING from scheduler")
        continue
    }

    $taskState = $task.State
    $exitCode  = if ($info -and $info.LastRunTime -ne [DateTime]::MinValue) { $info.LastTaskResult } else { $null }
    $lastRun   = if ($info -and $info.LastRunTime -ne [DateTime]::MinValue) { $info.LastRunTime.ToString("MM-dd HH:mm") } else { "never" }

    # Task finished (Ready = not running right now)
    if ($taskState -eq "Ready" -and $exitCode -ne $null) {
        if ($exitCode -le 7) {
            if (-not $isFirstRun) {
                $alerts.Add("SUCCESS: Drive $drv drain COMPLETED (robocopy exit $exitCode) - verify NAS then check off in PLAN.md")
            }
            $s.Completed = $true
        } elseif (-not $s.AlertedStop) {
            if (-not $isFirstRun) {
                $alerts.Add("CRITICAL: Drive $drv task STOPPED (exit code $exitCode > 7 = robocopy error) at $lastRun")
            }
            $s.AlertedStop = $true
        }
        $okLines.Add("Drive $drv : Stopped (exit=$exitCode last=$lastRun)")
        continue
    }

    # Task is Running or Queued — check log freshness and error count
    if (Test-Path $d.Log) {
        $item        = Get-Item $d.Log
        $lastMod     = $item.LastWriteTime
        $hoursSince  = [math]::Round(((Get-Date) - $lastMod).TotalHours, 1)
        $logSizeKB   = [math]::Round($item.Length / 1KB, 0)

        # Stall detection: >24h without log update while task claims to be Running
        if ($hoursSince -gt 24 -and $taskState -eq "Running") {
            if (-not $s.AlertedStall -and -not $isFirstRun) {
                $alerts.Add("WARNING: Drive $drv log not updated for ${hoursSince}h - possible stall or very large file")
                $s.AlertedStall = $true
            }
        } elseif ($hoursSince -lt 6) {
            $s.AlertedStall = $false
        }

        # New errors since last check
        $allLines   = Get-Content $d.Log -ErrorAction SilentlyContinue
        $errorCount = ($allLines | Where-Object { $_ -match " ERROR | FAILED " }).Count
        $prevErrors = [int]$s.ErrorCount
        if ($errorCount -gt $prevErrors -and -not $isFirstRun) {
            $delta      = $errorCount - $prevErrors
            $recentErrs = $allLines | Where-Object { $_ -match " ERROR | FAILED " } | Select-Object -Last 2
            $errSample  = ($recentErrs | ForEach-Object { "  $_" }) -join "`n"
            $alerts.Add("WARNING: Drive $drv has $delta new error line(s) (total $errorCount):`n$errSample")
        }
        $s.ErrorCount = $errorCount

        $okLines.Add("Drive $drv : $taskState  log=${logSizeKB}KB updated ${hoursSince}h ago  errors=$errorCount")
    } else {
        $okLines.Add("Drive $drv : $taskState  (log not yet created)")
    }
}

# Robocopy process count
$rcCount = (Get-Process -Name "robocopy" -ErrorAction SilentlyContinue | Measure-Object).Count
$okLines.Add("robocopy.exe processes: $rcCount")

# ---------------------------------------------------------------------------
# Write to monitor.log (always)
# ---------------------------------------------------------------------------
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
if ($isFirstRun) {
    $logLine = "$timestamp | BASELINE (first run - recording state, no alerts sent) | " + ($okLines -join " | ")
} elseif ($alerts.Count -eq 0) {
    $logLine = "$timestamp | OK | " + ($okLines -join " | ")
} else {
    $logLine = "$timestamp | ALERTS($($alerts.Count)) | " + ($alerts -join " ; ")
}
Add-Content $MonitorLog $logLine

# ---------------------------------------------------------------------------
# Helper: send a push notification
# ---------------------------------------------------------------------------
function Send-Notification {
    param([string]$Message)
    $token   = (Get-Content $TokenFile -Raw).Trim()
    $payload = @{ message = $Message } | ConvertTo-Json -Compress
    $headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
    Invoke-RestMethod -Uri "$HaUrl/api/services/notify/$NotifyService" `
        -Method Post -Headers $headers -Body $payload -TimeoutSec 15 | Out-Null
}

# ---------------------------------------------------------------------------
# Alert notification (problems / completion)
# ---------------------------------------------------------------------------
if ($alerts.Count -gt 0 -and -not $isFirstRun -and (Test-Path $TokenFile)) {
    $msg  = "Millcreek Drain Alert $timestamp`n"
    $msg += ($alerts -join "`n") + "`n---`n" + ($okLines -join "`n")
    try {
        Send-Notification $msg
        Add-Content $MonitorLog "$timestamp | Alert notification sent"
    } catch {
        Add-Content $MonitorLog "$timestamp | Alert notification FAILED: $_"
        $fallback = "$LogDir\drain_alert.txt"
        "=== UNSENT ALERT $timestamp ===" | Set-Content $fallback
        $alerts | Add-Content $fallback
    }
} elseif ($alerts.Count -gt 0 -and -not $isFirstRun -and -not (Test-Path $TokenFile)) {
    $fallback = "$LogDir\drain_alert.txt"
    "=== ALERT (no ha.token) $timestamp ===" | Set-Content $fallback
    $alerts | Add-Content $fallback
    Add-Content $MonitorLog "$timestamp | Alert written to $fallback (ha.token missing)"
}

# ---------------------------------------------------------------------------
# Daily progress report (once per 24h regardless of alert status)
# ---------------------------------------------------------------------------
$lastReport   = if ($state.PSObject.Properties['LastDailyReport'] -and $state.LastDailyReport) {
                    [DateTime]$state.LastDailyReport
                } else { [DateTime]::MinValue }
$hoursSinceDR = ((Get-Date) - $lastReport).TotalHours
$sendDaily    = (-not $isFirstRun) -and ($hoursSinceDR -ge 24) -and (Test-Path $TokenFile)

if ($sendDaily) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Millcreek Drain Progress — $timestamp")
    $lines.Add("")

    foreach ($d in $Drains) {
        $drv = $d.Drive
        $s   = $state.$drv

        if ($s.Completed) {
            $lines.Add("Drive $drv : Completed")
            continue
        }

        $task      = Get-ScheduledTask -TaskName $d.Task -ErrorAction SilentlyContinue
        $taskState = if ($task) { $task.State } else { "MISSING" }

        if (Test-Path $d.Log) {
            $item       = Get-Item $d.Log
            $hoursSince = [math]::Round(((Get-Date) - $item.LastWriteTime).TotalHours, 1)
            $logSizeMB  = [math]::Round($item.Length / 1MB, 1)
            $progress   = Get-DrainProgress $d.Log $d.TotalGB
            $errCount   = [int]$s.ErrorCount
            $errStr     = if ($errCount -gt 0) { " | $errCount errors" } else { "" }
            $progressStr = if ($progress) { " | $progress" } else { " | log ${logSizeMB}MB" }
            $lines.Add("Drive $drv : $taskState${progressStr} | updated ${hoursSince}h ago${errStr}")
        } else {
            $lines.Add("Drive $drv : $taskState (no log yet)")
        }
    }

    $lines.Add("")
    $lines.Add("NAS: $(if ($nasOk) { 'OK' } else { 'UNREACHABLE' }) | robocopy processes: $rcCount")

    try {
        Send-Notification ($lines -join "`n")
        $state | Add-Member -Force -NotePropertyName LastDailyReport -NotePropertyValue (Get-Date -Format "o")
        Add-Content $MonitorLog "$timestamp | Daily report sent"
    } catch {
        Add-Content $MonitorLog "$timestamp | Daily report FAILED: $_"
    }
}

# ---------------------------------------------------------------------------
# Save updated state
# ---------------------------------------------------------------------------
$state | ConvertTo-Json | Set-Content $StateFile

if ($isFirstRun) {
    Write-Host "First run complete. Baseline recorded. Monitoring active from next run."
    Write-Host "State file: $StateFile"
    Write-Host "Monitor log: $MonitorLog"
}
