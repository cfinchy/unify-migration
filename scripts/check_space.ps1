# Check free space on all relevant drives
# PLAN.md Step 1.2

Write-Host "=== Drive Free Space ===" -ForegroundColor Cyan
Get-PSDrive C,E,G,H,K,W,X,Y -ErrorAction SilentlyContinue |
    Select-Object Name,
        @{N='Free_GB';E={[math]::Round($_.Free/1GB,1)}},
        @{N='Used_GB';E={[math]::Round($_.Used/1GB,1)}},
        @{N='Total_GB';E={[math]::Round(($_.Free+$_.Used)/1GB,1)}} |
    Format-Table -AutoSize

Write-Host "`n=== C: target: 60+ GB free for new HA VM ===" -ForegroundColor Yellow
$cFree = (Get-PSDrive C).Free/1GB
if ($cFree -lt 60) {
    Write-Host "⚠️  C: only $([math]::Round($cFree,1)) GB free — run move_camera_roll.ps1 first" -ForegroundColor Red
} else {
    Write-Host "✅ C: has $([math]::Round($cFree,1)) GB free — sufficient for new VM" -ForegroundColor Green
}
