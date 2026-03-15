# start_drain.ps1 - Register and start a drain as a Windows Scheduled Task
# The task runs completely independently of the SSH session.
# Robocopy logs to C:\projects\unify-migration\logs\drain_<drive>.log
#
# Usage (from SSH):
#   powershell -ExecutionPolicy Bypass -File ...\start_drain.ps1 -Drive H
#   powershell -ExecutionPolicy Bypass -File ...\start_drain.ps1 -Drive G
#   powershell -ExecutionPolicy Bypass -File ...\start_drain.ps1 -Drive K
#
# Check progress:
#   powershell -ExecutionPolicy Bypass -File ...\check_drain.ps1

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("H","G","K")]
    [string]$Drive
)

$ProjectDir = "C:\projects\unify-migration"
$LogDir     = "$ProjectDir\logs"
$CredsFile  = "$ProjectDir\nas.creds"
$TaskName   = "UnifyMigration-Drain$Drive"

# Validate prereqs
if (-not (Test-Path $CredsFile)) {
    Write-Error "nas.creds not found at $CredsFile"
    exit 1
}

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

# Build robocopy arguments per drive
switch ($Drive) {
    "H" {
        $Source = "H:\"
        $Dest   = "\\192.168.0.124\Personal-Drive\DriveArchive\H"
        $Log    = "$LogDir\drain_h.log"
        $XDirs  = '"H:\System Volume Information"'
    }
    "G" {
        $Source = "G:\"
        $Dest   = "\\192.168.0.124\Personal-Drive\DriveArchive\G"
        $Log    = "$LogDir\drain_g.log"
        $XDirs  = '"G:\System Volume Information"'
    }
    "K" {
        $Source = "K:\"
        $Dest   = "\\192.168.0.124\Personal-Drive\K backup millcreek"
        $Log    = "$LogDir\drain_k.log"
        $XDirs  = '"K:\DebianVm" "K:\System Volume Information"'
    }
}

# The task action: a small inline PS script that reads nas.creds, mounts the UNC
# path directly (no drive letter needed), and runs robocopy.
# Using UNC paths avoids the drive-letter-per-session limitation entirely.
$InlineScript = @"
`$pass = (Get-Content '$CredsFile' -Raw).Trim()
net use '$Dest' `$pass /user:cfinchy 2>&1 | Out-Null
New-Item -ItemType Directory -Path '$Dest' -Force | Out-Null
robocopy '$Source' '$Dest' /E /COPY:DAT /DCOPY:DAT /Z /R:10 /W:30 /TS /NP /XD $XDirs /LOG+:'$Log'
"@

$EncodedScript = [Convert]::ToBase64String(
    [Text.Encoding]::Unicode.GetBytes($InlineScript)
)

# Deregister any existing task with the same name
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Register new task - runs as current user, highest privileges
$Action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -NonInteractive -EncodedCommand $EncodedScript"
$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Days 60) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 5) `
    -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName $TaskName -Action $Action -Settings $Settings `
    -RunLevel Highest -Force | Out-Null

# Start it immediately
Start-ScheduledTask -TaskName $TaskName

$status = (Get-ScheduledTask -TaskName $TaskName).State
Write-Host ""
Write-Host "=== Drain $Drive started ==="
Write-Host "Task name : $TaskName"
Write-Host "Source    : $Source"
Write-Host "Dest      : $Dest"
Write-Host "Log       : $Log"
Write-Host "Status    : $status"
Write-Host ""
Write-Host "The task runs independently of this SSH session."
Write-Host "Check progress: powershell -ExecutionPolicy Bypass -File $ProjectDir\scripts\check_drain.ps1"
