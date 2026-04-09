#!/usr/bin/env bash
# =============================================================================
# 06-verify.sh — Post-setup hardening audit
# =============================================================================
# PURPOSE : Read-only audit that checks whether every hardening measure
#           applied by scripts 01 and 02 is currently active.  Prints a
#           PASS / FAIL / WARN table so you know at a glance what is (and
#           is not) in effect.  Makes NO changes to the system.
#
# PERSISTENCE: SESSION-ONLY — read-only, no changes.
# REQUIRES : sudo / admin password for reading some kernel state.
# USAGE    : bash scripts/06-verify.sh
# =============================================================================

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo -e "  ${GREEN}[PASS]${NC}  $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo -e "  ${RED}[FAIL]${NC}  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC}  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
info() { echo -e "  ${CYAN}[INFO]${NC}  $*"; }

# ── Require root (sudo) ───────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    exec sudo --preserve-env=HOME,USER bash "$0" "$@"
fi

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — Post-Setup Hardening Audit        ${NC}"
echo -e "${CYAN}  [READ-ONLY] — No changes are made            ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# ── Helper: check a sysctl value ─────────────────────────────────────────────
# check_sysctl <key> <expected_value> <description>
check_sysctl() {
    local key="$1"
    local expected="$2"
    local desc="$3"
    local actual
    actual=$(sysctl -n "${key}" 2>/dev/null || echo "UNAVAILABLE")
    if [[ "${actual}" == "${expected}" ]]; then
        pass "${desc} (${key} = ${actual})"
    elif [[ "${actual}" == "UNAVAILABLE" ]]; then
        warn "${desc} — ${key} not available on this kernel"
    else
        fail "${desc} — ${key} = ${actual} (expected ${expected})"
    fi
}

# ── 1. IPv6 disabled ─────────────────────────────────────────────────────────
echo "── IPv6 ─────────────────────────────────────────────────────────────────"
check_sysctl "net.ipv6.conf.all.disable_ipv6"     "1" "IPv6 disabled (all)"
check_sysctl "net.ipv6.conf.default.disable_ipv6" "1" "IPv6 disabled (default)"
check_sysctl "net.ipv6.conf.lo.disable_ipv6"      "1" "IPv6 disabled (loopback)"
echo ""

# ── 2. Kernel hardening ───────────────────────────────────────────────────────
echo "── Kernel hardening ─────────────────────────────────────────────────────"
check_sysctl "kernel.randomize_va_space"     "2" "ASLR fully enabled"
check_sysctl "kernel.yama.ptrace_scope"      "1" "ptrace restricted to parent-child"
check_sysctl "kernel.kptr_restrict"          "2" "Kernel pointer exposure restricted"
check_sysctl "kernel.dmesg_restrict"         "1" "dmesg restricted to root"
check_sysctl "kernel.sysrq"                  "0" "SysRq key disabled"
check_sysctl "kernel.perf_event_paranoid"    "3" "perf_event access restricted"
check_sysctl "fs.suid_dumpable"              "0" "setuid core dumps disabled"
check_sysctl "fs.protected_hardlinks"        "1" "Hardlink attack protection"
check_sysctl "fs.protected_symlinks"         "1" "Symlink attack protection"
echo ""

# ── 3. Network hardening (sysctl) ────────────────────────────────────────────
echo "── Network hardening (sysctl) ───────────────────────────────────────────"
check_sysctl "net.ipv4.conf.all.accept_source_route"     "0" "IP source routing disabled"
check_sysctl "net.ipv4.conf.all.accept_redirects"        "0" "ICMP redirects rejected"
check_sysctl "net.ipv4.conf.all.send_redirects"          "0" "ICMP redirect sending disabled"
check_sysctl "net.ipv4.conf.all.rp_filter"               "1" "Reverse-path filtering enabled"
check_sysctl "net.ipv4.tcp_syncookies"                   "1" "SYN cookies enabled"
check_sysctl "net.ipv4.icmp_echo_ignore_broadcasts"      "1" "ICMP broadcast pings ignored"
check_sysctl "net.ipv4.conf.all.log_martians"            "1" "Martian packet logging enabled"
check_sysctl "net.ipv4.tcp_timestamps"                   "0" "TCP timestamps disabled"
echo ""

# ── 4. iptables INPUT rules ───────────────────────────────────────────────────
echo "── iptables INPUT rules ─────────────────────────────────────────────────"
if command -v iptables &>/dev/null; then
    IPT_LIST=$(iptables -L INPUT -n 2>/dev/null || echo "")

    if echo "${IPT_LIST}" | grep -q "state INVALID"; then
        pass "DROP INVALID packets rule present"
    else
        fail "DROP INVALID packets rule not found in INPUT chain"
    fi

    if echo "${IPT_LIST}" | grep -qE "ESTABLISHED,RELATED|ctstate ESTABLISHED"; then
        pass "ESTABLISHED/RELATED traffic allowed"
    else
        warn "ESTABLISHED/RELATED rule not found (may be in a sub-chain)"
    fi

    INPUT_POLICY=$(iptables -L INPUT -n 2>/dev/null | head -1 | awk '{print $NF}')
    if [[ "${INPUT_POLICY}" == "DROP" || "${INPUT_POLICY}" == "ACCEPT" ]]; then
        info "INPUT chain policy: ${INPUT_POLICY}"
    fi
else
    warn "iptables command not found"
fi
echo ""

# ── 5. ip6tables policy ───────────────────────────────────────────────────────
echo "── ip6tables (IPv6 firewall) ─────────────────────────────────────────────"
if command -v ip6tables &>/dev/null; then
    for chain in INPUT FORWARD OUTPUT; do
        policy=$(ip6tables -L "${chain}" -n 2>/dev/null | head -1 | awk '{print $NF}')
        if [[ "${policy}" == "DROP" ]]; then
            pass "ip6tables ${chain} policy = DROP"
        else
            fail "ip6tables ${chain} policy = ${policy:-unknown} (expected DROP)"
        fi
    done
else
    warn "ip6tables command not found"
fi
echo ""

# ── 6. USB auto-authorisation ─────────────────────────────────────────────────
echo "── USB auto-authorisation ───────────────────────────────────────────────"
USB_AUTH_PATH="/sys/bus/usb/drivers/usb/authorized_default"
if [[ -f "${USB_AUTH_PATH}" ]]; then
    USB_AUTH=$(cat "${USB_AUTH_PATH}" 2>/dev/null || echo "?")
    if [[ "${USB_AUTH}" == "0" ]]; then
        pass "USB auto-authorisation disabled (authorized_default = 0)"
    else
        fail "USB auto-authorisation still enabled (authorized_default = ${USB_AUTH})"
    fi
else
    warn "USB authorized_default path not found (${USB_AUTH_PATH})"
fi
echo ""

# ── 7. Firewire ───────────────────────────────────────────────────────────────
echo "── Firewire ─────────────────────────────────────────────────────────────"
if lsmod 2>/dev/null | grep -q "firewire_ohci"; then
    fail "firewire_ohci module is still loaded (DMA attack risk)"
else
    pass "firewire_ohci module not loaded"
fi

if [[ -f /etc/modprobe.d/tails-no-firewire.conf ]]; then
    pass "Firewire blacklist file present (/etc/modprobe.d/tails-no-firewire.conf)"
else
    warn "Firewire blacklist file not found (run 02-security-hardening.sh)"
fi
echo ""

# ── 8. Tor service ────────────────────────────────────────────────────────────
echo "── Tor ──────────────────────────────────────────────────────────────────"
if systemctl is-active --quiet tor@default 2>/dev/null || \
   systemctl is-active --quiet tor        2>/dev/null; then
    pass "Tor service is running"
else
    fail "Tor service is NOT running"
fi

if command -v torsocks &>/dev/null; then
    if torsocks curl -s --max-time 10 https://check.torproject.org/api/ip 2>/dev/null \
        | grep -q '"IsTor":true'; then
        pass "Traffic is routed through Tor (confirmed via check.torproject.org)"
    else
        warn "Could not confirm Tor routing — network may be offline"
    fi
fi
echo ""

# ── 9. Screen lock (GNOME idle delay) ────────────────────────────────────────
echo "── Screen lock ──────────────────────────────────────────────────────────"
TAILS_USER="${SUDO_USER:-amnesia}"
if command -v gsettings &>/dev/null; then
    IDLE_DELAY=$(sudo -u "${TAILS_USER}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "${TAILS_USER}")/bus" \
        gsettings get org.gnome.desktop.session idle-delay 2>/dev/null || echo "unknown")
    LOCK_ENABLED=$(sudo -u "${TAILS_USER}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "${TAILS_USER}")/bus" \
        gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null || echo "unknown")

    if [[ "${LOCK_ENABLED}" == "true" ]]; then
        pass "GNOME screen lock enabled"
    else
        warn "GNOME screen lock state: ${LOCK_ENABLED}"
    fi

    if [[ "${IDLE_DELAY}" =~ ^[0-9]+$ ]] && [[ "${IDLE_DELAY}" -le 600 ]]; then
        pass "GNOME idle delay = ${IDLE_DELAY}s (≤ 600s)"
    else
        warn "GNOME idle delay = ${IDLE_DELAY} (consider setting to ≤ 300s)"
    fi
else
    warn "gsettings not available — cannot check screen lock settings"
fi
echo ""

# ── 10. MAC address randomisation ────────────────────────────────────────────
echo "── MAC address randomisation ────────────────────────────────────────────"
for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v lo); do
    CURRENT_MAC=$(ip link show "${iface}" 2>/dev/null | awk '/ether/{print $2}')
    [[ -z "${CURRENT_MAC}" ]] && continue
    FIRST_BYTE=$(echo "${CURRENT_MAC}" | cut -d: -f1)
    if (( 16#${FIRST_BYTE} & 0x02 )); then
        pass "${iface}: MAC ${CURRENT_MAC} is randomised (locally administered bit set)"
    else
        warn "${iface}: MAC ${CURRENT_MAC} appears to be the hardware address"
    fi
done
echo ""

# ── 11. Core dumps ────────────────────────────────────────────────────────────
echo "── Core dumps ───────────────────────────────────────────────────────────"
CORE_PATTERN=$(sysctl -n kernel.core_pattern 2>/dev/null || echo "unknown")
if [[ "${CORE_PATTERN}" == "|/bin/false" ]]; then
    pass "Core dumps disabled (kernel.core_pattern = |/bin/false)"
else
    fail "Core dumps may be enabled (kernel.core_pattern = ${CORE_PATTERN})"
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo -e "${CYAN}================================================${NC}"
echo -e "  Results: ${GREEN}${PASS_COUNT} PASS${NC}  ${RED}${FAIL_COUNT} FAIL${NC}  ${YELLOW}${WARN_COUNT} WARN${NC}"
echo ""
if [[ ${FAIL_COUNT} -gt 0 ]]; then
    echo -e "  ${RED}Some checks FAILED.${NC} Run the relevant hardening scripts:"
    echo -e "    bash scripts/01-network-hardening.sh"
    echo -e "    bash scripts/02-security-hardening.sh"
elif [[ ${WARN_COUNT} -gt 0 ]]; then
    echo -e "  ${YELLOW}All critical checks passed; review warnings above.${NC}"
else
    echo -e "  ${GREEN}All checks passed. Hardening is fully active.${NC}"
fi
echo -e "${CYAN}================================================${NC}"
echo ""

[[ ${FAIL_COUNT} -eq 0 ]]
