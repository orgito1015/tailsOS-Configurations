#!/usr/bin/env bash
# =============================================================================
# setup-wizard.sh — Interactive setup wizard
# =============================================================================
# PURPOSE : Ask the user what they want to do and run only the selected
#           scripts.  Designed for new Tails users who do not want to read
#           all documentation before getting started.
#
# PERSISTENCE: SESSION-ONLY — delegates to whichever scripts you choose.
# REQUIRES : Nothing special to start.  Individual scripts will ask for
#            sudo when they need it.
# USAGE    : bash scripts/setup-wizard.sh
# =============================================================================

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

header() { echo -e "${CYAN}${BOLD}$*${NC}"; }
info()   { echo -e "  ${CYAN}[INFO]${NC}  $*"; }
ok()     { echo -e "  ${GREEN}[OK]${NC}    $*"; }
warn()   { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Utility: yes/no prompt ────────────────────────────────────────────────────
# ask_yn <question>   → returns 0 (yes) or 1 (no)
ask_yn() {
    local prompt="$1"
    local answer
    while true; do
        echo -en "  ${YELLOW}${prompt}${NC} [y/N] "
        read -r answer
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no|"") return 1 ;;
            *) echo "    Please answer y or n." ;;
        esac
    done
}

# ── Pre-flight check ──────────────────────────────────────────────────────────
clear
echo ""
echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}  Tails OS Configuration Wizard                     ${NC}"
echo -e "${CYAN}  tailsOS-Configurations                            ${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo ""
echo -e "  This wizard will ask you what you want to set up"
echo -e "  and run only those scripts.  You can always run"
echo -e "  individual scripts manually later."
echo ""
echo -e "  ${YELLOW}TIP:${NC} Read docs/FIRST-BOOT.md if this is your first"
echo -e "  time using Tails."
echo ""

# ── Collect choices ──────────────────────────────────────────────────────────
echo -e "${CYAN}── Step 1: Environment check ────────────────────────${NC}"
echo "  Recommended: always run this first to verify prerequisites."
RUN_00=false
if ask_yn "Run pre-flight environment check (00-setup-check.sh)?"; then
    RUN_00=true
fi
echo ""

echo -e "${CYAN}── Step 2: Network hardening ────────────────────────${NC}"
echo "  Applies extra firewall rules, disables IPv6, verifies MAC randomisation."
RUN_01=false
if ask_yn "Harden the network? (01-network-hardening.sh)"; then
    RUN_01=true
fi
echo ""

echo -e "${CYAN}── Step 3: System / kernel hardening ───────────────${NC}"
echo "  Applies kernel sysctl settings, disables USB auto-auth, sets screen lock."
RUN_02=false
if ask_yn "Apply kernel security hardening? (02-security-hardening.sh)"; then
    RUN_02=true
fi
echo ""

echo -e "${CYAN}── Step 4: Dotfiles / shell configuration ───────────${NC}"
echo "  Installs .bashrc, .vimrc, .bash_aliases, and .gitconfig into ~/."
RUN_03=false
if ask_yn "Set up dotfiles and shell config? (03-dotfiles-setup.sh)"; then
    RUN_03=true
fi
echo ""

echo -e "${CYAN}── Step 5: Install extra packages ───────────────────${NC}"
echo "  Installs lynis, mat2, nmap, tmux, htop, and other tools via apt over Tor."
echo -e "  ${YELLOW}Requires an active Tor connection and may take several minutes.${NC}"
RUN_04=false
if ask_yn "Install extra packages? (04-package-install.sh)"; then
    RUN_04=true
fi
echo ""

echo -e "${CYAN}── Step 5b: Install cybersecurity tools ────────────${NC}"
echo "  Installs offensive and defensive tools grouped by discipline:"
echo "  network analysis, web testing, password auditing, forensics,"
echo "  wireless security, reverse engineering, and OSINT."
echo -e "  ${YELLOW}Requires an active Tor connection.  Installation can take 10-20 minutes.${NC}"
echo -e "  ${YELLOW}Use --category <name> to install only one discipline.${NC}"
RUN_08=false
if ask_yn "Install cybersecurity tools? (08-cybersecurity-tools.sh)"; then
    RUN_08=true
fi
echo ""

echo -e "${CYAN}── Step 6: Persistent Storage setup ─────────────────${NC}"
echo "  Saves dotfiles and hardening settings so they reload on next boot."
echo -e "  ${YELLOW}Requires Persistent Storage to be enabled and unlocked.${NC}"
RUN_05=false
if ask_yn "Wire settings into Persistent Storage? (05-persistent-setup.sh)"; then
    RUN_05=true
fi
echo ""

echo -e "${CYAN}── Step 7: Verify hardening ─────────────────────────${NC}"
echo "  Read-only audit that prints a PASS/FAIL table for all hardening measures."
RUN_06=false
if ask_yn "Run post-setup verification? (06-verify.sh)"; then
    RUN_06=true
fi
echo ""

# ── Confirm ───────────────────────────────────────────────────────────────────
echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
echo "  Selected scripts:"

SELECTED=()
${RUN_00} && SELECTED+=("00-setup-check.sh")
${RUN_01} && SELECTED+=("01-network-hardening.sh")
${RUN_02} && SELECTED+=("02-security-hardening.sh")
${RUN_03} && SELECTED+=("03-dotfiles-setup.sh")
${RUN_04} && SELECTED+=("04-package-install.sh")
# 08 runs before 05 so all packages are installed before being persisted
${RUN_08} && SELECTED+=("08-cybersecurity-tools.sh")
${RUN_05} && SELECTED+=("05-persistent-setup.sh")
${RUN_06} && SELECTED+=("06-verify.sh")

if [[ ${#SELECTED[@]} -eq 0 ]]; then
    warn "No scripts selected — nothing to run."
    echo ""
    exit 0
fi

for s in "${SELECTED[@]}"; do
    echo -e "    ${GREEN}✓${NC}  ${s}"
done
echo ""

if ! ask_yn "Run the selected scripts now?"; then
    warn "Aborted — no scripts were run."
    echo ""
    exit 0
fi
echo ""

# ── Execute ───────────────────────────────────────────────────────────────────
PASSED=0
FAILED=0

run_script() {
    local name="$1"
    local full="${SCRIPT_DIR}/${name}"

    echo ""
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}  Running: ${name}${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"

    if [[ ! -f "${full}" ]]; then
        warn "${name} not found at ${full} — skipping."
        return
    fi

    if bash "${full}"; then
        ok "${name} completed successfully."
        PASSED=$((PASSED + 1))
    else
        warn "${name} exited with an error — continuing."
        FAILED=$((FAILED + 1))
    fi
}

${RUN_00} && run_script "00-setup-check.sh"
${RUN_01} && run_script "01-network-hardening.sh"
${RUN_02} && run_script "02-security-hardening.sh"
${RUN_03} && run_script "03-dotfiles-setup.sh"
${RUN_04} && run_script "04-package-install.sh"
# 08 runs before 05 so all packages are installed before being persisted
${RUN_08} && run_script "08-cybersecurity-tools.sh"
${RUN_05} && run_script "05-persistent-setup.sh"
${RUN_06} && run_script "06-verify.sh"

# ── Final summary ─────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=====================================================${NC}"
echo -e "  Wizard complete: ${GREEN}${PASSED} succeeded${NC}  ${RED}${FAILED} failed${NC}"
echo ""

if ${RUN_03}; then
    info "Dotfiles installed.  Apply them now with:"
    info "  source ~/.bashrc"
    echo ""
fi

if ! ${RUN_05}; then
    info "Changes are SESSION-ONLY and will be lost on reboot."
    info "To persist them, run:"
    info "  bash ${SCRIPT_DIR}/05-persistent-setup.sh"
    echo ""
fi

echo -e "${CYAN}=====================================================${NC}"
echo ""
