#!/usr/bin/env bash
# =============================================================================
# 03-dotfiles-setup.sh — Apply dotfiles and shell configuration
# =============================================================================
# PURPOSE : Copy the dotfiles from this repository into the current user's
#           home directory so that the shell and editor are configured
#           immediately for this session.
#
#           By default this is SESSION-ONLY.  Run 05-persistent-setup.sh
#           afterwards to place the dotfiles in Persistent Storage so they
#           are automatically loaded on the next Tails boot.
#
# PERSISTENCE: SESSION-ONLY by default.
#              Run 05-persistent-setup.sh to make dotfiles persistent.
# REQUIRES : No root needed.  Runs as the amnesia user.
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

# ── Determine repo root ───────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTFILES_DIR="${REPO_ROOT}/configs/dotfiles"

if [[ ! -d "${DOTFILES_DIR}" ]]; then
    die "Dotfiles directory not found: ${DOTFILES_DIR}"
fi

TARGET_HOME="${HOME}"

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — Dotfiles Setup                    ${NC}"
echo -e "${CYAN}  [SESSION-ONLY by default]                    ${NC}"
echo -e "${CYAN}  Source: ${DOTFILES_DIR}${NC}"
echo -e "${CYAN}  Target: ${TARGET_HOME}${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

BACKED_UP=0

# ── Helper: install a dotfile ─────────────────────────────────────────────────
install_dotfile() {
    local src="$1"
    local dest="${TARGET_HOME}/$2"
    local filename
    filename="$(basename "${src}")"

    # Back up existing file if it is not a symlink from us
    if [[ -f "${dest}" && ! -L "${dest}" ]]; then
        local backup
        backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        cp "${dest}" "${backup}"
        warn "Backed up existing ${filename} → ${backup}"
        BACKED_UP=$((BACKED_UP + 1))
    fi

    cp "${src}" "${dest}"
    ok "Installed ${filename} → ${dest}"
}

# ── Install each dotfile ──────────────────────────────────────────────────────
for dotfile in "${DOTFILES_DIR}"/.??*; do
    [[ -f "${dotfile}" ]] || continue
    filename="$(basename "${dotfile}")"

    case "${filename}" in
        .bashrc)
            install_dotfile "${dotfile}" ".bashrc"
            ;;
        .bash_aliases)
            install_dotfile "${dotfile}" ".bash_aliases"
            ;;
        .vimrc)
            install_dotfile "${dotfile}" ".vimrc"
            ;;
        .gitconfig)
            install_dotfile "${dotfile}" ".gitconfig"
            ;;
        *)
            info "Skipping unknown dotfile: ${filename}"
            ;;
    esac
done

# ── Source the new .bashrc in current session hint ───────────────────────────
echo ""
info "Dotfiles installed.  To apply shell changes immediately run:"
info "  source ~/.bashrc"

if [[ ${BACKED_UP} -gt 0 ]]; then
    warn "${BACKED_UP} file(s) were backed up with a .bak.* suffix."
fi

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  Dotfiles setup complete.                     ${NC}"
echo -e "${YELLOW}  To persist across reboots run:               ${NC}"
echo -e "${YELLOW}  bash scripts/05-persistent-setup.sh          ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
