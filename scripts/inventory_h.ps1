# Inventory H: drive — show top-level folders and sizes
# PLAN.md Step R2

Write-Host "=== H: Drive Inventory ===" -ForegroundColor Cyan
Get-PSDrive H | Select-Object @{N='Free_GB';E={[math]::Round($_.Free/1GB,1)}}, @{N='Used_GB';E={[math]::Round($_.Used/1GB,1)}}

Write-Host "`nTop-level folders on H::"
Get-ChildItem "H:\" -ErrorAction SilentlyContinue | ForEach-Object {
    $s = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    [PSCustomObject]@{ Name=$_.Name; GB=[math]::Round($s/1GB,2) }
} | Sort-Object GB -Descending | Format-Table -AutoSize

Write-Host "`nKnown NAS copies — check before draining H::"
Write-Host "W:\K backup millcreek\HA Backups exists: $(Test-Path 'W:\K backup millcreek\HA Backups')"
Write-Host "W:\K backup millcreek\c drive nook exists: $(Test-Path 'W:\K backup millcreek\c drive nook')"
Write-Host "W:\DriveArchive\H exists: $(Test-Path 'W:\DriveArchive\H')"
Write-Host ""
Write-Host "Note: H:\pcpcpcDownloads = Jan 2026 copy of K:\c drive nook\Users\PCPCPC\Downloads"
Write-Host "      H:\old HA backups  = Jan 2026 copy of K:\HA Backups"
Write-Host "      Both K: originals are also in W:\K backup millcreek — H: is a third copy."
Write-Host "      drain_h.ps1 will copy all of H: to W:\DriveArchive\H regardless (belt + suspenders)."
