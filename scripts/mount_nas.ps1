# mount_nas.ps1 - map W:/X: NAS shares for SSH-initiated scripts
# Reads password from nas.creds (gitignored, must exist locally at project root)
# Dot-source this before any script that accesses W: or X:
#   . "$PSScriptRoot\mount_nas.ps1"; Mount-Nas

$_CredsFile = "C:\projects\unify-migration\nas.creds"

function Mount-Nas {
    $pass = (Get-Content "C:\projects\unify-migration\nas.creds" -Raw).Trim()
    if (-not (Test-Path "W:")) {
        net use W: "\\192.168.0.124\Personal-Drive" $pass /user:cfinchy 2>&1 | Out-Null
        Write-Host "Mounted W: -> \\192.168.0.124\Personal-Drive"
    } else {
        Write-Host "W: already mapped - skipping"
    }
    if (-not (Test-Path "X:")) {
        net use X: "\\192.168.0.124\HABackups" $pass /user:cfinchy 2>&1 | Out-Null
        Write-Host "Mounted X: -> \\192.168.0.124\HABackups"
    } else {
        Write-Host "X: already mapped - skipping"
    }
}

function Dismount-Nas {
    net use W: /delete /yes 2>&1 | Out-Null
    net use X: /delete /yes 2>&1 | Out-Null
    Write-Host "NAS shares unmounted"
}

if (-not (Test-Path $_CredsFile)) {
    Write-Error "nas.creds not found at $_CredsFile - create it with the NAS password on one line"
    exit 1
}

# Execute the mount
Mount-Nas
