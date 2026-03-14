# Download Debian 12.9 Bookworm netinst ISO to C:\VMs\HA\
# PLAN.md Step 2.1

$dest = "C:\VMs\HA\debian-12.9.0-amd64-netinst.iso"
New-Item -ItemType Directory -Path "C:\VMs\HA" -Force | Out-Null

if (Test-Path $dest) {
    Write-Host "Already downloaded: $dest ($([math]::Round((Get-Item $dest).Length/1MB,0)) MB)"
    exit 0
}

Write-Host "Downloading Debian 12.9 Bookworm netinst (~700 MB)..."
Start-BitsTransfer -Source "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso" -Destination $dest
Write-Host "Done: $dest ($([math]::Round((Get-Item $dest).Length/1MB,0)) MB)"
