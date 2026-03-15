# Inventory G: drive — show top-level folders and sizes
# PLAN.md Step R2

Write-Host "=== G: Drive Inventory ===" -ForegroundColor Cyan
Get-PSDrive G | Select-Object @{N='Free_GB';E={[math]::Round($_.Free/1GB,1)}}, @{N='Used_GB';E={[math]::Round($_.Used/1GB,1)}}

Write-Host "`nTop-level folders on G::"
Get-ChildItem "G:\" -ErrorAction SilentlyContinue | ForEach-Object {
    $s = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    [PSCustomObject]@{ Name=$_.Name; GB=[math]::Round($s/1GB,2) }
} | Sort-Object GB -Descending | Format-Table -AutoSize

Write-Host "`nKnown NAS copies — check before draining G::"
Write-Host "W:\DriveArchive\G exists: $(Test-Path 'W:\DriveArchive\G')"
Write-Host ""
Write-Host "Note: G: contains a Bullseye DebianVM — drain_g.ps1 copies it all to W:\DriveArchive\G."
Write-Host "      W:\K backup millcreek\DebianVm is a Bookworm copy (from K:, not G:) — no overlap."
Write-Host "      Test the G: DebianVM from W:\DriveArchive\G before ejecting G:."
