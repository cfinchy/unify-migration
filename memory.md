# Project Memory — Unigy Box

*Last Updated: March 14, 2026*

---

## Primary Goals

1. **Get HA running fully on C: SSD — zero Passport drive dependency**
2. **Remove all WD Passport drives one by one** after migrating data to NAS
3. **Long-term:** Replace UniFi port forwards with Cloudflare Tunnel, retire DuckDNS

---

## System Overview

- **Machine:** Unigy box, Windows, on `10.176.1.0/24` LAN
- **Router:** UniFi Dream Machine Special Edition
- **WAN IP:** 192.168.1.209 (Optimum Online)
- **HA URL (external):** https://millcreek.duckdns.org:8123
- **HA URL (internal):** http://10.176.1.240:8123
- **HA IP:** `10.176.1.240` — **DO NOT CHANGE** (UniFi port forwards depend on this)

---

## Known Issues / Blockers

- ⚠️ **Windows Explorer keeps restarting** — recurring instability, investigate cause (shell extension crash? drive enumeration issue? Passport USB disconnect?)
- ⚠️ **C: drive low on space** (~33 GB free) — must complete media cleanup before moving HA VM from E:
- ⚠️ **NAS space ~13 TB free vs ~15.5 TB Passport data** — need to delete confirmed duplicates on K: first (K: data was already moved to H: in Jan 2026)

---

## Home Assistant

| Property | Value |
|---|---|
| Internal IP | 10.176.1.240 |
| External URL | https://millcreek.duckdns.org:8123 |
| SSH Port | 22 |
| Hypervisor | VirtualBox (Oracle VM) |
| VM Disk Location | E:\VM holder (target: move to C:) |
| HA Version | 2025.7.1 (last known) |

### HA Long-Lived Token
- **Stored in:** Windows Credential Manager
- **Retrieve with:** `cmdkey /list` or via PowerShell script `C:\projects\unify-migration\scripts\get_token.ps1`
- **Generic name:** `HomeAssistant` / user: `ha_api`
- ⚠️ Token revoked and replaced March 14, 2026 — old token was accidentally pasted in chat

---

## SSH Config (`C:\Users\chris\.ssh\config`)

```
Host ha
  HostName 10.176.1.240
  User root
  Port 22
  IdentityFile ~/.ssh/id_rsa

Host nas
  HostName 192.168.0.124
  User root
  Port 22
  IdentityFile ~/.ssh/id_rsa
```

- **SSH key:** `C:\Users\chris\.ssh\id_rsa` (RSA 4096, created Dec 2024)
- **NAS SSH:** Root login disabled on UniFi Drive — file transfers use SMB (W:/X:/Y: already mapped) ✅
- **HA SSH add-on:** Needs installing (Advanced SSH & Web Terminal, port 22)

---

## NAS

**Device:** UniFi Drive (Samba 4.17.12-Debian)

| Property | Value |
|---|---|
| Internal IP | 192.168.0.124 (Ethernet) — **USE THIS** |
| Internal IP (SFP+) | 192.168.1.88 — unreachable from Unigy box |
| External IP | 24.90.225.54 (home WAN, for FileZilla/remote) |
| Free Space | ~13 TB total across shares |
| SSH root login | Disabled on device — not needed |
| Web UI | https://192.168.0.124/unifi-drive |

### SMB Shares (already mapped on this machine)

| Drive | Share | Purpose |
|---|---|---|
| W: | `\\192.168.0.124\Personal-Drive` | General archive — **primary target for Passport drain** |
| X: | `\\192.168.0.124\HABackups` | HA backups |
| Y: | `\\192.168.0.124\FinchFamilyRoku` | Roku/media |

> ✅ No new drive mapping needed — W:/X:/Y: are live and usable now

### Passport Drain Target Structure on W:
```
W:\DriveArchive\
  I\    ← I: drive contents
  K\    ← K: drive contents (after dedup check)
  H\    ← H: drive contents
  G\    ← G: drive contents (incl. Bookworm DebianVM)
```

---

## UniFi Port Forwards

| Name | Proto | Ext Port | Internal Target | Interface |
|---|---|---|---|---|
| Home Assistant 2025 | TCP/UDP | 443 | 10.176.1.240:8123 | Any |
| Home Assistant 2025 8123 | TCP/UDP | 8123 | 10.176.1.240:8123 | Any |
| NasPro SSH | TCP/UDP | 22 | 10.176.1.240:22 | Internet 1 |
| Plex | TCP | 32400 | 10.176.1.110:32400 | Internet 1 |

> ⚠️ "NasPro SSH" forward (ext:22 → 10.176.1.240:22) appears to be for HA SSH — verify this is still correct after SSH add-on is installed

---

## Drive Inventory

| Drive | Type | Used | Free | Status | Notes |
|---|---|---|---|---|---|
| C: | Kingston SSD | ~413 GB | ~33 GB | ⚠️ Low | HA VM target — needs space first |
| E: | Crucial SSD | ~911 GB | ~66 GB | ⚠️ Low | Contains HA VirtualBox VM disk |
| G: | WD Passport 4TB | ~4.4 TB | ~257 GB | 🔴 Remove | Bookworm DebianVM, large files |
| H: | WD Passport 4TB | ~3.4 TB | ~368 GB | 🔴 Remove | pcpcpc downloads, old HA backups |
| I: | WD Passport 4TB | ~3.6 TB | ~1 TB | 🔴 Remove | exFAT, warning state — remove first |
| K: | WD Passport 4TB | ~4.3 TB | ~325 GB | 🔴 Remove | CRC error noted — remove second |
| W: | Network | — | ~42 TB | ✅ | May be NAS mapped drive — verify |
| X: | Network | — | ~43 TB | ✅ | May be NAS mapped drive — verify |
| Y: | Network | — | ~18 TB | ✅ | May be NAS mapped drive — verify |

---

## Passport Removal Order

1. **I:** — exFAT warning, worst health, remove first
2. **K:** — CRC error history, high risk; NOTE: K: data was already moved to H: in Jan 2026 — verify H: copies then delete K: originals to close NAS space gap
3. **H:** — holds Jan 2026 archive copies; drain to NAS after K: confirmed
4. **G:** — last; move Bookworm DebianVM to NAS with note: **"TEST VM BEFORE DELETING FROM NAS"**

---

## C: Drive Cleanup Remaining (unblocks HA VM move)

| Item | Size | Status |
|---|---|---|
| iPhone Movies (OneDrive\Documents\OCR Filing\Box Sync\...) | 6.4 GB | Ready to move to NAS/W: |
| ISO files in Downloads | 1.4 GB | Ready to move |
| OneDrive Camera Roll videos (2014–2023) | ~15 GB | Needs review |
| OneDrive iPlayer recording | 2.1 GB | Needs review |

---

## Future / Long-Term

- [ ] Replace UniFi port forwards with **Cloudflare Tunnel** (`cloudflared`) on HA
- [ ] Retire DuckDNS once Cloudflare tunnel is stable
- [ ] Test Bookworm DebianVM on NAS before deleting local copy
- [ ] Investigate **Windows Explorer restart loop** — possible causes: USB Passport disconnect events, shell extension crash, low disk space on C:
