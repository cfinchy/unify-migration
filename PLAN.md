# Unify Migration  Remote Implementation Plan

> **For Claude:** Open this repo as a VS Code workspace. Read `memory.md` first for full context,
> then `docs/Drive_Cleanup_Log.md` for history. Execute tasks in order below. Check off each item.
> All scripts are in `scripts/`. Token is in Windows Credential Manager  see memory.md for retrieval.

*Last updated: March 15, 2026*

---

## Current State (as of March 16, 2026 13:24 EDT — Phase R in progress)

### Drain Progress
| Drive | Status | Progress | Errors | Last Update | ETA |
|-------|--------|----------|--------|-------------|-----|
| **G:** | Running | 739 MB / 4,192 GB (0.02%) | 23 | 0.7h ago | ~26 days |
| **H:** | Running | Starting | 7 | 0.7h ago | ~21 days |
| **K:** | Complete | 284 GB / 284 GB ✅ | 0 | 14.5h ago | ~1-2 days (live HA VM: 8.179 GB) |

**Run time:** Started Mar 15 18:58 UTC, ~19 hours elapsed  
**Speed:** ~1.93 MB/s expected (currently impacted by NAS outage recovery)

### Recovery & Monitoring
- ✅ **NAS outage:** Dream Machine down 10:42-12:48 UTC, remounted and recovered
- ✅ **Monitoring active:** `monitor_drain.ps1` running every 30 min, iPhone notifications working
- ✅ **Auto-remount:** NAS reconnects automatically if connection drops
- ✅ **Logging:** All alerts logged to `C:\projects\unify-migration\logs\monitor.log`

### Infrastructure Status
- C: has ~78 GB free (sufficient for 60 GB new HA VM)
- HA running at `https://millcreek.duckdns.org:8123` (VirtualBox Bookworm VM, `10.176.1.240`)
- Debian 12.9 ISO downloaded (`C:\VMs\HA\debian-12.9.0-amd64-netinst.iso`)

---

## Migration Strategy: Parallel Install  Atomic Cutover

**Goal:** Keep HA at `10.176.1.240` running continuously until the NEW VM is 100% verified.
Downtime is ~60-90 seconds at the very end (`cutover_vm.ps1`).

```
Old VM (Bookworm, K:, MAC 080027D31560, IP .240)  STAYS RUNNING  power off
                                                                                        (~90s)
New VM (HomeAssistant-C, C:, TEMP MAC, random IP)  install  verify  cutover  STATIC .240 
```

- New VM uses **temp MAC `080027FFFFFE`** during setup  gets a random DHCP IP (not `.240`)
- `cutover_vm.ps1` does two things atomically:
  1. **MAC swap**  UniFi DHCP hands `.240` to the new VM (same reservation, same IP, no router changes)
  2. **Static IP**  immediately SSHs in and writes `10.176.1.240` as a static IP in `/etc/network/interfaces`
     so `.240` is permanently owned by the new VM  independent of DHCP going forward
- **No port forwarding changes needed**  `.240` never moves, all UniFi forwards keep working
- **DO NOT run `cutover_vm.ps1` until new HA is fully verified at its temp IP**

---

## Progress Tracking (Phase R)

### Checkpoints
| Date/Time | G: Progress | H: Progress | K: Progress | Notes |
|-----------|-------------|-------------|-------------|-------|
| 2026-03-15 18:58 | Started | Not started | Not started | Drains initiated |
| 2026-03-16 10:42 | ~500 MB | Starting | ~280 GB | Dream Machine outage, NAS disconnected |
| 2026-03-16 12:48 | NAS recovered | NAS recovered | NAS recovered | Remounted, jobs resuming |
| 2026-03-16 13:24 | 739 MB (0.02%) | In progress | 284 GB ✅ complete | Monitoring verified, iPhone notifications working |

### Key Metrics
- **Days elapsed:** 0.8 days
- **Estimated total time:** 68 days
- **Target completion:** ~May 22, 2026
- **Major milestones:**
  - K: complete (no more changes to HA VM)
  - H: expected ~Apr 6, 2026
  - G: expected ~Apr 11, 2026

---

## Monitoring Setup (Phase R) — Dual-Tier System

### Architecture

**Tier 1: Quick Health Check** (every 5 minutes)
- Fast test of W:, X:, Y: drive letters
- Auto-remounts if disconnected
- No alerts, no overhead
- **Catches mount failures in ~5 minutes** (vs 30 min with just full monitor)

**Tier 2: Full Drain Monitor** (every 30 minutes)
- Detailed drain task status
- Error/stall detection
- iPhone notifications on problems
- Logs to `monitor.log`

### Current Status

```
✓ UnifyMigration-QuickHealthCheck  (every 5 min)
✓ UnifyMigration-Monitor           (every 30 min)
✓ UnifyMigration-DrainG            (running)
✓ UnifyMigration-DrainH            (running)
✓ UnifyMigration-DrainK            (complete, ready)
```

### Manual Commands

| Task | Command |
|------|---------|
| **Check drain status** | `ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\check_drain.ps1"` |
| **View quick health log** | `ssh millcreek-win "Get-Content C:\projects\unify-migration\logs\health_check.log -Tail 30"` |
| **View full monitor log** | `ssh millcreek-win "Get-Content C:\projects\unify-migration\logs\monitor.log -Tail 50"` |
| **Manual remount** | `ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\mount_nas.ps1"` |

### Why This Works

The drain jobs stalled for **3.6 hours** when NAS went down (13:29-17:01) because:
- Original 30-min monitor missed the failure for too long
- SMB connections timeout/drop for various reasons

**Dual-tier approach:**
- **5-min quick check** catches issues before they kill drains
- **30-min full monitor** handles alerting and detailed logging
- **Auto-remount** keeps connections alive without human intervention
- **iPhone alerts** notify you of persistent problems

---

## Task Checklist

### Phase 0 — Remote Access Setup (required before continuing from home)
- [x] **0.1** Windows box IP confirmed: `10.176.1.110`
- [x] **0.2** OpenSSH Server enabled on Windows box (was already installed, started and set to Automatic)
- [x] **0.3** UniFi port forward added (ext:2222 → 10.176.1.110:22) + Optimum CPE forward (2222 → 192.168.1.209)
- [x] **0.4** `millcreek-win` added to `~/.ssh/config` on Proxmox VM
- [x] **0.5** SSH confirmed: hostname=`DESKTOP-879JK9R`, user=`desktop-879jk9r\chris`
- [x] **0.6** Script execution confirmed — `check_space.ps1` ran successfully remotely

### Phase 1  Verify Backup & Prepare C:  COMPLETE
- [x] **1.1** Backup `9ff1dfa6.tar` (4.91 GB) confirmed on `X:\HABackups`
- [x] **1.2** C: free space ~76 GB (sufficient for 60 GB VDI)
- [x] **1.3** Camera Roll move not needed  space already sufficient

### Phase R — Remote Drain (4-week window: do from home while physically away)

> **Context**: Cannot physically visit Millcreek for 4 weeks. Use this window to drain
> Passport drives (G:, H:, K:) to the NAS over SSH. HA stays live on K: throughout.
> When arriving in 4 weeks, G: and H: will be fully drained and ready to eject; K: will
> be drained except for `K:\DebianVm\Bookworm\` (freed in Phase 3).

- [ ] **R1** — Verify HA backup is current before touching anything:
  ```bash
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\check_backup.ps1"
  ```
  Confirm a backup exists on `X:\HABackups` dated ≤ 3 days ago. If stale, trigger a manual
  backup from https://millcreek.duckdns.org:8123 → Settings → Backup → Create.

- [ ] **R2** — Audit NAS first (from home Proxmox VM — fast local I/O), then inventory source drives:
  ```bash
  # 1. NAS audit — shows what's already on W:\ before any drain scripts run
  #    Fast default (item counts); add MILLCREEK_SIZES=1 for GB figures (slow)
  bash /tmp/unify-migration/scripts/millcreek-nas-audit.sh
  # Report lands at: ~/.local/share/millcreek-audit/reports/nas-audit-<ts>.md

  # 2. Source drive inventories (runs on Windows box via SSH)
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\inventory_k.ps1"
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\inventory_h.ps1"
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\inventory_g.ps1"

  # 3. Space summary
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\check_space.ps1"
  ```

  > **Transfer speed**: ~1.93 MB/s (15.4 Mbps — Millcreek ISP upload is the bottleneck).
  > Estimates: H: ~21 days, G: ~26 days, K: delta ~17 days (less if many files already in NAS backup).
  > Drains run as Windows Scheduled Tasks — completely independent of SSH sessions.
  > Robocopy skips already-copied files on restart, so any interruption is safe to resume.
  > **Recommended order**: G: first (longest, start immediately), then H:, then K:.

- [ ] **R3** — Start G: drain first (longest — ~26 days, start immediately):
  ```bash
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\start_drain.ps1 -Drive G"
  ```

- [ ] **R4** — Start H: drain (can run after G: completes, or earlier if bandwidth allows):
  ```bash
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\start_drain.ps1 -Drive H"
  ```
  H: drain includes `H:\old HA backups` and `H:\pcpcpcDownloads` — both are duplicates of data
  already in `K backup millcreek` on the NAS, but we copy anyway for completeness.

- [ ] **R5** — Start K: drain (excludes `K:\DebianVm\` — safe while HA is live):
  ```bash
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\start_drain.ps1 -Drive K"
  ```
  K: delta-syncs to `\\NAS\Personal-Drive\K backup millcreek` — only new/changed files transferred.
  `/XO` flag prevents overwriting newer NAS copies with CRC-damaged K: source files.
  **Do NOT eject K:** — the running HA VM lives at `K:\DebianVm\Bookworm\`. K: stays until Phase 3.

- [ ] **R6** — Set up automated monitoring (optional but recommended for long job):
  
  **Option A: Passive checking (manual, always works)**
  ```bash
  # Check drain status anytime from home
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\check_drain.ps1"
  ```
  Shows: Task state, robocopy progress, error count, last log update time, active processes.
  
  **Option B: Automated monitoring every 30 min (sends push notifications)**
  ```bash
  # First time only: register the monitor task
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\start_monitor.ps1"
  ```
  This will:
  - Run `monitor_drain.ps1` every 30 minutes
  - Check if NAS is reachable
  - Auto-remount if connection drops
  - Send push notifications to your iPhone on problems (NAS unreachable, task stalled, new errors)
  - Log everything to `C:\projects\unify-migration\logs\monitor.log`
  
  **After setup:** Just check the log occasionally:
  ```bash
  ssh millcreek-win "Get-Content -Path C:\projects\unify-migration\logs\monitor.log -Tail 20"
  ```

- [ ] **R7** — Verify NAS after each drive completes (from home):
  ```bash
  # Check what's been transferred
  ssh docker-host "ls -lh /mnt/nas/Personal-Drive/DriveArchive/"     # G: and H: destinations
  ssh docker-host "ls -lh /mnt/nas/Personal-Drive/K\ backup\ millcreek/" | tail -20  # K: destination
  ```

- [ ] **R8** — Monitor HA health weekly (repeat throughout 4-week window):
  ```bash
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\check_backup.ps1"
  # Also verify HA web UI: https://millcreek.duckdns.org:8123
  ```
  
  **If NAS goes down again (detected via monitor log or manual check):**
  ```bash
  # Remount immediately — drain jobs will resume
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\mount_nas.ps1"
  ```

---

> ⏸️ **PHYSICAL VISIT REQUIRED FOR EVERYTHING BELOW**
>
> Phases 2–7 require being physically at Millcreek. By the time you arrive:
> - G: and H: will be fully drained to NAS and ready to eject
> - K: will be drained except `K:\DebianVm\Bookworm\` (HA is still running there)
> - Phase 2 requires VirtualBox GUI (Debian installer) — cannot be done over SSH alone
> - Phase 3 deletes `K:\DebianVm\Bookworm\` — only after new VM is 100% verified

---

### Phase 2  Create Fresh HA Supervised VM on C: (parallel, old HA stays live)

>  This is **Home Assistant Supervised on Debian Bookworm**  NOT HAOS.
> New VM runs in parallel with temp MAC until cutover_vm.ps1 is called.

- [x] **2.0** Old VM MAC confirmed: `08:00:27:D3:15:60`, bridged to Intel AX201 Wi-Fi
- [x] **2.0** Backup `9ff1dfa6.tar` on `X:\HABackups` 
- [x] **2.1** Debian 12.9 ISO downloaded  `C:\VMs\HA\debian-12.9.0-amd64-netinst.iso` 
- [ ] **2.2** Create new VirtualBox VM — run `scripts\create_ha_vm.ps1` remotely:
  ```bash
  ssh millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\create_ha_vm.ps1"
  ```
  - Name: `HomeAssistant-C`, Debian 64-bit, 4096 MB RAM
  - 60 GB dynamic VDI at `C:\VMs\HA\HomeAssistant-C.vdi`
  - **TEMP MAC: `080027FFFFFE`**  old VM keeps `.240` while new VM is being set up
  - Bridged to Intel AX201 Wi-Fi
- [ ] **2.3** Start VM in VirtualBox GUI — connect via RealVNC to the Windows desktop,
  open VirtualBox, start `HomeAssistant-C` normally, complete Debian installer interactively.
  RealVNC cloud relay handles the graphical session — no port forward or VRDE needed.

  Complete minimal install:
  - No desktop environment
  - SSH server, standard system utilities
  - Hostname: `homeassistant`
  - **Note the IP** after first boot — check UniFi DHCP leases at unifi.ui.com → Network → Clients
    (it will NOT be `.240` — that stays on the old VM)
  - **Paste your `id_rsa.pub` into authorized_keys** during or after install so SSH works:
    ```bash
    mkdir -p ~/.ssh && echo "PASTE_CONTENTS_OF_C:\Users\chris\.ssh\id_rsa.pub" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    ```

  If RealVNC session is too slow for the installer:
  - Alternative: enable VRDE and tunnel via SSH:
    ```bash
    ssh millcreek-win "& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' modifyvm 'HomeAssistant-C' --vrde on --vrdeport 5555"
    ssh -L 5555:localhost:5555 millcreek-win   # keep open
    xfreerdp /v:localhost:5555                 # in another terminal
    ```
    After install: `VBoxManage modifyvm 'HomeAssistant-C' --vrde off`

> ⏸️ **PAUSE POINT** — Stop here. Confirm Debian is booted and reachable before continuing.
> Verify:
> - VM shows a login prompt in VirtualBox / RealVNC
> - New VM has a temp DHCP IP (visible at unifi.ui.com → Network → Clients)
> - `ssh millcreek-win` then `ssh root@<TEMP_IP>` drops you into a shell
> Once confirmed, proceed to 2.4 to install HA Supervised.

- [ ] **2.4** SSH into new VM at its temp IP via jump through Windows box:
  ```bash
  ssh millcreek-win
  # then from Windows PowerShell:
  ssh root@<TEMP_IP>
  ```
  Or use ProxyJump from Proxmox VM directly:
  ```
  Host millcreek-debian-new
    HostName <TEMP_IP>
    User root
    ProxyJump millcreek-win
  ```
  Then install HA Supervised:
  ```bash
  apt update && apt install -y curl
  curl -sL https://raw.githubusercontent.com/home-assistant/supervised-installer/main/installer.sh \
    | bash -s -- -m generic-x86-64
  ```
- [ ] **2.5** Wait ~5 min for Supervisor to initialize. Access at `http://<TEMP_IP>:8123`
- [ ] **2.6** Restore backup: Settings  Backup  Upload `9ff1dfa6.tar` from `X:\HABackups`
  -  After restore, HA will restart. Wait for it to come back at `http://<TEMP_IP>:8123`
- [ ] **2.7** Fully verify new HA at temp IP  take your time, days if needed, old HA still live:
  - All automations, integrations, devices visible 
  - DuckDNS add-on present (external URL will be wrong until cutover  that's expected) 
  - No errors in Supervisor logs 
- [ ] **2.8** Confirm SSH works via ProxyJump (Optimum CPE does not pass port 22 directly — must hop through Windows box):
  ```bash
  ssh -J millcreek-win root@<TEMP_IP>
  ```
- [ ] **2.9** CUTOVER — run via interactive SSH session (script has Read-Host prompt):
  ```bash
  ssh -t millcreek-win "powershell -ExecutionPolicy Bypass -File C:\projects\unify-migration\scripts\cutover_vm.ps1 -TempIP <TEMP_IP>"
  ```
  The `-t` flag allocates a pseudo-TTY so the `Read-Host "Type YES"` prompt works correctly.

  The script will:
  - Verify SSH works to new VM before touching anything
  - Stop old Bookworm VM
  - Swap new VM MAC  `080027D31560`  UniFi DHCP hands it `10.176.1.240`
  - Start new VM, wait for HA to respond
  - SSH in and write `/etc/network/interfaces` with **static IP `10.176.1.240`**
  - After this: `.240` is permanent  no DHCP dependency, no port forward changes ever needed
  - Total downtime: ~60-90 seconds

### Phase 3  Decommission Old VM on K: (AFTER cutover confirmed working)

> By the time you reach this phase, H: and G: are fully drained to NAS (Phase R3/R4).
> K: is drained except for `K:\DebianVm\Bookworm\` (Phase R5). This phase frees that last ~1.6 TB.

- [ ] **3.1** Confirm new VM running stably at `.240` for at least 1 hour post-cutover
- [ ] **3.2** Remove old Bookworm VM from VirtualBox registry: `scripts\remove_old_vm.ps1`
- [ ] **3.3** Delete `K:\DebianVm\Bookworm\`  frees ~1.6 TB on K:
  - Run `scripts\delete_bookworm.ps1`
- [ ] **3.4** Verify K: free space after deletion

### Phase 4  Eject Passport Drives (all drain work done in Phase R)

> H: and G: are already fully drained (Phase R3/R4). K: is fully drained after Phase 3.3 deletes
> `K:\DebianVm\`. Verify NAS copies one final time, then eject all three drives.

- [ ] **4.1** Final NAS verification from home or locally:
  - `ls /mnt/nas/Personal-Drive/DriveArchive/` — confirm H\, G\, K\ all present
  - Spot-check a few large files from each drive
- [ ] **4.2** Eject H: — source data confirmed backed up to NAS in Phase R3
- [ ] **4.3** Eject G: — source data confirmed backed up to NAS in Phase R4
  - ⚠️ G: contains a Bullseye DebianVM copy — test it from NAS before ejecting if you plan to use it
- [ ] **4.4** Safely eject K:  all data now on NAS or C: (DebianVm deleted in Phase 3.3)

### Phase 5  Final Verification
- [ ] **5.1** Confirm HA running from C: only, no K:/G:/H: dependency
- [ ] **5.2** Update memory.md with completed passport removals
- [ ] **5.3** Commit final state to this repo

---

## Key Credentials & Access

| Resource | How to access |
|---|---|
| Windows box shell | `ssh millcreek-win` (see memory.md, Phase 0) |
| HA Token | Windows Credential Manager — `get_token.ps1` runs on Windows box via SSH |
| HA Web UI (live) | https://millcreek.duckdns.org:8123 |
| HA Web UI (new VM, temp) | `http://<TEMP_IP>:8123` — check UniFi DHCP leases at unifi.ui.com → Network → Clients |
| HA SSH (post-cutover) | `ssh ha` (Host ha = 10.176.1.240 in `C:\Users\chris\.ssh\config`) |
| UniFi admin (remote) | https://unifi.ui.com (cloud) — NOT 192.168.0.1 from home |
| DHCP leases (remote) | unifi.ui.com → Network → Clients |
| NAS Web UI | https://192.168.0.124/unifi-drive |
| NAS SMB | W: = Personal-Drive, X: = HABackups, Y: = FinchFamilyRoku |
| VirtualBox GUI | RealVNC (primary) or VRDE tunnel: `ssh -L 5555:localhost:5555 millcreek-win` → `xfreerdp /v:localhost:5555` |
| New VM temp IP | Check unifi.ui.com, or `ssh millcreek-win "& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' guestproperty get 'HomeAssistant-C' /VirtualBox/GuestInfo/Net/0/V4/IP"` |

---

## Important Constraints

- **DO NOT change the MAC on old Bookworm VM**  it must keep `.240` until cutover
- **DO NOT run `cutover_vm.ps1` early**  only after new HA fully verified at temp IP
- **DO NOT delete `K:\DebianVm\Bookworm` until new VM confirmed working at `.240`** (Phase 3.1)
- **No port forwarding changes needed**  `.240` never moves (MAC swap + static IP in cutover script)
- After cutover, `.240` is a **static IP on the Debian VM**  DHCP reservation can be left or deleted
- Windows Explorer instability noted  if Explorer crashes during file operations, reconnect remotely

---

## Notes

- **RealVNC Viewer** installed on Proxmox VM (`realvnc-vnc-viewer 7.15.1.18` at `/usr/bin/vncviewer`). Launch with `vncviewer` or from the app menu. Use this as bootstrap and fallback for any graphical work on the Windows desktop.
- **RealVNC vs SSH**: Once SSH + port forward is set up (Phase 0), prefer SSH for script execution (faster, scriptable, copy-pasteable). Use RealVNC for graphical steps (VirtualBox installer, checking Windows desktop state).
- **UniFi admin from home**: Always use https://unifi.ui.com — the LAN address `192.168.0.1` is unreachable from home.
