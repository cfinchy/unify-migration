# monitor_drain.ps1 - Periodic health check for all drain tasks
# Runs every 30 min via Task Scheduler (registered by start_monitor.ps1)
# Sends Telegram alert via HA REST API on any problem or completion
# Always writes to logs\monitor.log regardless of alert state
#
# Requires for Telegram alerts:
#   C:\projects\unify-migration\ha.token  (one line, gitignored)
#   $NotifyService set to your HA notify service name (see below)
#
# To find your HA notify service name:
#   HA UI -> Developer Tools -> Services -> search "notify"
#   Likely "notify.telegram_bot" or "notify.mobile_app_<yourphone>"

$ProjectDir    = "C:\projects\unify-migration"
$LogDir        = "$ProjectDir\logs"
$StateFile     = "$LogDir\monitor_state.json"
$MonitorLog    = "$LogDir\monitor.log"
$TokenFile     = "$ProjectDir\ha.token"
$HaUrl         = "https://millcreek.duckdns.org"  # Millcreek HA (same LAN as Windows box)
$NotifyService = "telegram_bot"               # CHANGE THIS to match your HA service name

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
            # Robocopy exit 0=no change, 1=files copied, 2=extra files, 3=both, etc — all OK
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
        # (24h threshold because robocopy with /Z can be silent during a very large file)
        if ($hoursSince -gt 24 -and $taskState -eq "Running") {
            if (-not $s.AlertedStall -and -not $isFirstRun) {
                $alerts.Add("WARNING: Drive $drv log not updated for ${hoursSince}h - possible stall or very large file")
                $s.AlertedStall = $true
            }
        } elseif ($hoursSince -lt 6) {
            $s.AlertedStall = $false   # clear stall flag once log resumes updating
        }

        # New errors since last check
        $allLines   = Get-Content $d.Log -ErrorAction SilentlyContinue
        $errorCount = ($allLines | Where-Object { $_ -match " ERROR | FAILED " }).Count
        $prevErrors = [int]$s.ErrorCount
        if ($errorCount -gt $prevErrors -and -not $isFirstRun) {
            $delta       = $errorCount - $prevErrors
            $recentErrs  = $allLines | Where-Object { $_ -match " ERROR | FAILED " } | Select-Object -Last 2
            $errSample   = ($recentErrs | ForEach-Object { "  $_" }) -join "`n"
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
    $logLine = "$timestamp | ALERTS(${alerts.Count}) | " + ($alerts -join " ; ")
}
Add-Content $MonitorLog $logLine

# ---------------------------------------------------------------------------
# Send Telegram alert via HA REST API
# ---------------------------------------------------------------------------
if ($alerts.Count -gt 0 -and -not $isFirstRun -and (Test-Path $TokenFile)) {
    $token   = (Get-Content $TokenFile -Raw).Trim()
    $msgBody = "Millcreek Drain Alert $timestamp`n"
    $msgBody += ($alerts -join "`n") + "`n"
    $msgBody += "---`n" + ($okLines -join "`n")

    $payload = @{ message = $msgBody } | ConvertTo-Json -Compress
    $headers = @{
        Authorization  = "Bearer $token"
        "Content-Type" = "application/json"
    }
    try {
        Invoke-RestMethod -Uri "$HaUrl/api/services/notify/$NotifyService" `
            -Method Post -Headers $headers -Body $payload -TimeoutSec 15 | Out-Null
        Add-Content $MonitorLog "$timestamp | Telegram sent OK"
    } catch {
        Add-Content $MonitorLog "$timestamp | Telegram FAILED: $_"
        # Also write alert to a visible file as fallback
        $fallback = "$LogDir\drain_alert.txt"
        "=== UNSENT ALERT $timestamp ===" | Set-Content $fallback
        $alerts | Add-Content $fallback
        Add-Content $MonitorLog "$timestamp | Fallback alert written to $fallback"
    }
} elseif ($alerts.Count -gt 0 -and -not $isFirstRun -and -not (Test-Path $TokenFile)) {
    # No token - write visible alert file so SSH check will surface it
    $fallback = "$LogDir\drain_alert.txt"
    "=== ALERT (no ha.token - Telegram not configured) $timestamp ===" | Set-Content $fallback
    $alerts | Add-Content $fallback
    Add-Content $MonitorLog "$timestamp | Alert written to $fallback (ha.token missing)"
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
