#!/usr/bin/env bash
# =============================================================================
# 07-cleanup.sh — Session cleanup before shutdown
# =============================================================================
# PURPOSE : Securely wipe in-session artifacts before shutting down Tails:
#             • Clear bash / shell history (in-memory and any stray files)
#             • Empty /tmp and /var/tmp
#             • Wipe apt caches (package lists and downloaded .debs)
#             • Clear thumbnail caches
#             • Optionally overwrite free space on the RAM disk
#
# PERSISTENCE: SESSION-ONLY — no changes to Persistent Storage.
# REQUIRES : sudo / admin password set at Greeter.
# USAGE    : bash scripts/07-cleanup.sh [--wipe-free-space]
#              --wipe-free-space   Also zero-fill free space on tmpfs (slow)
# =============================================================================

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "  ${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "  ${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "  ${RED}[ERROR]${NC} $*"; exit 1; }

WIPE_FREE_SPACE=false
for arg in "$@"; do
    [[ "${arg}" == "--wipe-free-space" ]] && WIPE_FREE_SPACE=true
done

# ── Require root (sudo) ───────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    exec sudo --preserve-env=HOME,USER bash "$0" "$@"
fi

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — Session Cleanup                   ${NC}"
echo -e "${CYAN}  [SESSION-ONLY] — Run before shutdown         ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

TAILS_USER="${SUDO_USER:-amnesia}"
TAILS_HOME=$(getent passwd "${TAILS_USER}" | cut -d: -f6)

# ── 1. Bash / shell history ───────────────────────────────────────────────────
info "Clearing shell history..."

# Clear in-memory history for the current shell
history -c 2>/dev/null || true

# Overwrite any stray .bash_history files (Tails sets HISTFILE="" but users
# might have enabled it manually during the session)
for histfile in \
    "${TAILS_HOME}/.bash_history" \
    "${TAILS_HOME}/.zsh_history" \
    "${TAILS_HOME}/.python_history" \
    "${TAILS_HOME}/.lesshst" \
    "${TAILS_HOME}/.local/share/recently-used.xbel"; do
    if [[ -f "${histfile}" ]]; then
        # Overwrite with zeros before removing to prevent recovery from RAM
        shred -u -z "${histfile}" 2>/dev/null && ok "  Shredded ${histfile}" \
            || { rm -f "${histfile}"; ok "  Removed ${histfile}"; }
    fi
done
ok "Shell history cleared."

# ── 2. /tmp ────────────────────────────────────────────────────────────────────
info "Clearing /tmp..."
# Remove all files/dirs in /tmp but not the directory itself
find /tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
ok "/tmp emptied."

# ── 3. /var/tmp ───────────────────────────────────────────────────────────────
info "Clearing /var/tmp..."
find /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
ok "/var/tmp emptied."

# ── 4. apt caches ─────────────────────────────────────────────────────────────
info "Clearing apt caches..."
apt-get clean -qq 2>/dev/null && ok "  apt package cache cleared." \
    || warn "  apt-get clean failed."
rm -rf /var/lib/apt/lists/* 2>/dev/null && ok "  apt package lists cleared." \
    || warn "  Could not clear apt lists."

# ── 5. Thumbnail caches ───────────────────────────────────────────────────────
info "Clearing thumbnail caches..."
THUMB_CACHE="${TAILS_HOME}/.cache/thumbnails"
if [[ -d "${THUMB_CACHE}" ]]; then
    rm -rf "${THUMB_CACHE}" 2>/dev/null && ok "  Thumbnail cache cleared." \
        || warn "  Could not clear thumbnail cache."
fi

# GNOME recent files
RECENT_FILES="${TAILS_HOME}/.local/share/recently-used.xbel"
if [[ -f "${RECENT_FILES}" ]]; then
    shred -u -z "${RECENT_FILES}" 2>/dev/null || rm -f "${RECENT_FILES}" 2>/dev/null || true
    ok "  GNOME recent files list cleared."
fi

# ── 6. Editor swap/undo files ────────────────────────────────────────────────
info "Clearing editor swap files..."
find "${TAILS_HOME}" -maxdepth 3 \( -name '*.swp' -o -name '*.swo' -o -name '*~' \) \
    -exec rm -f {} + 2>/dev/null || true
ok "Editor swap/backup files cleared."

# ── 7. Optional: overwrite free space ────────────────────────────────────────
if [[ "${WIPE_FREE_SPACE}" == true ]]; then
    info "Overwriting free space on RAM disk (this may take a while)..."
    TARGET_FS="/"
    FREE_KB=$(df -k "${TARGET_FS}" 2>/dev/null | awk 'NR==2{print $4}')
    if [[ -n "${FREE_KB}" ]] && (( FREE_KB > 4096 )); then
        WIPE_FILE=$(mktemp /tmp/wipe-XXXXXXXX)
        # Write zeros until the filesystem is full, then delete
        dd if=/dev/zero of="${WIPE_FILE}" bs=1M 2>/dev/null || true
        sync
        rm -f "${WIPE_FILE}"
        ok "Free space on ${TARGET_FS} zeroed."
    else
        warn "Less than 4 MB free on ${TARGET_FS} — skipping free-space wipe."
    fi
else
    info "Skipping free-space wipe (pass --wipe-free-space to enable)."
fi

# ── 8. Sync and report ───────────────────────────────────────────────────────
sync
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  Session cleanup complete.                    ${NC}"
echo -e "${YELLOW}  You can now safely shut down Tails.          ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
