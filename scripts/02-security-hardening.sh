#!/usr/bin/env bash
# =============================================================================
# 02-security-hardening.sh — Kernel & system security hardening
# =============================================================================
# PURPOSE : Apply kernel-level and system-level hardening beyond Tails defaults:
#             • Sysctl kernel parameter hardening
#             • Restrict ptrace (process tracing/debugging) scope
#             • Restrict dmesg access for unprivileged users
#             • Enable ASLR (should already be on in Tails)
#             • Lock screen configuration
#             • Restrict USB / firewire access (USBGuard or manual)
#             • Ensure core dumps are disabled
# PERSISTENCE: SESSION-ONLY — changes are lost on reboot.
#              To persist sysctl settings, run 05-persistent-setup.sh.
# REQUIRES : sudo / admin password set at Greeter.
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

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — Security Hardening                ${NC}"
echo -e "${CYAN}  [SESSION-ONLY] — Changes lost on reboot      ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# ── 1. ASLR — ensure Address Space Layout Randomisation is on ───────────────
info "Ensuring ASLR is fully enabled..."
sysctl -w kernel.randomize_va_space=2 >/dev/null
ok "ASLR set to mode 2 (full randomisation)."

# ── 2. Restrict ptrace to parent processes only ───────────────────────────────
info "Restricting ptrace scope..."
sysctl -w kernel.yama.ptrace_scope=1 >/dev/null
ok "ptrace restricted to parent–child relationships (scope=1)."

# ── 3. Restrict dmesg access ─────────────────────────────────────────────────
info "Restricting dmesg access to root only..."
sysctl -w kernel.dmesg_restrict=1 >/dev/null
ok "dmesg restricted to privileged users."

# ── 4. Restrict kernel pointer leaks ─────────────────────────────────────────
info "Restricting kernel pointer exposure..."
sysctl -w kernel.kptr_restrict=2 >/dev/null
ok "Kernel pointer restriction set to level 2."

# ── 5. Disable core dumps ─────────────────────────────────────────────────────
info "Disabling core dumps for all processes..."
sysctl -w kernel.core_pattern="|/bin/false"  >/dev/null
ulimit -c 0
# Also configure via sysfs for setuid processes
sysctl -w fs.suid_dumpable=0 >/dev/null
ok "Core dumps disabled."

# ── 6. Restrict perf_event_open (hardware performance counters) ──────────────
info "Restricting access to performance events..."
if sysctl -w kernel.perf_event_paranoid=3 2>/dev/null; then
    ok "perf_event_paranoid set to 3."
else
    warn "Could not set kernel.perf_event_paranoid (kernel may not support it)."
fi

# ── 7. Disable kexec (kernel live replacement) ───────────────────────────────
info "Disabling kexec_load..."
if sysctl -w kernel.kexec_load_disabled=1 2>/dev/null; then
    ok "kexec_load disabled."
else
    warn "Could not disable kexec_load (may already be disabled or unsupported)."
fi

# ── 8. Restrict loading of kernel modules ────────────────────────────────────
# Note: kernel.modules_disabled is intentionally left at its default (0) to
# preserve Tor and Wi-Fi module loading.  Setting it to 1 provides the most
# locked-down configuration but prevents loading any new kernel modules.
# Uncomment the line below only after all required modules are loaded:

# ── 9. Disable SysRq key (prevents magic-key attacks) ────────────────────────
info "Restricting SysRq key..."
sysctl -w kernel.sysrq=0 >/dev/null
ok "SysRq disabled."

# ── 10. Protect hard and symlinks ────────────────────────────────────────────
info "Enabling hardlink and symlink protections..."
sysctl -w fs.protected_hardlinks=1 >/dev/null
sysctl -w fs.protected_symlinks=1  >/dev/null
ok "Hard/symlink protections enabled."

# ── 11. Disable unprivileged user namespaces (reduces attack surface) ────────
info "Restricting unprivileged user namespaces..."
if sysctl -w kernel.unprivileged_userns_clone=0 2>/dev/null; then
    ok "Unprivileged user namespace creation disabled."
else
    warn "kernel.unprivileged_userns_clone not available on this kernel."
fi

# ── 12. Network-adjacent kernel hardening ────────────────────────────────────
info "Applying network-adjacent kernel hardening..."
sysctl -w net.ipv4.tcp_timestamps=0     >/dev/null  # prevent clock fingerprinting
sysctl -w net.ipv4.tcp_sack=0           >/dev/null  # disable SACK (CVE-2019-11477 family)
sysctl -w net.core.bpf_jit_harden=2    >/dev/null 2>&1 || true
ok "Network-adjacent sysctl hardening applied."

# ── 13. Screen lock timeout ───────────────────────────────────────────────────
info "Setting screen lock timeout to 5 minutes..."
if command -v xset &>/dev/null && [[ -n "${DISPLAY:-}" ]]; then
    # X11 screen-saver: blank after 300 seconds
    sudo -u "${SUDO_USER:-amnesia}" DISPLAY="${DISPLAY:-:0}" xset s 300 300 2>/dev/null || warn "xset not available."
    ok "Screen blank timeout set to 5 minutes via xset."
else
    warn "DISPLAY not set or xset unavailable — skipping screen lock timeout."
fi

# GNOME idle/lock settings (if running GNOME, which Tails does)
if command -v gsettings &>/dev/null; then
    TAILS_USER="${SUDO_USER:-amnesia}"
    sudo -u "${TAILS_USER}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "${TAILS_USER}")/bus" \
        gsettings set org.gnome.desktop.session idle-delay 300 2>/dev/null \
        && ok "GNOME idle delay set to 300 seconds." \
        || warn "Could not set GNOME idle delay (DBUS session may not be available)."

    sudo -u "${TAILS_USER}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "${TAILS_USER}")/bus" \
        gsettings set org.gnome.desktop.screensaver lock-enabled true 2>/dev/null \
        && ok "GNOME screen lock enabled." \
        || warn "Could not enable GNOME screen lock."
fi

# ── 14. USB / firewire device restrictions ───────────────────────────────────
info "Restricting kernel USB authorization defaults..."
# Disable auto-authorisation for new USB devices (USB Guard lite approach)
# Devices already connected at boot remain authorised.
USB_AUTH_PATH="/sys/bus/usb/drivers/usb/authorized_default"
if [[ -f "${USB_AUTH_PATH}" ]]; then
    echo 0 > "${USB_AUTH_PATH}" 2>/dev/null && ok "USB auto-authorisation disabled." \
        || warn "Could not disable USB auto-authorisation."
else
    warn "USB authorized_default sysfs path not found."
fi

# Disable Firewire DMA (can be used for cold-boot/memory attacks)
if modprobe -n firewire_ohci 2>/dev/null; then
    if rmmod firewire_ohci 2>/dev/null; then
        ok "firewire_ohci module removed."
    fi
fi
echo "blacklist firewire-ohci" > /etc/modprobe.d/tails-no-firewire.conf 2>/dev/null || true

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  Security hardening complete.                 ${NC}"
echo -e "${YELLOW}  Remember: changes are SESSION-ONLY.          ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
