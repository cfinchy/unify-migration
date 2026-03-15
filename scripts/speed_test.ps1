# speed_test.ps1 — Measure H: -> NAS transfer speed and estimate drain times
# PLAN.md Step R2 (run before committing to a drain order)

. "$PSScriptRoot\mount_nas.ps1"; Mount-Nas   # mounts W: and X: from nas.creds if not already mapped

New-Item -ItemType Directory -Path "C:\projects\unify-migration\logs" -Force | Out-Null
New-Item -ItemType Directory -Path "W:\SpeedTest" -Force | Out-Null

# Pick a representative single file from H: (~300 MB — large enough for accuracy, small enough to finish quickly)
$file   = "H:\c drive nook\Users\chris\AppData\Roaming\Apple Computer\MobileSync\Backup\00008030-000C6DCA2190802E\Manifest.db"
$dir    = Split-Path $file
$fname  = Split-Path $file -Leaf
$sizeMB = [math]::Round((Get-Item $file).Length / 1MB, 2)

Write-Host "=== NAS Speed Test ==="
Write-Host "File   : $fname"
Write-Host "Size   : $sizeMB MB"
Write-Host "Source : H:"
Write-Host "Dest   : W:\SpeedTest (NAS Personal-Drive)"
Write-Host "Using same robocopy flags as drain scripts..."
Write-Host ""

$elapsed = Measure-Command {
    robocopy $dir "W:\SpeedTest" $fname /COPYALL /R:1 /W:1 /NP
}

$secs        = [math]::Round($elapsed.TotalSeconds, 1)
$speed_MBs   = [math]::Round($sizeMB / $elapsed.TotalSeconds, 2)   # MB/s
$speed_Mbps  = [math]::Round($speed_MBs * 8, 1)                    # Megabits/s

Write-Host "=== Result ==="
Write-Host "Time   : $secs seconds"
Write-Host "Speed  : $speed_MBs MB/s  ($speed_Mbps Mbps)"
Write-Host ""
Write-Host "=== Drain Time Estimates (at $speed_MBs MB/s) ==="
@(
    [PSCustomObject]@{ Label="H: full drain  (~3,358 GB)";     GB=3358 },
    [PSCustomObject]@{ Label="G: full drain  (~4,192 GB)";     GB=4192 },
    [PSCustomObject]@{ Label="K: delta sync  (~2,700 GB new)"; GB=2700 }
) | ForEach-Object {
    $hrs  = [math]::Round(($_.GB * 1024) / $speed_MBs / 3600, 1)
    $days = [math]::Round($hrs / 24, 1)
    Write-Host ("  " + $_.Label + " : ~$hrs hours (~$days days) unattended")
}

Write-Host ""
Write-Host "Note: robocopy is single-threaded. Actual drain may be slower due to"
Write-Host "many small files (higher overhead per file than this single large-file test)."

# Save result to log
$logLine = "$(Get-Date -Format 'yyyy-MM-dd HH:mm') | $sizeMB MB | ${secs}s | $speedMBps MB/s | $speedMbps Mbps"
Add-Content "C:\projects\unify-migration\logs\speedtest.log" $logLine

# Clean up test file
Remove-Item "W:\SpeedTest" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Test file cleaned up. Log: C:\projects\unify-migration\logs\speedtest.log"
