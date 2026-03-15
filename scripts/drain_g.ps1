# Drain G: to NAS W:\DriveArchive\G\
# PLAN.md Step R4

$source = "G:\"
$dest   = "W:\DriveArchive\G"
$log    = "C:\projects\unify-migration\logs\drain_g.log"
New-Item -ItemType Directory -Path "C:\projects\unify-migration\logs" -Force | Out-Null
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Write-Host "Draining G: → $dest"
Write-Host "⚠️  G: contains Bookworm/Bullseye DebianVM files"
Write-Host "⚠️  NOTE IN MEMORY.MD: Test DebianVM from NAS before deleting G: copy"

robocopy $source $dest /E /COPYALL /R:2 /W:5 /XD "G:\System Volume Information" /LOG+:$log /TEE /NP
Write-Host "`nDone. Log: $log"
Write-Host "Remember: DO NOT delete G:\DebianVm until VM has been tested from W:\DriveArchive\G\"
