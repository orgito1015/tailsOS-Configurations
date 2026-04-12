#!/usr/bin/env bash
# =============================================================================
# run-all.sh — Run all session-hardening scripts in sequence
# =============================================================================
# PURPOSE : Convenience wrapper that executes scripts 00 through 04 in order.
#           Each script is run independently; a failure in one will not prevent
#           the others from running (unless --strict is passed).
#
# PERSISTENCE: SESSION-ONLY — this script does NOT run 05-persistent-setup.sh.
#              To persist settings, run 05-persistent-setup.sh separately.
# REQUIRES : sudo / admin password set at Greeter.
# USAGE    : bash run-all.sh [--strict]
#              --strict  Abort on first script failure
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
fail()  { echo -e "  ${RED}[FAIL]${NC}  $*"; }

STRICT=false
if [[ "${1:-}" == "--strict" ]]; then
    STRICT=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPTS=(
    "00-setup-check.sh"
    "01-network-hardening.sh"
    "02-security-hardening.sh"
    "03-dotfiles-setup.sh"
    "04-package-install.sh"
    "08-cybersecurity-tools.sh"
)

echo ""
echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}  Tails OS — Full Session Setup                      ${NC}"
echo -e "${CYAN}  [SESSION-ONLY] — run 05-persistent-setup.sh        ${NC}"
echo -e "${CYAN}  separately to make changes survive reboot.         ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo ""

PASSED=0
FAILED=0
SKIPPED=0

for script in "${SCRIPTS[@]}"; do
    full_path="${SCRIPT_DIR}/${script}"
    echo -e "${CYAN}──────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}  Running: ${script}${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────────${NC}"

    if [[ ! -f "${full_path}" ]]; then
        warn "Script not found: ${full_path} — skipping."
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if bash "${full_path}"; then
        ok "${script} completed successfully."
        PASSED=$((PASSED + 1))
    else
        EXIT_CODE=$?
        fail "${script} exited with code ${EXIT_CODE}."
        FAILED=$((FAILED + 1))
        if [[ "${STRICT}" == true ]]; then
            fail "Aborting due to --strict mode."
            exit "${EXIT_CODE}"
        fi
    fi
    echo ""
done

# ── Final summary ─────────────────────────────────────────────────────────────
echo -e "${CYAN}======================================================${NC}"
echo -e "  Results: ${GREEN}${PASSED} passed${NC}  ${RED}${FAILED} failed${NC}  ${YELLOW}${SKIPPED} skipped${NC}"
echo ""

if [[ ${FAILED} -gt 0 ]]; then
    warn "Some scripts failed.  Review the output above."
    EXIT_STATUS=1
else
    ok "All scripts completed successfully."
    EXIT_STATUS=0
fi

echo ""
info "To persist settings across reboots, run:"
info "  bash ${SCRIPT_DIR}/05-persistent-setup.sh"
echo -e "${CYAN}======================================================${NC}"
echo ""

exit "${EXIT_STATUS}"
