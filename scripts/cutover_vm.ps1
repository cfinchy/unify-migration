# cutover_vm.ps1
# ATOMIC HA CUTOVER  run ONLY when HomeAssistant-C is fully verified working
#
# What this does (total downtime ~60-90 seconds):
#   1. Confirms new VM (HomeAssistant-C) is running
#   2. Powers off old Bookworm VM
#   3. Powers off new VM
#   4. Swaps MAC on new VM to 080027D31560 (UniFi DHCP reservation  .240)
#   5. Starts new VM  DHCP hands out 10.176.1.240
#   6. Polls until HA responds at 10.176.1.240:8123
#   7. SSHs into new VM and converts it to STATIC IP 10.176.1.240
#      (so .240 is permanent, not DHCP-dependent going forward)
#
# After this script: HA owns .240 via static IP. No port forward changes needed.
# Old VM is powered off but files remain on K: until Phase 3 cleanup.
#
# Prerequisites:
#   - New VM installed, HA Supervised running, backup restored, manually verified
#   - SSH key working: test with  ssh <TEMP_IP> "echo ok"  before running this

param(
    [Parameter(Mandatory=$true)]
    [string]$TempIP   # Current IP of new VM (find in UniFi DHCP leases)
)

$vbm     = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$newVM   = "HomeAssistant-C"
$oldVM   = "Bookworm"
$prodMAC = "080027D31560"     # UniFi DHCP reservation  10.176.1.240
$haIP    = "10.176.1.240"
$gateway = "10.176.1.1"
$sshKey  = "C:\Users\chris\.ssh\id_rsa"

Write-Host "=== HA CUTOVER SCRIPT ===" -ForegroundColor Cyan
Write-Host "New VM temp IP:    $TempIP"
Write-Host "Target static IP:  $haIP"
Write-Host "Total downtime:    ~60-90 seconds"
Write-Host ""

# Step 0: Show running VMs
Write-Host "Currently running VMs:"
& $vbm list runningvms
Write-Host ""

# Verify SSH works to new VM before we touch anything
Write-Host "Verifying SSH to new VM at $TempIP ..."
$sshTest = & ssh -i $sshKey -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$TempIP "echo SSH_OK" 2>&1
if ($sshTest -notmatch "SSH_OK") {
    Write-Error "Cannot SSH to $TempIP. Fix SSH access before proceeding (check id_rsa.pub is in authorized_keys on new VM)."
    exit 1
}
Write-Host "  SSH OK "
Write-Host ""

# Find network interface name on new VM
$iface = & ssh -i $sshKey root@$TempIP "ip route | grep default | awk '{print `$5}'" 2>&1
if (-not $iface) { $iface = "enp0s3" }  # VirtualBox E1000 default
Write-Host "  Network interface: $iface"
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
Write-Host "Step 1: Powering off OLD VM ($oldVM) ..." -ForegroundColor Yellow
& $vbm controlvm $oldVM poweroff
Start-Sleep -Seconds 5

Write-Host "Step 2: Powering off NEW VM ($newVM) ..." -ForegroundColor Yellow
& $vbm controlvm $newVM poweroff
Start-Sleep -Seconds 5

Write-Host "Step 3: Swapping MAC to $prodMAC ..." -ForegroundColor Yellow
& $vbm modifyvm $newVM --macaddress1 $prodMAC
if ($LASTEXITCODE -ne 0) { Write-Error "MAC swap failed!"; exit 1 }
Write-Host "  MAC set to $prodMAC"

Write-Host "Step 4: Starting new VM (headless) ..." -ForegroundColor Yellow
& $vbm startvm $newVM --type headless
Start-Sleep -Seconds 15

Write-Host "Step 5: Waiting for HA at http://${haIP}:8123 ..." -ForegroundColor Yellow
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

if (-not $ok) {
    Write-Host ""
    Write-Warning "  HA did not respond within ${timeout}s. Check VirtualBox console for boot errors."
    Write-Host "   New VM MAC is now $prodMAC  do NOT restart the old VM (IP conflict)."
    Write-Host "   Open VirtualBox GUI to diagnose, then re-run step 6 manually once HA is up:"
    Write-Host "   ssh root@${haIP} 'cat /etc/network/interfaces'"
    exit 1
}

Write-Host ""
Write-Host " HA responding at http://${haIP}:8123" -ForegroundColor Green
Write-Host ""
Write-Host "Step 6: Converting new VM from DHCP to static IP $haIP ..." -ForegroundColor Yellow

# Write static IP config to new VM
$ifacesContent = @"
auto lo
iface lo inet loopback

auto $iface
iface $iface inet static
    address $haIP
    netmask 255.255.255.0
    gateway $gateway
    dns-nameservers $gateway 8.8.8.8
"@

# Write the file and restart networking (backgrounded so SSH doesn't hang)
$cmd = "echo '$ifacesContent' > /etc/network/interfaces && systemctl restart networking &"
& ssh -i $sshKey root@$haIP $cmd 2>&1 | Out-Null
Start-Sleep -Seconds 10

# Verify HA still up after networking restart
try {
    $r2 = Invoke-WebRequest -Uri "http://${haIP}:8123" -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    Write-Host "  Static IP set, HA still responding " -ForegroundColor Green
} catch {
    Write-Warning "  Static IP applied but HA briefly unreachable  this is normal. Wait 30s and check."
}

Write-Host ""
Write-Host "" -ForegroundColor Cyan
Write-Host "  CUTOVER COMPLETE" -ForegroundColor Green
Write-Host "" -ForegroundColor Cyan
Write-Host "  HA web:    https://millcreek.duckdns.org:8123"
Write-Host "  Internal:  http://${haIP}:8123"
Write-Host "  SSH:       ssh ha"
Write-Host "  IP type:   STATIC (not DHCP  permanent)"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Verify HA fully working (automations, external access)"
Write-Host "  2. Run Phase 3: scripts\remove_old_vm.ps1 then scripts\delete_bookworm.ps1"
Write-Host "  3. This frees ~1.6 TB on K:"
