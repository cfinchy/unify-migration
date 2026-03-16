# register_monitoring.ps1 - Set up dual-tier monitoring
# Runs quick_health_check every 5 minutes (catch mount failures fast)
# Runs monitor_drain every 30 minutes (detailed status + alerts)

$ProjectDir = "C:\projects\unify-migration"

Write-Host "Registering monitoring tasks..."

# Task 1: Quick health check (every 5 minutes)
$action1 = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File $ProjectDir\scripts\quick_health_check.ps1"
$trigger1 = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 365)
$settings1 = New-ScheduledTaskSettingsSet -StartWhenAvailable -DisallowDemandStart:$false

try {
    Unregister-ScheduledTask -TaskName "UnifyMigration-QuickHealthCheck" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
catch {}

Register-ScheduledTask -Action $action1 -Trigger $trigger1 -Settings $settings1 `
    -TaskName "UnifyMigration-QuickHealthCheck" `
    -Description "Quick NAS mount check - every 5 minutes" -Force | Out-Null

Write-Host "✓ Task registered: UnifyMigration-QuickHealthCheck (every 5 min)"

# Task 2: Full drain monitor (every 30 minutes) - if not already registered
$action2 = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File $ProjectDir\scripts\monitor_drain.ps1"
$trigger2 = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration (New-TimeSpan -Days 365)
$settings2 = New-ScheduledTaskSettingsSet -StartWhenAvailable -DisallowDemandStart:$false

try {
    Unregister-ScheduledTask -TaskName "UnifyMigration-Monitor" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
catch {}

Register-ScheduledTask -Action $action2 -Trigger $trigger2 -Settings $settings2 `
    -TaskName "UnifyMigration-Monitor" `
    -Description "Drain job monitor - every 30 minutes" -Force | Out-Null

Write-Host "✓ Task registered: UnifyMigration-Monitor (every 30 min)"

Write-Host ""
Write-Host "Monitoring is now active:"
Write-Host "  5-minute check:  Quick NAS mount verification (fast, no alerts)"
Write-Host "  30-minute check: Full drain status + iPhone notifications"
Write-Host ""
Write-Host "View logs:"
Write-Host "  Health check: $ProjectDir\logs\health_check.log"
Write-Host "  Drain monitor: $ProjectDir\logs\monitor.log"
