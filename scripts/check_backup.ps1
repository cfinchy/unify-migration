# Check HA backup status and list recent backups on X:\HABackups
# PLAN.md Step 1.1

. "$PSScriptRoot\get_token.ps1"
$base = "https://millcreek.duckdns.org:8123"
$headers = @{ Authorization = "Bearer $token" }

# Check backup manager state
$state = Invoke-RestMethod -Uri "$base/api/states/sensor.backup_backup_manager_state" -Headers $headers
Write-Host "Backup manager state: $($state.state)"
if ($state.state -eq "create_backup") { Write-Host "⏳ Backup still IN PROGRESS — wait before proceeding" }
if ($state.state -eq "idle") { Write-Host "✅ Backup manager idle — last backup complete" }

# Last successful backup time
$last = Invoke-RestMethod -Uri "$base/api/states/sensor.backup_last_successful_automatic_backup" -Headers $headers
Write-Host "Last successful backup: $($last.state)"

# List backup files on NAS share
Write-Host "`nFiles on X:\HABackups:"
Get-ChildItem "X:\HABackups" -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10 Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime |
    Format-Table -AutoSize
