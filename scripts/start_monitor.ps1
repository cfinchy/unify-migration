# start_monitor.ps1 - Register drain health monitor as a Windows Scheduled Task
# Runs monitor_drain.ps1 every 30 minutes, completely independent of SSH.
# Run this once to set up; re-run to reset/update.
#
# Alerts go to HA Companion App (mobile_app_iphone_chris_2) via Millcreek HA REST API.
# Requires: C:\projects\unify-migration\ha.token  (Millcreek HA long-lived token)
# Without ha.token: monitor still runs and writes to logs\monitor.log only

$ProjectDir = "C:\projects\unify-migration"
$TaskName   = "UnifyMigration-Monitor"
$Script     = "$ProjectDir\scripts\monitor_drain.ps1"
$MonitorLog = "$ProjectDir\logs\monitor.log"

# Deregister any existing monitor task
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$Script`""

# Trigger: every 30 minutes, starting 1 minute from now, running indefinitely
# Note: [TimeSpan]::MaxValue overflows the Task Scheduler XML parser — set Duration
# to "" via the repetition object, which Task Scheduler interprets as "no end".
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 30)
$Trigger.Repetition.Duration = ""    # empty = run indefinitely

$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit  (New-TimeSpan -Minutes 10) `
    -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
    -Settings $Settings -RunLevel Highest -Force | Out-Null

# Run once immediately so we get a baseline before the first 30-min tick
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 5   # brief pause so first run starts

$status = (Get-ScheduledTask -TaskName $TaskName).State

Write-Host ""
Write-Host "=== Monitor registered ===" -ForegroundColor Cyan
Write-Host "Task     : $TaskName"
Write-Host "Script   : $Script"
Write-Host "Schedule : every 30 minutes"
Write-Host "Status   : $status"
Write-Host ""
Write-Host "--- Alert configuration ---" -ForegroundColor Yellow
Write-Host "  Token  : C:\projects\unify-migration\ha.token  (Millcreek HA long-lived token)"
Write-Host "  Notify : mobile_app_iphone_chris_2  (HA Companion App push notification)"
Write-Host ""
Write-Host "  Without ha.token : alerts logged to $MonitorLog only"
Write-Host "  With ha.token    : push notification sent on any problem or completion"
Write-Host ""
Write-Host "Monitor log : $MonitorLog"
Write-Host "To run now  : powershell -ExecutionPolicy Bypass -File $Script"
Write-Host ""
