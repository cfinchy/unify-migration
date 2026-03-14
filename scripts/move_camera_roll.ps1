# Move Camera Roll videos from OneDrive to NAS to free C: space
# PLAN.md Step 1.3
# ⚠️  This moves files OUT of OneDrive sync — OneDrive will remove local copies after move

$source = "C:\Users\chris\OneDrive\Pictures\Camera Roll"
$dest   = "W:\MediaArchive\CameraRoll"

Write-Host "Source: $source"
Write-Host "Destination: $dest"
$size = (Get-ChildItem $source -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {$_.Extension -match "\.mp4|\.mov|\.avi|\.mkv"} |
    Measure-Object Length -Sum).Sum
Write-Host "Video data to move: $([math]::Round($size/1GB,2)) GB"

$confirm = Read-Host "Proceed? (yes/no)"
if ($confirm -ne "yes") { Write-Host "Aborted."; exit }

New-Item -ItemType Directory -Path $dest -Force | Out-Null

$log = "C:\projects\unify-migration\logs\camera_roll_move.log"
New-Item -ItemType Directory -Path "C:\projects\unify-migration\logs" -Force | Out-Null

robocopy $source $dest /E /MOVE /XA:SH /LOG:$log /TEE /NP
Write-Host "`nDone. Log at $log"
Write-Host "Check OneDrive isn't re-syncing the folder before deleting the source."
