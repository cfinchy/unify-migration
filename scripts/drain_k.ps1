# Drain K: unique data to NAS W:\DriveArchive\K\
# PLAN.md Step R5
# Safe to run while HA VM is live on K: — K:\DebianVm\ is excluded via /XD
# K:\DebianVm\ will be deleted later in Phase 3 (delete_bookworm.ps1) at physical visit

. "$PSScriptRoot\mount_nas.ps1"; Mount-Nas   # mounts W: and X: from nas.creds if not already mapped

$source = "K:\"
$dest   = "W:\K backup millcreek"   # pre-existing manual backup — robocopy delta-syncs only new/changed files
$log    = "C:\projects\unify-migration\logs\drain_k.log"
New-Item -ItemType Directory -Path "C:\projects\unify-migration\logs" -Force | Out-Null

Write-Host "Draining K: → $dest  (delta sync — only new/changed files copied)"
Write-Host "Excluding K:\DebianVm (HA VM still running there — freed in Phase 3)"
Write-Host "Log: $log"

# /E = all subdirs, /COPY:DAT = Data+Attributes+Timestamps (no NTFS security - Samba NAS doesn't support it)
# /Z = resume partial file transfers, /R:2 = retry twice, /W:5 = wait 5s
# /XO = exclude older - do not overwrite NAS files that are newer than K: source
#       (protects against K: CRC-corrupted or missing files overwriting good NAS copies)
# /XD = exclude DebianVm (running HA VM) and System Volume Information
robocopy $source $dest /E /COPY:DAT /Z /R:2 /W:5 /XO /XD "K:\DebianVm" "K:\System Volume Information" /LOG+:$log /TEE /NP

Write-Host "`nRobocopy done. Check log for errors: $log"
Write-Host "Verify contents on W:\K backup millcreek before ejecting K:."
