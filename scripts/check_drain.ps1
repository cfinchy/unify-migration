# check_drain.ps1 - Show progress of all running drain operations
# Reads robocopy log files and Task Scheduler status.
# Run from SSH at any time - has no effect on the drain itself.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File ...\check_drain.ps1

$LogDir = "C:\projects\unify-migration\logs"

$Drains = @(
    [PSCustomObject]@{ Drive="H"; Task="UnifyMigration-DrainH"; Log="$LogDir\drain_h.log"; TotalGB=3358 },
    [PSCustomObject]@{ Drive="G"; Task="UnifyMigration-DrainG"; Log="$LogDir\drain_g.log"; TotalGB=4192 },
    [PSCustomObject]@{ Drive="K"; Task="UnifyMigration-DrainK"; Log="$LogDir\drain_k.log"; TotalGB=2700 }
)

Write-Host "=== Drain Status $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===" -ForegroundColor Cyan
Write-Host ""

foreach ($d in $Drains) {
    Write-Host "--- Drive $($d.Drive): ---" -ForegroundColor Yellow

    # Task Scheduler status
    $task = Get-ScheduledTask -TaskName $d.Task -ErrorAction SilentlyContinue
    if ($task) {
        $info = Get-ScheduledTaskInfo -TaskName $d.Task -ErrorAction SilentlyContinue
        $state = $task.State
        $lastRun = if ($info.LastRunTime -and $info.LastRunTime -ne [DateTime]::MinValue) {
            $info.LastRunTime.ToString("yyyy-MM-dd HH:mm")
        } else { "never" }
        $lastResult = $info.LastTaskResult
        $color = if ($state -eq "Running") { "Green" } elseif ($state -eq "Ready") { "White" } else { "Red" }
        Write-Host "  Task     : $state  (last run: $lastRun, exit code: $lastResult)" -ForegroundColor $color
    } else {
        Write-Host "  Task     : not registered (run start_drain.ps1 -Drive $($d.Drive))" -ForegroundColor DarkGray
    }

    # Log file stats
    if (Test-Path $d.Log) {
        $lines = Get-Content $d.Log -ErrorAction SilentlyContinue
        $logSize = (Get-Item $d.Log).Length
        $lastMod  = (Get-Item $d.Log).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")

        # Count files and bytes from robocopy summary line
        # Robocopy summary format: "Files :" or "Bytes :" lines
        $bytesSummary = $lines | Where-Object { $_ -match "^\s+Bytes\s*:" } | Select-Object -Last 1
        $filesSummary = $lines | Where-Object { $_ -match "^\s+Files\s*:" } | Select-Object -Last 1
        $speedLine    = $lines | Where-Object { $_ -match "Speed\s*:" }     | Select-Object -Last 1
        $errorLines   = $lines | Where-Object { $_ -match "ERROR|FAILED" }

        # Extract bytes copied from "Bytes :  X  copied  Y  skipped" format
        if ($bytesSummary -match "(\d[\d\.]*)\s+(?:g|Gigabytes|m|Megabytes|k|Kilobytes|Bytes)?\s+(\d[\d,]*)\s+(?:g|Gigabytes|m|Megabytes|k|Kilobytes|Bytes)?") {
        }
        # Simpler: just grab the last 20 lines for a snapshot
        $tail = $lines | Select-Object -Last 5

        Write-Host "  Log      : $($d.Log)  ($([math]::Round($logSize/1KB,0)) KB, updated $lastMod)"
        if ($filesSummary) { Write-Host "  $($filesSummary.Trim())" }
        if ($bytesSummary) { Write-Host "  $($bytesSummary.Trim())" }
        if ($speedLine)    { Write-Host "  $($speedLine.Trim())" }
        if ($errorLines.Count -gt 0) {
            Write-Host "  ERRORS   : $($errorLines.Count) error line(s) in log" -ForegroundColor Red
            $errorLines | Select-Object -Last 3 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        }
        Write-Host "  Last log entries:"
        $tail | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "  Log      : not found (drain not started yet)"
    }

    Write-Host ""
}

Write-Host "--- Active robocopy processes ---"
$robocopyProcs = Get-Process -Name "robocopy" -ErrorAction SilentlyContinue
if ($robocopyProcs) {
    $robocopyProcs | ForEach-Object {
        $runtime = (Get-Date) - $_.StartTime
        Write-Host "  PID $($_.Id)  running $([math]::Round($runtime.TotalHours,1))h  CPU $([math]::Round($_.TotalProcessorTime.TotalMinutes,1))min" -ForegroundColor Green
    }
} else {
    Write-Host "  No robocopy process currently running" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "To start a drain : powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\start_drain.ps1 -Drive <H|G|K>"
Write-Host "To tail a log    : Get-Content C:\projects\unify-migration\logs\drain_<x>.log -Wait -Tail 20"
