#!/usr/bin/env bash
# =============================================================================
# configs/network/iptables-rules.sh — Extra iptables hardening rules
# =============================================================================
# PURPOSE : Additional iptables rules to complement Tails' built-in firewall.
#           This script is designed to be sourced by 01-network-hardening.sh
#           or called directly via the persistent autostart mechanism set up
#           by 05-persistent-setup.sh.
#
# PERSISTENCE: Called from XDG autostart by 05-persistent-setup.sh.
#              When run standalone it is SESSION-ONLY.
# REQUIRES : root (sudo).
# =============================================================================

set -uo pipefail

# Helper: run iptables, log failures but continue (rules may already exist)
ipt() {
    if ! iptables "$@" 2>/dev/null; then
        echo "Warning: iptables $* failed (rule may already exist)" >&2
    fi
}

ipt6() {
    if ! ip6tables "$@" 2>/dev/null; then
        echo "Warning: ip6tables $* failed" >&2
    fi
}

# Tails already enforces all traffic through Tor via its own iptables chains.
# We add INPUT-level defences; we must NOT modify the OUTPUT chain or we risk
# breaking the Tor enforcement.

# ── Drop invalid state packets ───────────────────────────────────────────────
ipt -A INPUT -m conntrack --ctstate INVALID -j DROP

# ── Allow loopback ────────────────────────────────────────────────────────────
ipt -A INPUT -i lo -j ACCEPT

# ── Allow established/related inbound ────────────────────────────────────────
ipt -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ── ICMP: allow ping but rate-limit ──────────────────────────────────────────
ipt -A INPUT -p icmp --icmp-type echo-request \
    -m limit --limit 1/second --limit-burst 5 -j ACCEPT

# ── SYN flood protection: rate-limit new TCP connections ─────────────────────
ipt -A INPUT -p tcp --syn \
    -m limit --limit 25/second --limit-burst 50 -j ACCEPT
ipt -A INPUT -p tcp --syn -j DROP

# ── Port scan protection: log and block NULL / XMAS / FIN scans ──────────────
# NULL scan
ipt -A INPUT -p tcp --tcp-flags ALL NONE \
    -m limit --limit 3/min -j LOG --log-prefix "NULL scan: "
ipt -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# XMAS scan
ipt -A INPUT -p tcp --tcp-flags ALL ALL \
    -m limit --limit 3/min -j LOG --log-prefix "XMAS scan: "
ipt -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# FIN scan
ipt -A INPUT -p tcp --tcp-flags ACK,FIN FIN \
    -m limit --limit 3/min -j LOG --log-prefix "FIN scan: "
ipt -A INPUT -p tcp --tcp-flags ACK,FIN FIN -j DROP

# ── Block all other inbound by default ───────────────────────────────────────
ipt -A INPUT \
    -m limit --limit 5/min -j LOG --log-prefix "INPUT DROP: " --log-level 7
ipt -A INPUT -j DROP

# ── IPv6: block everything ────────────────────────────────────────────────────
for table in INPUT FORWARD OUTPUT; do
    ipt6 -P "${table}" DROP
done

echo "iptables rules applied successfully."
