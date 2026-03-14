# Inventory K: drive — show top-level folders and sizes
# PLAN.md Step 4.1

Write-Host "=== K: Drive Inventory ===" -ForegroundColor Cyan
Get-PSDrive K | Select-Object @{N='Free_GB';E={[math]::Round($_.Free/1GB,1)}}, @{N='Used_GB';E={[math]::Round($_.Used/1GB,1)}}

Write-Host "`nTop-level folders on K::"
Get-ChildItem "K:\" -ErrorAction SilentlyContinue | ForEach-Object {
    $s = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    [PSCustomObject]@{ Name=$_.Name; GB=[math]::Round($s/1GB,2) }
} | Sort-Object GB -Descending | Format-Table -AutoSize

Write-Host "`nChecking known duplicates on H::"
Write-Host "H:\pcpcpcDownloads exists: $(Test-Path 'H:\pcpcpcDownloads')"
Write-Host "H:\old HA backups exists:  $(Test-Path 'H:\old HA backups')"
Write-Host "K:\c drive nook exists:    $(Test-Path 'K:\c drive nook')"
Write-Host "K:\HA Backups exists:      $(Test-Path 'K:\HA Backups')"
