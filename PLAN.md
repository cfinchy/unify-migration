# Unify Migration  Remote Implementation Plan

> **For Claude:** Open this repo as a VS Code workspace. Read `memory.md` first for full context,
> then `docs/Drive_Cleanup_Log.md` for history. Execute tasks in order below. Check off each item.
> All scripts are in `scripts/`. Token is in Windows Credential Manager  see memory.md for retrieval.

*Last updated: March 14, 2026*

---

## Current State (as of March 14, 2026)

-  C: freed from 17 GB  ~76 GB (Bond collection deleted, ISOs deleted)
-  HA running at `https://millcreek.duckdns.org:8123` (VirtualBox Bookworm VM, `10.176.1.240`)
-  NAS (`192.168.0.124`) reachable, SMB shares mapped as W:/X:/Y:
-  HA backup completed Mar 14  `9ff1dfa6.tar` (4.91 GB) on `X:\HABackups`
-  Debian 12.9 ISO downloaded  `C:\VMs\HA\debian-12.9.0-amd64-netinst.iso`
-  Bookworm VM (HA) lives entirely on K: (`K:\DebianVm\Bookworm\`)  1.6 TB of snapshot chain
-  K: drive has prior CRC errors  data at risk
-  Windows Explorer restarting intermittently  monitor

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

## Task Checklist

### Phase 1  Verify Backup & Prepare C:  COMPLETE
- [x] **1.1** Backup `9ff1dfa6.tar` (4.91 GB) confirmed on `X:\HABackups`
- [x] **1.2** C: free space ~76 GB (sufficient for 60 GB VDI)
- [x] **1.3** Camera Roll move not needed  space already sufficient

### Phase 2  Create Fresh HA Supervised VM on C: (parallel, old HA stays live)

>  This is **Home Assistant Supervised on Debian Bookworm**  NOT HAOS.
> New VM runs in parallel with temp MAC until cutover_vm.ps1 is called.

- [x] **2.0** Old VM MAC confirmed: `08:00:27:D3:15:60`, bridged to Intel AX201 Wi-Fi
- [x] **2.0** Backup `9ff1dfa6.tar` on `X:\HABackups` 
- [x] **2.1** Debian 12.9 ISO downloaded  `C:\VMs\HA\debian-12.9.0-amd64-netinst.iso` 
- [ ] **2.2** Create new VirtualBox VM  run `scripts\create_ha_vm.ps1`
  - Name: `HomeAssistant-C`, Debian 64-bit, 4096 MB RAM
  - 60 GB dynamic VDI at `C:\VMs\HA\HomeAssistant-C.vdi`
  - **TEMP MAC: `080027FFFFFE`**  old VM keeps `.240` while new VM is being set up
  - Bridged to Intel AX201 Wi-Fi
- [ ] **2.3** Start VM in VirtualBox GUI, boot Debian installer, complete minimal install:
  - No desktop environment
  - SSH server , standard system utilities 
  - Hostname: `homeassistant`
  - **Note the IP** after first boot  check UniFi DHCP leases at `https://192.168.0.1`
    (it will NOT be `.240`  that stays on the old VM)
  - **Paste your `id_rsa.pub` into authorized_keys** during or after install so SSH works:
    ```bash
    mkdir -p ~/.ssh && echo "PASTE_CONTENTS_OF_C:\Users\chris\.ssh\id_rsa.pub" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    ```
- [ ] **2.4** SSH into new VM at its temp IP, install HA Supervised:
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
- [ ] **2.8** Confirm SSH works: `ssh root@<TEMP_IP>` (using id_rsa)
- [ ] **2.9**  CUTOVER  run only when fully satisfied with 2.7/2.8:
  ```powershell
  .\scripts\cutover_vm.ps1 -TempIP <NEW_VM_TEMP_IP>
  ```
  The script will:
  - Verify SSH works to new VM before touching anything
  - Stop old Bookworm VM
  - Swap new VM MAC  `080027D31560`  UniFi DHCP hands it `10.176.1.240`
  - Start new VM, wait for HA to respond
  - SSH in and write `/etc/network/interfaces` with **static IP `10.176.1.240`**
  - After this: `.240` is permanent  no DHCP dependency, no port forward changes ever needed
  - Total downtime: ~60-90 seconds

### Phase 3  Decommission Old VM on K: (AFTER cutover confirmed working)
- [ ] **3.1** Confirm new VM running stably at `.240` for at least 1 hour post-cutover
- [ ] **3.2** Remove old Bookworm VM from VirtualBox registry: `scripts\remove_old_vm.ps1`
- [ ] **3.3** Delete `K:\DebianVm\Bookworm\`  frees ~1.6 TB on K:
  - Run `scripts\delete_bookworm.ps1`
- [ ] **3.4** Verify K: free space after deletion

### Phase 4  Drain K: Drive to NAS
- [ ] **4.1** Inventory remaining K: contents  run `scripts\inventory_k.ps1`
- [ ] **4.2** Check for duplicates already on H: (K: data was moved to H: in Jan 2026)
  - `H:\pcpcpcDownloads` = copy of `K:\c drive nook\Users\PCPCPC\Downloads`
  - `H:\old HA backups` = copy of `K:\HA Backups`
  - If H: copies verified intact  delete K: originals (no NAS copy needed)
- [ ] **4.3** Copy remaining unique K: data to `W:\DriveArchive\K\`  run `scripts\drain_k.ps1`
- [ ] **4.4** Verify copy with robocopy log, then delete source
- [ ] **4.5** Safely eject K: drive  update memory.md

### Phase 5  Drain H: Drive to NAS
- [ ] **5.1** Inventory H:  run `scripts\inventory_h.ps1`
- [ ] **5.2** Ensure `X:\HABackups` has recent HA backups before deleting `H:\old HA backups`
- [ ] **5.3** Copy H: to `W:\DriveArchive\H\`  run `scripts\drain_h.ps1`
- [ ] **5.4** Verify, delete source, safely eject H:

### Phase 6  Drain G: Drive to NAS
- [ ] **6.1** Inventory G:  run `scripts\inventory_g.ps1`
- [ ] **6.2** Copy G: to `W:\DriveArchive\G\`  run `scripts\drain_g.ps1`
  -  Note: G: contains DebianVM (Bullseye?)  add note "TEST BEFORE DELETING"
- [ ] **6.3** Verify, delete source, safely eject G:

### Phase 7  Final Verification
- [ ] **7.1** Confirm HA running from C: only, no K:/G:/H: dependency
- [ ] **7.2** Update memory.md with completed passport removals
- [ ] **7.3** Commit final state to this repo

---

## Key Credentials & Access

| Resource | How to access |
|---|---|
| HA Token | Windows Credential Manager: `[CM]::Get("HomeAssistant")`  see `scripts\get_token.ps1` |
| HA Web UI (live) | https://millcreek.duckdns.org:8123 |
| HA Web UI (new VM, temp) | `http://<TEMP_IP>:8123`  check UniFi DHCP leases at https://192.168.0.1 |
| HA SSH (post-cutover) | `ssh ha` (Host ha = 10.176.1.240 in `C:\Users\chris\.ssh\config`) |
| NAS Web UI | https://192.168.0.124/unifi-drive |
| NAS SMB | W: = Personal-Drive, X: = HABackups, Y: = FinchFamilyRoku |
| VirtualBox | `C:\Program Files\Oracle\VirtualBox\VBoxManage.exe` |

---

## Important Constraints

- **DO NOT change the MAC on old Bookworm VM**  it must keep `.240` until cutover
- **DO NOT run `cutover_vm.ps1` early**  only after new HA fully verified at temp IP
- **DO NOT delete `K:\DebianVm\Bookworm` until new VM confirmed working at `.240`** (Phase 3.1)
- **No port forwarding changes needed**  `.240` never moves (MAC swap + static IP in cutover script)
- After cutover, `.240` is a **static IP on the Debian VM**  DHCP reservation can be left or deleted
- Windows Explorer instability noted  if Explorer crashes during file operations, reconnect remotely
