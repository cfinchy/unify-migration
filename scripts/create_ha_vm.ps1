# Create new HomeAssistant-C VirtualBox VM on C: drive
# PLAN.md Step 2.2
# Run AFTER debian ISO is downloaded

$vbm   = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$name  = "HomeAssistant-C"
$vdi   = "C:\VMs\HA\HomeAssistant-C.vdi"
$iso   = "C:\VMs\HA\debian-12.9.0-amd64-netinst.iso"
$mac   = "080027D31560"   # Same as old Bookworm VM — keeps IP 10.176.1.240

if (-not (Test-Path $iso)) { Write-Error "ISO not found at $iso — run download_debian.ps1 first"; exit 1 }

Write-Host "Creating VM: $name"

# Create VM
& $vbm createvm --name $name --ostype Debian_64 --register

# Set RAM, CPUs, firmware
& $vbm modifyvm $name --memory 4096 --cpus 2 --boot1 dvd --boot2 disk --boot3 none
& $vbm modifyvm $name --firmware bios --graphicscontroller vmsvga --vram 16

# Network: bridged, same MAC as old VM
& $vbm modifyvm $name --nic1 bridged --bridgeadapter1 "Intel(R) Wi-Fi 6 AX201 160MHz" --macaddress1 $mac

# Create 60GB dynamic VDI on C:
Write-Host "Creating 60GB VDI at $vdi ..."
& $vbm createmedium disk --filename $vdi --size 61440 --format VDI --variant Standard

# Add SATA controller and attach VDI
& $vbm storagectl $name --name "SATA" --add sata --controller IntelAhci --portcount 2
& $vbm storageattach $name --storagectl "SATA" --port 0 --device 0 --type hdd --medium $vdi

# Add IDE controller for DVD
& $vbm storagectl $name --name "IDE" --add ide
& $vbm storageattach $name --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium $iso

Write-Host ""
Write-Host "✅ VM '$name' created."
Write-Host "MAC address: $mac (matches old VM — IP .240 will be preserved)"
Write-Host ""
Write-Host "Start the VM in VirtualBox and complete the Debian installer:"
Write-Host "  - Hostname: homeassistant"
Write-Host "  - No desktop environment"
Write-Host "  - SSH server: YES"
Write-Host "  - Standard system utilities: YES"
Write-Host ""
Write-Host "To start headless: & '$vbm' startvm '$name' --type headless"
