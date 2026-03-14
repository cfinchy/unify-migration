# cutover_vm.ps1
# ATOMIC HA CUTOVER  run ONLY when HomeAssistant-C is fully verified working
#
# What this does (total downtime ~30-60 seconds):
#   1. Confirms new VM (HomeAssistant-C) is running and HA responds
#   2. Powers off old Bookworm VM
#   3. Powers off new VM
#   4. Swaps MAC on new VM to 080027D31560 (production MAC)
#   5. Starts new VM
#   6. Polls until 10.176.1.240:8123 responds
#
# Prerequisites:
#   - New VM installed, HA Supervised running, backup restored, manually verified
#   - Run: . .\scripts\get_token.ps1  to set $token first (optional, for health check)

$vbm     = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$newVM   = "HomeAssistant-C"
$oldVM   = "Bookworm"         # Check exact name first with: & $vbm list runningvms
$prodMAC = "080027D31560"     # MAC that maps to DHCP reservation 10.176.1.240
$haIP    = "10.176.1.240"

Write-Host "=== HA CUTOVER SCRIPT ==="
Write-Host "This will briefly power off both VMs (~30-60 sec downtime)."
Write-Host ""

# Step 0: Show running VMs
Write-Host "Currently running VMs:"
& $vbm list runningvms
Write-Host ""

# Confirm
$confirm = Read-Host "Type YES to proceed with cutover"
if ($confirm -ne "YES") { Write-Host "Aborted."; exit 0 }

# Step 1: Check new VM is actually running
$running = & $vbm list runningvms
if ($running -notmatch $newVM) {
    Write-Error "HomeAssistant-C is not running! Start it and verify HA before cutting over."
    exit 1
}

Write-Host ""
Write-Host "Step 1: Powering off OLD VM ($oldVM)..."
& $vbm controlvm $oldVM poweroff
Start-Sleep -Seconds 5

Write-Host "Step 2: Powering off NEW VM ($newVM)..."
& $vbm controlvm $newVM poweroff
Start-Sleep -Seconds 5

Write-Host "Step 3: Swapping MAC to production MAC $prodMAC..."
& $vbm modifyvm $newVM --macaddress1 $prodMAC
if ($LASTEXITCODE -ne 0) { Write-Error "MAC swap failed!"; exit 1 }
Write-Host "  MAC set to $prodMAC"

Write-Host "Step 4: Starting new VM..."
& $vbm startvm $newVM --type headless
Start-Sleep -Seconds 10

Write-Host "Step 5: Waiting for HA at http://${haIP}:8123 ..."
$timeout = 180
$elapsed = 0
$ok = $false
while ($elapsed -lt $timeout) {
    try {
        $r = Invoke-WebRequest -Uri "http://${haIP}:8123" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -lt 500) { $ok = $true; break }
    } catch {}
    Start-Sleep -Seconds 5
    $elapsed += 5
    Write-Host "  ...${elapsed}s"
}

if ($ok) {
    Write-Host ""
    Write-Host " CUTOVER COMPLETE! HA is responding at http://${haIP}:8123"
    Write-Host "   External: https://millcreek.duckdns.org:8123"
    Write-Host "   SSH:      ssh ha"
    Write-Host ""
    Write-Host "Next: update PLAN.md Phase 3 (decommission old VM on K:)"
} else {
    Write-Host ""
    Write-Warning "  HA did not respond within ${timeout}s. Check VirtualBox console for boot errors."
    Write-Host "   New VM MAC is now $prodMAC -- do NOT restart the old VM (IP conflict)."
    Write-Host "   Open VirtualBox GUI to diagnose the boot."
}
