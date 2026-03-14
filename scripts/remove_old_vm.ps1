# Remove old Bookworm VM from VirtualBox registry (does NOT delete files yet)
# PLAN.md Step 3.2
# Run ONLY after new HA VM is confirmed working

$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

Write-Host "Current Bookworm VM state:"
& $vbm showvminfo "Bookworm" | Select-String "State:"

$confirm = Read-Host "This will unregister Bookworm from VirtualBox (files stay on K: until delete_bookworm.ps1). Proceed? (yes/no)"
if ($confirm -ne "yes") { Write-Host "Aborted."; exit }

& $vbm unregistervm "Bookworm"
Write-Host "VM unregistered. Run delete_bookworm.ps1 to free the 1.6 TB on K:"
