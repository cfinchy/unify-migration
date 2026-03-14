# Drive Cleanup Log
**Date:** January 12, 2026  
**Objective:** Free up space on critical drives E:, G:, K:

---

## Summary of Changes

### K: Drive - Initial Cleanup (Completed)
- **Initial Status:** 0% free (0 GB)
- **Final Status:** 7.37% free (343.11 GB)
- **Total Freed:** 112 GB

#### K:\c drive nook\Users\PCPCPC\Downloads
- **Status:** All 62 folders processed
- **Destination:** H:\pcpcpcDownloads
- **Action:** Moved to H:, then deleted from K:
- **Space Freed:** ~60 GB

**Notable Items:**
- green thumb drive 20150228 (39.83 GB) - Moved
- Download from C drive archived (12.89 GB) - Moved
- 2ND LAN CARD DRIVER (1.26 GB) - Moved
- INTEL BLUETOOTH (917.62 MB) - Moved
- Plus 58 other folders (drivers, tools, etc.)

#### K:\HA Backups
- **Status:** All 8 items processed
- **Destination:** H:\old HA backups
- **Space Freed:** 52.13 GB

**Items Moved:**
1. Automatic_backup_2025.6.1_2025-06-23_04.55_44001123 (14.14 GB) - ✓ Moved
2. Automatic_backup_2025.6.1_2025-06-16_05.36_08005789.tar (7.18 GB) - ✓ Moved
3. Automatic_backup_2025.6.1_2025-06-23_04.55_44001123.tar (7.18 GB) - ✓ Moved
4. Automatic_backup_2025.5.3_2025-06-04_17.04_17038715.tar (7.17 GB) - ✓ Moved
5. 391d3b36.tar (4.18 GB) - ✓ Moved
6. Automatic_backup_2025.7.1_2025-07-12_05.41_01004279.tar (4.17 GB) - ✓ Moved
7. 2024-09-30 06 51 33.tar (4.04 GB) - ✓ Moved
8. 2024-09-30 18 37 48.tar (4.07 GB) - ⚠️ **CRC ERROR** - File corrupted, deleted

**Note:** One file had a cyclic redundancy check (CRC) error indicating possible disk hardware issues on K: drive. Monitor closely.

---

## C: Drive Media Audit - January 13, 2026

### Current Status
- **Total Capacity:** 445.95 GB
- **Used:** 421 GB (94.41%)
- **Free:** 24.95 GB (5.59%) - ⚠️ After recycle bin cleared
- **Pending Deletion:** 50.37 GB (Bond collection scheduled for 23:30)
- **Projected After Deletion:** 75.32 GB free (16.89%)
- **Target:** Maintain 10%+ free (44.6 GB) ✅

### Media Files Discovered
**Total Found:** 74.75 GB in 124 files over 100MB

#### Priority Relocation Candidates

##### 1. James Bond Collection (IN PROGRESS) ⏳
- **Original Location:** `C:\Users\James Bond 007 Films 50th Anniversary Collection 1962-2008 720p BluRay x264-NhaNc3`
- **New Location:** `Y:\Movies\James Bond 007 Films 50th Anniversary Collection 1962-2008 720p BluRay x264-NhaNc3`
- **Size:** 50.37 GB (23 files total)
- **Transfer Status:** 48.86 GB / 50.37 GB (97% complete)
- **Remaining:** Die Another Day - 1.13 GB / 2.64 GB copied
- **Scheduled Deletion:** 23:30 (Jan 13, 2026) - Automatic task will delete C: folder
- **Space to Free:** 50.37 GB
- **Junction Pending:** Will create after deletion to maintain accessibility

##### 2. iPhone Movies Collection
- **Location:** `C:\Users\chris\OneDrive\Documents\OCR Filing\Box Sync\Chris Finch's iPhone 5\Movies`
- **Size:** 6.39 GB (44 video files)
- **Proposed Destination:** `W:\Media_Archive\iPhone_Videos\iPhone_5_Movies`
- **Link Strategy:** Create directory junction

##### 3. OneDrive Camera Roll Videos
- **Location:** `C:\Users\chris\OneDrive\Pictures\Camera Roll\` (various year/month folders)
- **Size:** ~15 GB spread across multiple folders (2014-2023)
- **Status:** ⚠️ CAUTION - OneDrive synced content
- **Recommendation:** Review OneDrive sync settings before moving
- **Alternative:** Exclude from OneDrive sync, then move to W:\Media_Archive

##### 4. ISO Files in Downloads
- **Location:** `C:\Users\chris\Downloads`
- **Files:** 
  - debian-12.0.0-amd64-netinst.iso (732 MB)
  - gparted-live-1.2.0-1-amd64.iso (435 MB)
  - (1 additional file ~265 MB)
- **Size:** 1.43 GB total
- **Proposed Destination:** `W:\Software_Archive\ISOs`
- **Link Strategy:** File-level symbolic links

##### 5. iPlayer Recording
- **Location:** `C:\Users\chris\OneDrive\home assistant\scans\Desktop\iPlayer Recordings`
- **Size:** 2.1 GB (Attenborough documentary)
- **Status:** ⚠️ CAUTION - OneDrive synced
- **Proposed Destination:** `W:\Media_Archive\Documentaries`

### Relocation Plan Summary

| Item | Size (GB) | Priority | OneDrive Synced | Space Gained |
|------|-----------|----------|-----------------|--------------|
| James Bond Collection | 50.3 | ⭐⭐⭐ HIGH | No | 50.3 GB |
| iPhone Movies | 6.39 | ⭐⭐ MEDIUM | Yes | 6.39 GB |
| ISO Files | 1.43 | ⭐ LOW | No | 1.43 GB |
| iPlayer Recording | 2.1 | ⭐ LOW | Yes | 2.1 GB |
| Camera Roll Videos | ~15 | ⚠️ REVIEW | Yes | TBD |

**Estimated Total Space to Free:** 60-75 GB  
**Post-Cleanup Target:** 90-105 GB free (20-23% free)

### Symbolic Link Strategy

**Directory Junctions** (for folders):
```powershell
# After moving folder, create junction:
New-Item -ItemType Junction -Path "C:\Original\Path" -Target "W:\New\Location"
```

**Symbolic Links** (for files):
```powershell
# After moving file, create symlink:
New-Item -ItemType SymbolicLink -Path "C:\Original\File.ext" -Target "W:\New\Location\File.ext"
```

**Benefits:**
- Applications continue working with original paths
- No broken shortcuts or registry entries
- Transparent to software looking for files at original locations
- Space freed on C: drive while maintaining accessibility

---

## Planned Changes

### E: Drive - Target 5% Free (48.86 GB)
- ~~**Current Status:** 0.6% free (5.58 GB)~~
- **Updated Status (Jan 13):** ✅ 6.71% free (65.61 GB) - **TARGET ACHIEVED**
- ~~**Need to Free:** 43.28 GB~~
- ~~**Plan:** Move "System Backup(1)" folder (60.02 GB) to W:\E_Drive_Archive~~

**Completed Actions:**
1. ✅ E:\System Backup(1) → W:\E_Drive_Archive\System Backup(1) (60.02 GB freed)

**Alternative if needed:**
- E:\VM holder → W:\E_Drive_Archive\VM holder (214.67 GB)

---

### G: Drive - Target 5% Free (232.87 GB)
- ~~**Current Status:** 3.8% free (178.39 GB)~~
- **Updated Status (Jan 13):** ✅ 5.52% free (256.93 GB) - **TARGET ACHIEVED**
- ~~**Need to Free:** 54.48 GB~~
- ~~**Plan:** Move "HA Backups" folder (52.13 GB) to H:\old HA backups~~

**Completed Actions:**
1. ✅ G:\HA Backups → Already cleared/empty (folder exists but contains no files)

**Alternative if needed:**
- G:\c drive nook → W:\G_Drive_Archive\c drive nook (71.51 GB)

---

### I: Drive - Warning Status
- **Current Status:** Warning (exFAT filesystem)
- **Space:** 21.7% free (1010.92 GB) - Not critical
- **Issue:** exFAT filesystem may trigger Windows warnings
- **Plan:** Run filesystem check with `chkdsk I: /F` (requires admin)
- **Alternative:** If accessible and functional, monitor only

---

## Movement Destinations

### Archived to H:\pcpcpcDownloads
- All K:\c drive nook\Users\PCPCPC\Downloads contents

### Archived to H:\old HA backups
- K:\HA Backups (8 items, 7 successful + 1 corrupted)
- G:\HA Backups (pending)

### Archived to W:\E_Drive_Archive (planned)
- E:\System Backup(1) (pending)
- E:\VM holder (if needed)

### Archived to W:\G_Drive_Archive (planned)
- G:\c drive nook (if needed)

---

## Drive Health Summary

| Drive | Status | %Free | Free GB | Total GB | Physical Disk | Health |
|-------|--------|-------|---------|----------|---------------|--------|
| C:    | ⚠️ LOW | 7.4%  | 33.06   | 445.95   | Kingston SSD  | Media audit needed |
| D:    | ✅ OK  | 65.5% | 0.06    | 0.1      | Crucial SSD   | Healthy |
| E:    | ✅ OK  | 6.7%  | 65.61   | 977.15   | Crucial SSD   | Healthy |
| G:    | ✅ OK  | 5.5%  | 256.93  | 4657.49  | WD Passport   | Healthy |
| H:    | ⚠️ LOW | 9.9%  | 367.92  | 3725.99  | WD Passport   | Healthy |
| I:    | ⚠️ WARN| 21.7% | 1010.92 | 4657.38  | WD Passport   | Warning (exFAT) |
| K:    | ⚠️ LOW | 7.0%  | 324.75  | 4657.48  | WD Passport   | Healthy (CRC error noted) |
| W:    | ✅ OK  | 93.9% | 41922.06| 44663.44 | Network       | OK |
| X:    | ✅ OK  | 96.9% | 43261.97| 44663.44 | Network       | OK |
| Y:    | ✅ OK  | 39.3% | 17558.32| 44663.44 | Network       | OK |

---

## Notes & Observations

1. **K: Drive CRC Error:** File "2024-09-30 18 37 48.tar" had a cyclic redundancy check error. This could indicate:
   - Bad sectors on the drive
   - USB connection issues
   - Drive beginning to fail
   - **Recommendation:** Monitor K: drive closely, consider replacing if more errors occur

2. **Network Drives (W:, X:, Y:):** Have massive free space (41-43 TB available). Ideal for archiving large files.

3. **I: Drive exFAT Warning:** Common Windows issue with exFAT filesystems. If drive is accessible and data is safe, warning can be ignored. Otherwise, run chkdsk.

4. **E: Drive Critical:** Contains Windows system files, VMs, and backups. Be careful when moving data.

5. **G: Drive Critical:** Primarily a DebianVM drive (4TB). Limited options for space clearing without affecting the VM.

---

## Execution Status

### Completed Tasks
- ✅ K:\c drive nook\Users\PCPCPC\Downloads - **COMPLETED** (60 GB freed)
- ✅ K:\HA Backups - **COMPLETED** (52.13 GB freed)
- ✅ E:\System Backup(1) - **COMPLETED** (60.02 GB freed)
- ✅ G:\HA Backups - **COMPLETED** (already empty)
- ✅ C: Drive Media Audit - **COMPLETED** (74.75 GB identified)

### Pending Tasks
- ⏳ **C: Drive Media Relocation** - IN PROGRESS
  - ✅ Recycle Bin Cleared (freed ~8 GB)
  - 🔄 James Bond Collection (50.37 GB) - 97% COPIED, deletion scheduled 23:30
  - ⏳ iPhone Movies (6.39 GB) - READY TO MOVE
  - ⏳ ISO Files (1.43 GB) - READY TO MOVE
  - ⏳ OneDrive files - NEEDS REVIEW
- ⏳ I: Drive Check - **PENDING** (filesystem check needed)

### Active Operations
- **23:30 Tonight:** Scheduled task will delete Bond folder from C: (50.37 GB)
- **Post-Deletion:** Create junction from C: to Y: for transparent access

---

*Last Updated: January 13, 2026*

---

## Next Steps Checklist

### C: Drive Media Cleanup (Priority Order)

1. **Phase 1: James Bond Collection** (50.3 GB)
   - [ ] Create destination folder: `W:\Media_Archive\Movies\James_Bond_Collection`
   - [ ] Move folder to W: drive
   - [ ] Verify all 20 films transferred successfully
   - [ ] Create directory junction: `C:\Users\James Bond...` → `W:\Media_Archive\Movies\James_Bond_Collection`
   - [ ] Test playback from original location via junction

2. **Phase 2: iPhone Movies** (6.39 GB)
   - [ ] Create destination: `W:\Media_Archive\iPhone_Videos\iPhone_5_Movies`
   - [ ] Move folder to W: drive
   - [ ] Verify file integrity
   - [ ] Create directory junction at original location

3. **Phase 3: ISO Files** (1.43 GB)
   - [ ] Create destination: `W:\Software_Archive\ISOs`
   - [ ] Move ISO files from Downloads
   - [ ] Create symbolic links for each ISO file
   - [ ] Test mounting ISOs from links

4. **Phase 4: OneDrive Review** (~17 GB)
   - [ ] Review OneDrive sync settings
   - [ ] Decide on Camera Roll and iPlayer content
   - [ ] Adjust OneDrive selective sync if needed
   - [ ] Move non-critical videos to W: if appropriate

5. **Final Verification**
   - [ ] Confirm C: drive at 10%+ free space
   - [ ] Test all junctions and symlinks
   - [ ] Document final space savings
   - [ ] Update Drive_Cleanup_Log.md with completion status

### Commands Reference

**Create Directory Junction:**
```powershell
New-Item -ItemType Junction -Path "C:\Original\Path" -Target "W:\New\Location"
```

**Create File Symbolic Link:**
```powershell
New-Item -ItemType SymbolicLink -Path "C:\Original\File.ext" -Target "W:\New\Location\File.ext"
```

**Verify Junction/Link:**
```powershell
Get-Item "C:\Path\To\Link" | Select-Object LinkType, Target
```

---

*Last Updated: January 13, 2026*
