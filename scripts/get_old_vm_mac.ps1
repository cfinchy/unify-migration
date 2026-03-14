# Get MAC address of old Bookworm VM — needed to clone into new VM
# PLAN.md Step 2.2

$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
Write-Host "=== Bookworm VM Network Config ===" -ForegroundColor Cyan
& $vbm showvminfo "Bookworm" | Select-String "MAC|NIC|Adapter"
Write-Host "`nCopy the MAC address above into the new VM's network adapter settings"
Write-Host "In VirtualBox: VM Settings → Network → Adapter 1 → Advanced → MAC Address"
