# Drain K: unique data to NAS W:\DriveArchive\K\
# PLAN.md Step R5
# Safe to run while HA VM is live on K: — K:\DebianVm\ is excluded via /XD
# K:\DebianVm\ will be deleted later in Phase 3 (delete_bookworm.ps1) at physical visit

$source = "K:\"
$dest   = "W:\DriveArchive\K"
$log    = "C:\projects\unify-migration\logs\drain_k.log"
New-Item -ItemType Directory -Path "C:\projects\unify-migration\logs" -Force | Out-Null
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Write-Host "Draining K: → $dest"
Write-Host "Excluding DebianVm folder (already deleted or large)"
Write-Host "Log: $log"

# /E = all subdirs, /COPYALL = all attributes, /R:2 = retry twice, /W:5 = wait 5s
# /XD = exclude DebianVm (already gone) and System Volume Information
robocopy $source $dest /E /COPYALL /R:2 /W:5 /XD "K:\DebianVm" "K:\System Volume Information" /LOG+:$log /TEE /NP

Write-Host "`nRobocopy done. Check log for errors: $log"
Write-Host "Verify contents on W: before deleting K: source files."
