# start_monitor.ps1 - Register drain health monitor as a Windows Scheduled Task
# Runs monitor_drain.ps1 every 30 minutes, completely independent of SSH.
# Run this once to set up; re-run to reset/update.
#
# Prerequisites for Telegram alerts (optional but recommended):
#   1. Create a HA long-lived token:
#      HA UI -> bottom-left avatar -> Security -> Long-lived access tokens -> Create
#      Save the token to: C:\projects\unify-migration\ha.token (one line)
#   2. Find your Telegram notify service name:
#      HA UI -> Developer Tools -> Services -> search "notify"
#      Edit monitor_drain.ps1 line: $NotifyService = "telegram_bot"  <- update this
#
# Without ha.token: monitor still runs and logs to logs\monitor.log
# With ha.token:    alerts sent to Telegram + logged

$ProjectDir = "C:\projects\unify-migration"
$TaskName   = "UnifyMigration-Monitor"
$Script     = "$ProjectDir\scripts\monitor_drain.ps1"
$MonitorLog = "$ProjectDir\logs\monitor.log"

# Deregister any existing monitor task
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$Script`""

# Trigger: every 30 minutes, starting 1 minute from now, running indefinitely
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval  (New-TimeSpan -Minutes 30) `
    -RepetitionDuration  ([TimeSpan]::MaxValue)

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
Write-Host "--- Next steps for Telegram alerts ---" -ForegroundColor Yellow
Write-Host "  1. Create HA long-lived token and save to:"
Write-Host "     C:\projects\unify-migration\ha.token"
Write-Host "     (HA UI -> avatar bottom-left -> Security -> Long-lived access tokens)"
Write-Host ""
Write-Host "  2. Verify notify service name in monitor_drain.ps1:"
Write-Host "     `$NotifyService = `"telegram_bot`"  <- check HA Dev Tools > Services > search notify"
Write-Host ""
Write-Host "  Without ha.token: alerts logged to $MonitorLog only"
Write-Host "  With ha.token   : Telegram message sent on any problem or completion"
Write-Host ""
Write-Host "Monitor log : $MonitorLog"
Write-Host "To run now  : powershell -ExecutionPolicy Bypass -File $Script"
Write-Host ""
