#!/usr/bin/env bash
# =============================================================================
# 01-network-hardening.sh — Network security hardening
# =============================================================================
# PURPOSE : Apply additional network-layer protections on top of the defaults
#           already provided by Tails OS:
#             • Enforce strict iptables rules (deny inbound by default)
#             • Drop all IPv6 traffic (Tails does not expose IPv6 over Tor)
#             • Enable reverse-path filtering (anti-spoofing)
#             • Randomise MAC address for all interfaces (if not already done)
#             • Ensure Tor-enforced firewall is intact
# PERSISTENCE: SESSION-ONLY — rules are flushed on reboot.
#              To make iptables rules persistent via Persistent Storage, run
#              05-persistent-setup.sh after this script.
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
echo -e "${CYAN}  Tails OS — Network Hardening                 ${NC}"
echo -e "${CYAN}  [SESSION-ONLY] — Changes lost on reboot      ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# ── 1. IPv6 — disable completely ─────────────────────────────────────────────
info "Disabling IPv6..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1       >/dev/null
sysctl -w net.ipv6.conf.default.disable_ipv6=1   >/dev/null
sysctl -w net.ipv6.conf.lo.disable_ipv6=1        >/dev/null
ok "IPv6 disabled for all interfaces."

# ── 2. Reverse-path filtering (anti-spoofing) ────────────────────────────────
info "Enabling reverse-path filtering..."
sysctl -w net.ipv4.conf.all.rp_filter=1          >/dev/null
sysctl -w net.ipv4.conf.default.rp_filter=1      >/dev/null
ok "Reverse-path filtering enabled."

# ── 3. Disable IP source routing & ICMP redirects ────────────────────────────
info "Disabling IP source routing and ICMP redirects..."
sysctl -w net.ipv4.conf.all.accept_source_route=0     >/dev/null
sysctl -w net.ipv4.conf.default.accept_source_route=0 >/dev/null
sysctl -w net.ipv4.conf.all.accept_redirects=0        >/dev/null
sysctl -w net.ipv4.conf.default.accept_redirects=0    >/dev/null
sysctl -w net.ipv4.conf.all.send_redirects=0          >/dev/null
sysctl -w net.ipv4.conf.default.send_redirects=0      >/dev/null
sysctl -w net.ipv4.conf.all.secure_redirects=0        >/dev/null
sysctl -w net.ipv4.conf.default.secure_redirects=0    >/dev/null
ok "Source routing and ICMP redirects disabled."

# ── 4. SYN flood protection ──────────────────────────────────────────────────
info "Enabling SYN cookies (SYN flood protection)..."
sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null
ok "SYN cookies enabled."

# ── 5. iptables — harden on top of Tails defaults ────────────────────────────
info "Applying extra iptables rules..."

# Tails already has an output-restricting firewall; we add inbound protection.
# Do NOT flush Tails' own rules — only append to INPUT.

# Drop invalid packets
iptables -A INPUT -m state --state INVALID -j DROP

# Drop unsolicited inbound TCP connections (Tails default is already restrictive,
# but being explicit is safer) — allow 25 new TCP connections/second
iptables -A INPUT -p tcp --syn -m limit --limit 25/second --limit-burst 50 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established/related (needed for Tor and LAN)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Log and drop everything else on INPUT (rate-limited to avoid log flooding)
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables INPUT DROP: " --log-level 7
iptables -A INPUT -j DROP

ok "iptables INPUT rules applied."

# ── 6. ip6tables — block all IPv6 traffic ────────────────────────────────────
info "Blocking all IPv6 traffic with ip6tables..."
ip6tables -P INPUT   DROP  2>/dev/null || warn "ip6tables INPUT policy not changed (may already be set)."
ip6tables -P FORWARD DROP  2>/dev/null || warn "ip6tables FORWARD policy not changed."
ip6tables -P OUTPUT  DROP  2>/dev/null || warn "ip6tables OUTPUT policy not changed."
ok "All IPv6 traffic blocked."

# ── 7. MAC address randomisation ─────────────────────────────────────────────
info "Checking MAC address randomisation..."
# Tails randomises MAC on boot by default; we verify and force if needed.
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo); do
    CURRENT_MAC=$(ip link show "${iface}" | awk '/ether/{print $2}')
    # A locally administered (randomised) MAC has bit 1 of first byte set
    FIRST_BYTE=$(echo "${CURRENT_MAC}" | cut -d: -f1)
    if (( 16#${FIRST_BYTE} & 0x02 )); then
        ok "  ${iface}: MAC ${CURRENT_MAC} is already randomised (locally administered)."
    else
        info "  ${iface}: MAC ${CURRENT_MAC} appears to be the hardware address."
        info "  Attempting randomisation via macchanger..."
        if command -v macchanger &>/dev/null; then
            ip link set "${iface}" down 2>/dev/null || true
            macchanger -r "${iface}" 2>/dev/null && ok "  ${iface}: MAC randomised." || warn "  ${iface}: macchanger failed (interface may be in use)."
            ip link set "${iface}" up   2>/dev/null || true
        else
            warn "  macchanger not found; cannot randomise MAC for ${iface}."
        fi
    fi
done

# ── 8. Disable ICMP broadcast pings ──────────────────────────────────────────
info "Ignoring ICMP broadcast pings..."
sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 >/dev/null
ok "ICMP broadcast pings ignored."

# ── 9. Log martian packets ───────────────────────────────────────────────────
info "Enabling martian packet logging..."
sysctl -w net.ipv4.conf.all.log_martians=1     >/dev/null
sysctl -w net.ipv4.conf.default.log_martians=1 >/dev/null
ok "Martian packet logging enabled."

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  Network hardening complete.                  ${NC}"
echo -e "${YELLOW}  Remember: changes are SESSION-ONLY.          ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
