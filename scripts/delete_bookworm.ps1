# DELETE Bookworm VM files from K: — frees ~1.6 TB
# PLAN.md Step 3.3
# ⚠️  IRREVERSIBLE — only run after new VM is confirmed working AND VM is unregistered

$path = "K:\DebianVm\Bookworm"

if (-not (Test-Path $path)) { Write-Host "Path $path not found — already deleted?"; exit }

$size = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Write-Host "⚠️  About to permanently delete: $path"
Write-Host "   Size: $([math]::Round($size/1GB,2)) GB across $(((Get-ChildItem $path -Recurse -File).Count)) files"
Write-Host ""
Write-Host "Pre-flight checks:"
Write-Host "  1. New HA VM running on C: and accessible at https://millcreek.duckdns.org:8123 ?"
Write-Host "  2. Bookworm unregistered from VirtualBox (remove_old_vm.ps1 completed) ?"
Write-Host "  3. HA backup confirmed on X:\HABackups ?"
Write-Host ""
$confirm = Read-Host "Type DELETE to confirm permanent deletion"
if ($confirm -ne "DELETE") { Write-Host "Aborted."; exit }

Write-Host "Taking ownership and deleting..."
Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile -Command `"takeown /f '$path' /r /d y | Out-Null; icacls '$path' /grant '$env:USERNAME`:(F)' /t /q | Out-Null; Remove-Item '$path' -Recurse -Force; Write-Host DONE`""

if (-not (Test-Path $path)) {
    Write-Host "✅ Deleted successfully"
    Get-PSDrive K | Select-Object @{N='K_Free_GB';E={[math]::Round($_.Free/1GB,1)}}
} else {
    Write-Host "⚠️  Some files may remain — check $path manually"
}
