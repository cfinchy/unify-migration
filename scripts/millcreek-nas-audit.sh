#!/usr/bin/env bash
# millcreek-nas-audit.sh — Walk W:\ (NAS Personal-Drive) and report what's already
# archived before running Phase R drain scripts. Read-only. No files modified.
#
# Reuses structure from seedbox-nas-audit.sh:
#   logging, REPORT_DIR/TIMESTAMP, scan_folder accumulator, markdown output.
#
# Run from this Proxmox VM — NAS mounted at /mnt/nas/Personal-Drive.
#
# Usage:
#   ./millcreek-nas-audit.sh                  # fast: item counts only
#   MILLCREEK_SIZES=1 ./millcreek-nas-audit.sh  # slow: recursive du for GB figures
#
# Output: ~/.local/share/millcreek-audit/reports/nas-audit-<timestamp>.md

set -euo pipefail

NAS_BASE="/mnt/nas/Personal-Drive"
REPORT_DIR="${HOME}/.local/share/millcreek-audit/reports"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
REPORT_FILE="${REPORT_DIR}/nas-audit-${TIMESTAMP}.md"
LOG_FILE="${HOME}/.local/share/millcreek-audit/millcreek-audit.log"
WANT_SIZES="${MILLCREEK_SIZES:-0}"

mkdir -p "$REPORT_DIR"

# ---------------------------------------------------------------------------
# Logging — same pattern as seedbox-lib.sh
# ---------------------------------------------------------------------------
log() {
    local level="$1"; shift
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"
}
log_info()  { log "INFO " "$@"; }
log_warn()  { log "WARN " "$@"; }
log_error() { log "ERROR" "$@"; }

# ---------------------------------------------------------------------------
# dir_info <path>
# Returns "N items" (fast) or "N items, X.X GB" (when MILLCREEK_SIZES=1).
# Returns "missing" if path does not exist.
# ---------------------------------------------------------------------------
dir_info() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        echo "missing"
        return
    fi
    local count
    count=$(find "$path" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l)
    if [[ "$WANT_SIZES" == "1" ]]; then
        local bytes gb
        bytes=$(du -sb "$path" 2>/dev/null | awk '{print $1}')
        gb=$(awk "BEGIN{printf \"%.1f\", ${bytes}/1073741824}")
        echo "${count} items, ${gb} GB"
    else
        echo "${count} items"
    fi
}

# ---------------------------------------------------------------------------
# Global accumulators — same pattern as seedbox-nas-audit.sh
# ---------------------------------------------------------------------------
declare -a ROWS=()
declare -a DUPE_ROWS=()
declare -i MISSING_COUNT=0
declare -i PRESENT_COUNT=0

# ---------------------------------------------------------------------------
# scan_nas_dir <label> <path> [note]
# Checks one NAS path and accumulates result into ROWS.
# ---------------------------------------------------------------------------
scan_nas_dir() {
    local label="$1"
    local path="$2"
    local note="${3:-}"
    local info
    info=$(dir_info "$path")

    if [[ "$info" == "missing" ]]; then
        MISSING_COUNT+=1
        ROWS+=("| \`${label}\` | — | not present | ${note} |")
        log_info "  MISSING: ${label}"
    else
        PRESENT_COUNT+=1
        ROWS+=("| \`${label}\` | ${info} | present | ${note} |")
        log_info "  OK: ${label} — ${info}"
    fi
}

# ---------------------------------------------------------------------------
# NAS mount check — same guard as seedbox-nas-audit.sh
# ---------------------------------------------------------------------------
if [[ ! -d "$NAS_BASE" ]]; then
    log_error "NAS not mounted at ${NAS_BASE} — check fstab / mount"
    exit 1
fi

log_info "Millcreek NAS audit starting  (MILLCREEK_SIZES=${WANT_SIZES})"
log_info "Report: $REPORT_FILE"

# ---------------------------------------------------------------------------
# Scan: existing manual backups (pre-Phase R)
# ---------------------------------------------------------------------------
log_info "--- Existing backups ---"
scan_nas_dir "K backup millcreek"              "$NAS_BASE/K backup millcreek"              "manual backup of K: (pre-Jan 2026)"
scan_nas_dir "K backup millcreek/c drive nook" "$NAS_BASE/K backup millcreek/c drive nook" "373 GB per Mar-2026 check"
scan_nas_dir "K backup millcreek/DebianVm"     "$NAS_BASE/K backup millcreek/DebianVm"     "⚠️ STALE — K:\\DebianVm is now 1.6 TB"
scan_nas_dir "K backup millcreek/HA Backups"   "$NAS_BASE/K backup millcreek/HA Backups"   "2024 backups; one may be CRC-corrupted"
scan_nas_dir "E_Drive_Archive"                 "$NAS_BASE/E_Drive_Archive"                 "E:\\System Backup(1) Acronis .adi — moved Jan 2026"

# ---------------------------------------------------------------------------
# Scan: Phase R drain targets
# ---------------------------------------------------------------------------
log_info "--- Phase R drain targets ---"
scan_nas_dir "DriveArchive/H" "$NAS_BASE/DriveArchive/H" "Phase R3 — drain_h.ps1 target"
scan_nas_dir "DriveArchive/G" "$NAS_BASE/DriveArchive/G" "Phase R4 — drain_g.ps1 target"

# drain_k.ps1 now targets K backup millcreek directly (delta sync) — no DriveArchive/K
if [[ -d "$NAS_BASE/DriveArchive/K" ]]; then
    scan_nas_dir "DriveArchive/K" "$NAS_BASE/DriveArchive/K" "⚠️ drain_k.ps1 was retargeted to K backup millcreek — this is a stale/duplicate copy"
    log_warn "DriveArchive/K exists — drain_k.ps1 now targets K backup millcreek; consider removing DriveArchive/K"
fi

# ---------------------------------------------------------------------------
# Scan: other top-level folders (anything not already scanned)
# ---------------------------------------------------------------------------
log_info "--- Other top-level folders ---"
SCANNED=("K backup millcreek" "E_Drive_Archive" "DriveArchive")
while IFS= read -r dir; do
    dname="$(basename "$dir")"
    skip=0
    for s in "${SCANNED[@]}"; do
        [[ "$dname" == "$s" ]] && skip=1 && break
    done
    [[ "$skip" -eq 1 ]] && continue
    scan_nas_dir "$dname" "$dir"
done < <(find "$NAS_BASE" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

# ---------------------------------------------------------------------------
# Duplication check: K backup millcreek vs DriveArchive/K (if both present)
# ---------------------------------------------------------------------------
KBM="$NAS_BASE/K backup millcreek"
KDRAIN="$NAS_BASE/DriveArchive/K"
if [[ -d "$KBM" && -d "$KDRAIN" ]]; then
    while IFS= read -r subdir; do
        sname="$(basename "$subdir")"
        drain_path="${KDRAIN}/${sname}"
        if [[ -d "$drain_path" ]]; then
            src_info=$(dir_info "$subdir")
            dst_info=$(dir_info "$drain_path")
            DUPE_ROWS+=("| \`K backup millcreek/${sname}\` | \`DriveArchive/K/${sname}\` | ${src_info} | ${dst_info} |")
            log_warn "DUPLICATE: K backup millcreek/${sname} AND DriveArchive/K/${sname} both present"
        fi
    done < <(find "$KBM" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# Write markdown report — same style as seedbox-nas-audit.sh
# ---------------------------------------------------------------------------
{
    echo "# Millcreek NAS Audit — W:\\ (Personal-Drive)"
    echo "_Generated: $(date '+%Y-%m-%d %H:%M:%S')_  "
    echo "_Sizes included: $([ "$WANT_SIZES" = "1" ] && echo "yes" || echo "no — re-run with \`MILLCREEK_SIZES=1\` for GB counts (slow)")_"
    echo ""
    echo "## Summary"
    echo ""
    echo "- Paths present: **${PRESENT_COUNT}**"
    echo "- Paths missing (not yet created): **${MISSING_COUNT}**"
    echo ""

    echo "## NAS Contents"
    echo ""
    echo "| Path | Contents | Status | Notes |"
    echo "|------|----------|--------|-------|"
    for row in "${ROWS[@]}"; do
        echo "$row"
    done
    echo ""

    echo "## Phase R Drain Readiness"
    echo ""
    echo "| Step | Script | NAS target | Status |"
    echo "|------|--------|------------|--------|"
    h_stat="$( [[ -d "$NAS_BASE/DriveArchive/H" ]] && echo "⚠️ already started — check robocopy log" || echo "✅ not started — safe to run" )"
    g_stat="$( [[ -d "$NAS_BASE/DriveArchive/G" ]] && echo "⚠️ already started — check robocopy log" || echo "✅ not started — safe to run" )"
    k_stat="$( [[ -d "$KBM" ]] && echo "✅ destination exists — robocopy will delta-sync only" || echo "⚠️ K backup millcreek missing" )"
    echo "| R3 | \`drain_h.ps1\` | \`DriveArchive\\H\` | ${h_stat} |"
    echo "| R4 | \`drain_g.ps1\` | \`DriveArchive\\G\` | ${g_stat} |"
    echo "| R5 | \`drain_k.ps1\` | \`K backup millcreek\` | ${k_stat} |"
    echo ""

    echo "## K: Deduplication Note"
    echo ""
    echo "\`K backup millcreek/\` is a pre-existing manual backup of K: (~373 GB \`c drive nook\`,"
    echo "~350 GB stale \`DebianVm\`, ~8 GB \`HA Backups\`). \`drain_k.ps1\` has been updated to"
    echo "target this folder directly so robocopy delta-syncs — only new or changed files are"
    echo "copied over WAN, avoiding a full re-copy of data already on the NAS."
    echo ""
    echo "The stale \`DebianVm\` copy (350 GB) predates the current 1.6 TB snapshot chain."
    echo "\`K:\\DebianVm\` is excluded from drain_k.ps1 regardless — do not delete the NAS copy"
    echo "until Phase 3 confirms the new HA VM is working."
    echo ""

    if [[ "${#DUPE_ROWS[@]}" -gt 0 ]]; then
        echo "## ⚠️ Confirmed Duplicates on NAS"
        echo ""
        echo "| Existing path | Duplicate path | Existing | Duplicate |"
        echo "|---------------|----------------|----------|-----------|"
        for row in "${DUPE_ROWS[@]}"; do
            echo "$row"
        done
        echo ""
        echo "Consider removing \`DriveArchive/K\` to reclaim NAS space."
        echo ""
    fi

} > "$REPORT_FILE"

# ---------------------------------------------------------------------------
# Stdout summary — same style as seedbox-nas-audit.sh
# ---------------------------------------------------------------------------
log_info "Audit complete — ${PRESENT_COUNT} present, ${MISSING_COUNT} missing"
log_info "Report written: $REPORT_FILE"

if [[ "${#DUPE_ROWS[@]}" -gt 0 ]]; then
    log_warn "${#DUPE_ROWS[@]} duplicate path(s) found — review report"
fi

echo ""
echo "Report: $REPORT_FILE"
[[ "$WANT_SIZES" == "0" ]] && echo "Tip: re-run with MILLCREEK_SIZES=1 for GB counts (slow — recursive du over NAS)"

exit 0
