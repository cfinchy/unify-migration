# mount_nas.ps1 — map W:/X: NAS shares for SSH-initiated scripts
# Reads password from nas.creds (gitignored, must exist locally)
# Dot-source this before any script that accesses W: or X:
#   . "$PSScriptRoot\mount_nas.ps1"
# Call Dismount-Nas at the end to clean up.

$CredsFile = Join-Path (Split-Path $PSScriptRoot) "nas.creds"
if (-not (Test-Path $CredsFile)) {
    Write-Error "nas.creds not found at $CredsFile — create it with just the NAS password on one line"
    exit 1
}
$NasPass = (Get-Content $CredsFile -Raw).Trim()
$NasUser = "cfinchy"
$NasHost = "192.168.0.124"

function Mount-Nas {
    foreach ($map in @(
        @{Letter="W"; Share="Personal-Drive"},
        @{Letter="X"; Share="HABackups"}
    )) {
        $letter = $map.Letter + ":"
        if (-not (Test-Path $letter)) {
            net use $letter "\\$NasHost\$($map.Share)" $NasPass /user:$NasUser | Out-Null
            Write-Host "Mounted $letter -> \\$NasHost\$($map.Share)"
        } else {
            Write-Host "$letter already mapped — skipping"
        }
    }
}

function Dismount-Nas {
    foreach ($letter in @("W:", "X:")) {
        net use $letter /delete /yes 2>$null | Out-Null
    }
    Write-Host "NAS shares unmounted"
}
