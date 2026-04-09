#!/usr/bin/env bash
# =============================================================================
# 00-setup-check.sh — Pre-flight environment checks
# =============================================================================
# PURPOSE : Verify that all prerequisites are met before running the other
#           hardening scripts.  Run this first.
# PERSISTENCE: SESSION-ONLY — makes no changes to the system.
# REQUIRES: Nothing special.  Run as the amnesia user.
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Colour

pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "  ${CYAN}[INFO]${NC} $*"; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — Pre-flight Setup Check            ${NC}"
echo -e "${CYAN}  [SESSION-ONLY] — No changes are made         ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

ERRORS=0

# ── 1. Detect Tails OS ───────────────────────────────────────────────────────
echo "Checking Tails OS..."
if grep -qi "tails" /etc/os-release 2>/dev/null; then
    TAILS_VERSION=$(grep "^TAILS_VERSION_ID" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown")
    pass "Running on Tails OS (version: ${TAILS_VERSION:-unknown})"
else
    fail "This does not appear to be Tails OS."
    warn "These scripts are designed specifically for Tails 6.x."
    ERRORS=$((ERRORS + 1))
fi

# ── 2. Check current user ────────────────────────────────────────────────────
echo ""
echo "Checking user environment..."
CURRENT_USER=$(whoami)
if [[ "${CURRENT_USER}" == "amnesia" ]]; then
    pass "Running as the expected Tails user: amnesia"
else
    warn "Current user is '${CURRENT_USER}', expected 'amnesia'."
    warn "Behaviour may differ from the intended Tails default."
fi

# ── 3. Admin password / sudo access ─────────────────────────────────────────
echo ""
echo "Checking admin (sudo) access..."
if sudo -n true 2>/dev/null; then
    pass "sudo is available without a password prompt (admin password already cached)."
elif sudo -v 2>/dev/null; then
    pass "sudo is available (you may be prompted for your admin password)."
else
    fail "sudo is NOT available. Did you set an admin password in the Greeter?"
    info "Reboot Tails and set an admin password in the login screen."
    ERRORS=$((ERRORS + 1))
fi

# ── 4. Persistent Storage ───────────────────────────────────────────────────
echo ""
echo "Checking Persistent Storage..."
PERSIST_DIR="/live/persistence/TailsData_unlocked"
if [[ -d "${PERSIST_DIR}" ]]; then
    pass "Persistent Storage is mounted at ${PERSIST_DIR}"
    # Show used space
    USED=$(df -h "${PERSIST_DIR}" 2>/dev/null | awk 'NR==2{print $3 " used of " $2}' || echo "unknown")
    info "Disk usage: ${USED}"
else
    warn "Persistent Storage not found at ${PERSIST_DIR}."
    warn "05-persistent-setup.sh will not work without it."
    warn "Enable Persistent Storage via Applications → Tails → Configure persistent volume."
fi

# ── 5. Tor connectivity ──────────────────────────────────────────────────────
echo ""
echo "Checking Tor connectivity..."
if systemctl is-active --quiet tor@default 2>/dev/null || systemctl is-active --quiet tor 2>/dev/null; then
    pass "Tor service is running."
else
    warn "Tor service does not appear to be running."
    warn "Network operations (e.g. 04-package-install.sh) require Tor."
fi

# Quick Tor check via the control port or torsocks
if command -v torsocks &>/dev/null; then
    if torsocks curl -s --max-time 10 https://check.torproject.org/api/ip 2>/dev/null | grep -q '"IsTor":true'; then
        pass "Tor is working — traffic is being routed through Tor."
    else
        warn "Could not confirm Tor routing (network may not be connected)."
    fi
fi

# ── 6. Required commands ─────────────────────────────────────────────────────
echo ""
echo "Checking required commands..."
for cmd in iptables sysctl ip curl apt-get git; do
    if command -v "${cmd}" &>/dev/null; then
        pass "  ${cmd}"
    else
        warn "  ${cmd} not found — some scripts may not function."
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
if [[ ${ERRORS} -eq 0 ]]; then
    echo -e "${GREEN}  All critical checks passed. Ready to proceed.${NC}"
else
    echo -e "${RED}  ${ERRORS} critical check(s) failed. Review the output above.${NC}"
fi
echo -e "${CYAN}================================================${NC}"
echo ""

exit "${ERRORS}"
