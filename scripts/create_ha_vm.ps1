# Create new HomeAssistant-C VirtualBox VM on C: drive
# PLAN.md Step 2.2
# Run AFTER debian ISO is downloaded
#
# STRATEGY: Uses a TEMP MAC so the new VM gets a different IP from DHCP.
# The old Bookworm VM (MAC 080027D31560) keeps running at 10.176.1.240 during
# the entire setup, install, and verify phase. Only run cutover_vm.ps1 when
# the new VM is confirmed fully working. That script does the atomic MAC swap.

$vbm   = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$name  = "HomeAssistant-C"
$vdi   = "C:\VMs\HA\HomeAssistant-C.vdi"
$iso   = "C:\VMs\HA\debian-12.9.0-amd64-netinst.iso"
$mac   = "080027FFFFFE"   # TEMP MAC - NOT the production MAC (080027D31560)

if (-not (Test-Path $iso)) { Write-Error "ISO not found at $iso -- run download_debian.ps1 first"; exit 1 }

Write-Host "Creating VM: $name (temp MAC $mac -- old HA remains at .240)"

# Create VM
& $vbm createvm --name $name --ostype Debian_64 --register

# Set RAM, CPUs, firmware
& $vbm modifyvm $name --memory 4096 --cpus 2 --boot1 dvd --boot2 disk --boot3 none
& $vbm modifyvm $name --firmware bios --graphicscontroller vmsvga --vram 16

# Network: bridged, TEMP MAC (old VM still owns 080027D31560 and .240)
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
Write-Host " VM '$name' created with TEMP MAC $mac"
Write-Host "   The new VM will get a different DHCP IP -- find it with:"
Write-Host "   & '$vbm' guestproperty get '$name' /VirtualBox/GuestInfo/Net/0/V4/IP"
Write-Host "   (only available after VirtualBox Guest Additions installed)"
Write-Host "   Or: check UniFi DHCP leases at https://192.168.0.1"
Write-Host ""
Write-Host "Start the VM in VirtualBox and complete the Debian installer:"
Write-Host "  - Hostname: homeassistant"
Write-Host "  - No desktop environment"
Write-Host "  - SSH server: YES"
Write-Host "  - Standard system utilities: YES"
Write-Host ""
Write-Host "  DO NOT run cutover_vm.ps1 until new HA is fully verified!"
Write-Host "To start: & '$vbm' startvm '$name' --type gui"
