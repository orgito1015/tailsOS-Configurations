#!/usr/bin/env bash
# =============================================================================
# 05-persistent-setup.sh — Wire configuration files into Persistent Storage
# =============================================================================
# PURPOSE : Copy selected configuration files from this repository into the
#           Tails Persistent Storage volume and set up the dot-file mechanism
#           so they are loaded automatically on the next boot.
#
#           Tails loads dotfiles from:
#             /live/persistence/TailsData_unlocked/dotfiles/
#           Any file placed there is symlinked into ~/  on boot.
#
#           This script also writes a persistent sysctl configuration file so
#           that the kernel hardening parameters survive reboots.
#
# PERSISTENCE: ** SURVIVES REBOOT ** — this is the whole point.
# REQUIRES : sudo / admin password.
#            Persistent Storage must be enabled and unlocked.
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

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PERSIST_ROOT="/live/persistence/TailsData_unlocked"
PERSIST_DOTFILES="${PERSIST_ROOT}/dotfiles"

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — Persistent Storage Setup          ${NC}"
echo -e "${CYAN}  ** CHANGES SURVIVE REBOOT **                 ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# ── Verify Persistent Storage ─────────────────────────────────────────────────
if [[ ! -d "${PERSIST_ROOT}" ]]; then
    die "Persistent Storage not found at ${PERSIST_ROOT}.\n  Enable it via: Applications → Tails → Configure Persistent Volume"
fi
ok "Persistent Storage found at ${PERSIST_ROOT}."

# ── 1. Dotfiles ───────────────────────────────────────────────────────────────
info "Setting up persistent dotfiles..."
mkdir -p "${PERSIST_DOTFILES}"

for dotfile in "${REPO_ROOT}/configs/dotfiles"/.[^.]*; do
    [[ -f "${dotfile}" ]] || continue
    filename="$(basename "${dotfile}")"
    dest="${PERSIST_DOTFILES}/${filename}"

    cp "${dotfile}" "${dest}"
    chmod 600 "${dest}"
    ok "  Copied ${filename} → ${dest}"
done

# Ensure persistent/dotfiles directory is listed in persistence.conf
PERSIST_CONF="${PERSIST_ROOT}/persistence.conf"
if [[ -f "${PERSIST_CONF}" ]]; then
    if ! grep -q "^/home/amnesia$" "${PERSIST_CONF}"; then
        # The dotfiles mechanism uses a special directory; the home persistence
        # is separate.  Dotfiles dir is handled by Tails automatically when the
        # directory exists — no explicit entry needed in persistence.conf.
        info "persistence.conf present; Tails will automatically load dotfiles from ${PERSIST_DOTFILES}."
    fi
else
    warn "persistence.conf not found.  Tails may not be configured to use persistent dotfiles."
    warn "Enable 'Dotfiles' in: Applications → Tails → Configure Persistent Volume"
fi

# ── 2. Persistent sysctl hardening ───────────────────────────────────────────
info "Installing persistent sysctl hardening configuration..."
# Tails reads /etc/sysctl.d/ on boot.  We can drop a config there via
# a persistence.conf entry, but the simpler approach for Tails is to use
# the dotfiles mechanism for /etc files via the 'live-additional-software'
# or custom persistent /etc mount.  We document both approaches.
#
# The safest approach for Tails 6.x: use the dotfiles feature together with
# a custom shell script placed in ~/.config/autostart/ (via XDG autostart)
# that runs the sysctl commands on each login.

AUTOSTART_DIR="${PERSIST_DOTFILES}/.config/autostart"
mkdir -p "${AUTOSTART_DIR}"

SYSCTL_AUTOSTART="${AUTOSTART_DIR}/tails-sysctl-hardening.desktop"
SYSCTL_CONF_SRC="${REPO_ROOT}/configs/security/sysctl-hardening.conf"

if [[ -f "${SYSCTL_CONF_SRC}" ]]; then
    # Copy sysctl config into persistent dotfiles
    PERSIST_SYSCTL_DIR="${PERSIST_DOTFILES}/.config/tails-hardening"
    mkdir -p "${PERSIST_SYSCTL_DIR}"
    cp "${SYSCTL_CONF_SRC}" "${PERSIST_SYSCTL_DIR}/sysctl-hardening.conf"
    ok "  Sysctl config copied to ${PERSIST_SYSCTL_DIR}/sysctl-hardening.conf"
fi

# Write an XDG autostart .desktop file that applies sysctl on each GNOME login
cat > "${SYSCTL_AUTOSTART}" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Tails Security Hardening
Comment=Apply kernel hardening sysctl parameters at session start
Exec=bash -c "sudo sysctl -p ~/.config/tails-hardening/sysctl-hardening.conf 2>/dev/null || true"
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
DESKTOP

chmod 644 "${SYSCTL_AUTOSTART}"
ok "  XDG autostart entry created: ${SYSCTL_AUTOSTART}"

# ── 3. Persistent iptables rules via autostart ────────────────────────────────
info "Setting up persistent iptables rules via autostart..."
IPTABLES_SRC="${REPO_ROOT}/configs/network/iptables-rules.sh"
PERSIST_SCRIPTS_DIR="${PERSIST_DOTFILES}/.config/tails-hardening"
mkdir -p "${PERSIST_SCRIPTS_DIR}"

if [[ -f "${IPTABLES_SRC}" ]]; then
    cp "${IPTABLES_SRC}" "${PERSIST_SCRIPTS_DIR}/iptables-rules.sh"
    chmod 750 "${PERSIST_SCRIPTS_DIR}/iptables-rules.sh"
    ok "  iptables rules script copied to ${PERSIST_SCRIPTS_DIR}/iptables-rules.sh"
fi

IPTABLES_AUTOSTART="${AUTOSTART_DIR}/tails-iptables-hardening.desktop"
cat > "${IPTABLES_AUTOSTART}" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Tails Firewall Hardening
Comment=Apply extra iptables hardening rules at session start
Exec=bash -c "sudo bash ~/.config/tails-hardening/iptables-rules.sh 2>/dev/null || true"
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
DESKTOP

chmod 644 "${IPTABLES_AUTOSTART}"
ok "  XDG autostart entry created: ${IPTABLES_AUTOSTART}"

# ── 4. Store this repo in Persistent Storage ─────────────────────────────────
info "Checking if repo should be stored in Persistent Storage..."
PERSIST_HOME="${PERSIST_ROOT}/home/amnesia"
if [[ -d "${PERSIST_ROOT}/home" ]]; then
    REPO_DEST="${PERSIST_HOME}/tailsOS-Configurations"
    if [[ ! -d "${REPO_DEST}" ]]; then
        mkdir -p "${PERSIST_HOME}"
        cp -r "${REPO_ROOT}" "${REPO_DEST}"
        chown -R "$(id -u "${SUDO_USER:-amnesia}"):$(id -g "${SUDO_USER:-amnesia}")" "${REPO_DEST}" 2>/dev/null || true
        ok "  Repo copied to Persistent Storage: ${REPO_DEST}"
    else
        info "  Repo already exists at ${REPO_DEST} — not overwriting."
    fi
else
    warn "  Personal Files persistence not enabled.  The repo will not be saved."
    info "  Enable 'Personal Data' in: Applications → Tails → Configure Persistent Volume"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  Persistent setup complete.                   ${NC}"
echo -e "${GREEN}  The following will survive reboot:           ${NC}"
echo -e "${GREEN}    • Dotfiles in ~/.config/tails-hardening/   ${NC}"
echo -e "${GREEN}    • GNOME autostart entries                  ${NC}"
echo -e "${GREEN}    • iptables rules (applied at login)        ${NC}"
echo -e "${GREEN}    • sysctl hardening (applied at login)      ${NC}"
echo -e "${YELLOW}  NOTE: Requires 'Dotfiles' feature enabled in  ${NC}"
echo -e "${YELLOW}  Persistent Storage configuration.             ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
