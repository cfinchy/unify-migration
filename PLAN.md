# Unify Migration — Remote Implementation Plan

> **For Claude:** Open this repo as a VS Code workspace. Read `memory.md` first for full context,
> then `docs/Drive_Cleanup_Log.md` for history. Execute tasks in order below. Check off each item.
> All scripts are in `scripts/`. Token is in Windows Credential Manager — see memory.md for retrieval.

*Last updated: March 14, 2026*

---

## Current State (as of March 14, 2026)

- ✅ C: freed from 17 GB → 68 GB (Bond collection deleted, ISOs deleted)
- ✅ HA running at `https://millcreek.duckdns.org:8123` (VirtualBox VM, `10.176.1.240`)
- ✅ NAS (`192.168.0.124`) reachable, SMB shares mapped as W:/X:/Y:
- ✅ HA backup triggered today (Mar 14) — **verify it completed before proceeding**
- ⚠️ Bookworm VM (HA) lives entirely on K: (`K:\DebianVm\Bookworm\`) — 1.6 TB of snapshot chain
- ⚠️ K: drive has prior CRC errors — data at risk
- ⚠️ Windows Explorer restarting intermittently — monitor

---

## Task Checklist

### Phase 1 — Verify Backup & Prepare C:
- [ ] **1.1** Verify today's HA backup completed and is on `X:\HABackups` — run `scripts\check_backup.ps1`
- [ ] **1.2** Check C: free space — need 60+ GB for new VM. Run `scripts\check_space.ps1`
- [ ] **1.3** If C: < 60 GB free: move Camera Roll videos (30 GB) off OneDrive — run `scripts\move_camera_roll.ps1`

### Phase 2 — Create Fresh HA VM on C:
- [ ] **2.1** Download latest HAOS VirtualBox image (.vdi) from `https://www.home-assistant.io/installation/windows`
  - Save to `C:\VMs\HA\`
- [ ] **2.2** In VirtualBox: create new Linux VM named `HomeAssistant-C`
  - Type: Linux 64-bit
  - RAM: 4096 MB
  - Use downloaded .vdi as existing disk
  - **CRITICAL:** Set MAC address to match old VM — run `scripts\get_old_vm_mac.ps1` first
- [ ] **2.3** Start new VM, wait for HA to boot (~2 min)
- [ ] **2.4** Confirm HA accessible at new VM's IP (may differ initially — check VirtualBox network)
- [ ] **2.5** Restore the backup from `X:\HABackups` — in HA UI: Settings → Backup → restore latest
- [ ] **2.6** After restore, confirm `https://millcreek.duckdns.org:8123` resolves to new VM
- [ ] **2.7** Confirm SSH works: `ssh ha` (from `C:\Users\chris\.ssh\config`)

### Phase 3 — Decommission Old VM on K:
- [ ] **3.1** Stop old Bookworm VM in VirtualBox (right-click → Power Off)
- [ ] **3.2** Remove VM from VirtualBox registry: `scripts\remove_old_vm.ps1`
- [ ] **3.3** Delete `K:\DebianVm\Bookworm\` — this frees ~1.6 TB on K:
  - Run `scripts\delete_bookworm.ps1`
- [ ] **3.4** Verify K: free space after deletion

### Phase 4 — Drain K: Drive to NAS
- [ ] **4.1** Inventory remaining K: contents — run `scripts\inventory_k.ps1`
- [ ] **4.2** Check for duplicates already on H: (K: data was moved to H: in Jan 2026)
  - `H:\pcpcpcDownloads` = copy of `K:\c drive nook\Users\PCPCPC\Downloads`
  - `H:\old HA backups` = copy of `K:\HA Backups`
  - If H: copies verified intact → delete K: originals (no NAS copy needed)
- [ ] **4.3** Copy remaining unique K: data to `W:\DriveArchive\K\` — run `scripts\drain_k.ps1`
- [ ] **4.4** Verify copy with robocopy log, then delete source
- [ ] **4.5** Safely eject K: drive — update memory.md

### Phase 5 — Drain H: Drive to NAS
- [ ] **5.1** Inventory H: — run `scripts\inventory_h.ps1`
- [ ] **5.2** Ensure `X:\HABackups` has recent HA backups before deleting `H:\old HA backups`
- [ ] **5.3** Copy H: to `W:\DriveArchive\H\` — run `scripts\drain_h.ps1`
- [ ] **5.4** Verify, delete source, safely eject H:

### Phase 6 — Drain G: Drive to NAS
- [ ] **6.1** Inventory G: — run `scripts\inventory_g.ps1`
- [ ] **6.2** Copy G: to `W:\DriveArchive\G\` — run `scripts\drain_g.ps1`
  - ⚠️ Note: G: contains DebianVM (Bullseye?) — add note "TEST BEFORE DELETING"
- [ ] **6.3** Verify, delete source, safely eject G:

### Phase 7 — Final Verification
- [ ] **7.1** Confirm HA running from C: only, no K:/G:/H: dependency
- [ ] **7.2** Update memory.md with completed passport removals
- [ ] **7.3** Commit final state to this repo

---

## Key Credentials & Access

| Resource | How to access |
|---|---|
| HA Token | Windows Credential Manager: `[CM]::Get("HomeAssistant")` — see `scripts\get_token.ps1` |
| HA Web UI | https://millcreek.duckdns.org:8123 |
| HA SSH | `ssh ha` (config in `C:\Users\chris\.ssh\config`) |
| NAS Web UI | https://192.168.0.124/unifi-drive |
| NAS SMB | W: = Personal-Drive, X: = HABackups, Y: = FinchFamilyRoku |
| VirtualBox | `C:\Program Files\Oracle\VirtualBox\VBoxManage.exe` |

---

## Important Constraints

- **DO NOT change the MAC address** of the new HA VM — UniFi DHCP reservation keeps IP `.240`
- **DO NOT delete K:\DebianVm\Bookworm until new VM is confirmed working**
- **UniFi port forwards depend on `10.176.1.240`** — HA must keep this IP
- Windows Explorer instability noted — if Explorer crashes during file operations, reconnect remotely and continue
