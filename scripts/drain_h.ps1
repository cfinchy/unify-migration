# Drain H: to NAS W:\DriveArchive\H\
# PLAN.md Step R3

. "$PSScriptRoot\mount_nas.ps1"; Mount-Nas   # mounts W: and X: from nas.creds if not already mapped

$source = "H:\"
$dest   = "W:\DriveArchive\H"
$log    = "C:\projects\unify-migration\logs\drain_h.log"
New-Item -ItemType Directory -Path "C:\projects\unify-migration\logs" -Force | Out-Null
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Write-Host "Draining H: → $dest"
Write-Host "⚠️  Ensure X:\HABackups has a recent HA backup before this deletes H:\old HA backups"
$confirm = Read-Host "Confirmed X:\HABackups is up to date? (yes/no)"
if ($confirm -ne "yes") { Write-Host "Aborted. Run check_backup.ps1 first."; exit }

robocopy $source $dest /E /COPYALL /R:2 /W:5 /XD "H:\System Volume Information" /LOG+:$log /TEE /NP
Write-Host "`nDone. Log: $log"
