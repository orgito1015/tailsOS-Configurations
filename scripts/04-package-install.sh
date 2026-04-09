#!/usr/bin/env bash
# =============================================================================
# 04-package-install.sh — Install extra packages for this session
# =============================================================================
# PURPOSE : Install additional privacy, security, and utility packages via
#           apt over Tor.  All packages are installed into the live RAM
#           filesystem and are lost on reboot.
#
#           Package list is defined in PACKAGES below.  Edit to taste.
#
# PERSISTENCE: SESSION-ONLY — packages must be reinstalled every session.
#              (You could use Tails' "Additional Software" feature in the
#              Persistent Storage menu to auto-install packages on boot.)
# REQUIRES : sudo / admin password set at Greeter.
#            Active Tor connection.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "  ${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "  ${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "  ${RED}[ERROR]${NC} $*"; exit 1; }

# ── Require root (sudo) ───────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    exec sudo --preserve-env=HOME,USER bash "$0" "$@"
fi

# ── Package list ─────────────────────────────────────────────────────────────
# Add or remove packages as needed.  All packages come from the standard
# Debian Bookworm repositories (accessed over Tor by default in Tails).
#
# Categories:
#   SECURITY  — hardening / audit tools
#   PRIVACY   — additional privacy tools
#   UTILITY   — general-purpose tools useful in a live session
PACKAGES=(
    # Security / audit
    "lynis"           # system security audit tool
    "chkrootkit"      # rootkit checker
    "rkhunter"        # rootkit hunter
    "aide"            # file integrity checker (session use only)
    "nmap"            # network scanner
    "netcat-openbsd"  # Swiss-army knife networking

    # Privacy
    "mat2"            # metadata anonymisation toolkit
    "exiftool"        # read/write/strip file metadata
    "secure-delete"   # secure file/memory/disk wiping

    # Utilities
    "vim"             # improved text editor (if not present)
    "tmux"            # terminal multiplexer
    "htop"            # interactive process viewer
    "tree"            # directory tree display
    "jq"              # JSON processor
    "xxd"             # hex dump utility (ships in vim-common; already present if vim is installed)
    "curl"            # HTTP client (usually already installed)
    "wget"            # file downloader
)

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — Package Installation              ${NC}"
echo -e "${CYAN}  [SESSION-ONLY] — packages lost on reboot     ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# ── Check Tor is running ─────────────────────────────────────────────────────
if ! systemctl is-active --quiet tor@default 2>/dev/null && \
   ! systemctl is-active --quiet tor        2>/dev/null; then
    warn "Tor does not appear to be running.  apt will still work but"
    warn "traffic routing cannot be guaranteed."
fi

# ── Update package lists ──────────────────────────────────────────────────────
info "Updating apt package lists..."
apt-get update -qq 2>&1 | tail -5
ok "Package lists updated."

# ── Install packages ──────────────────────────────────────────────────────────
info "Installing packages: ${PACKAGES[*]}"
echo ""

FAILED=()
for pkg in "${PACKAGES[@]}"; do
    if dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
        info "  ${pkg} already installed — skipping."
    else
        if apt_output=$(apt-get install -y --no-install-recommends "${pkg}" 2>&1); then
            ok "  ${pkg} installed."
        else
            warn "  ${pkg} FAILED to install."
            warn "  Output: $(echo "${apt_output}" | tail -3)"
            FAILED+=("${pkg}")
        fi
    fi
done

# ── Report failures ───────────────────────────────────────────────────────────
echo ""
if [[ ${#FAILED[@]} -gt 0 ]]; then
    warn "The following packages could not be installed:"
    for pkg in "${FAILED[@]}"; do
        warn "  - ${pkg}"
    done
    warn "Check your network connection and apt sources."
fi

# ── Tip: Tails Additional Software ───────────────────────────────────────────
echo ""
info "TIP: To auto-install packages on every boot, use Tails' built-in"
info "'Additional Software' feature (requires Persistent Storage enabled):"
info "  Applications → Tails → Additional Software"

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  Package installation complete.               ${NC}"
echo -e "${YELLOW}  Remember: packages are SESSION-ONLY.         ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
