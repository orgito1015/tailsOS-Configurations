#!/usr/bin/env bash
# =============================================================================
# 09-desktop-setup.sh — Configure a minimalist desktop environment
# =============================================================================
# PURPOSE : Replace the default Tails GNOME desktop with a cleaner, more
#           minimalist look.  The script works in two layers:
#
#             1. GNOME tweaks (no root required) — applied immediately via
#                gsettings / dconf.  Dark theme, no animations, solid-colour
#                background, hidden top-bar clock seconds, etc.
#
#             2. Openbox install (optional, requires sudo) — installs the
#                Openbox window manager and a minimal session launcher so
#                you can choose "Openbox" at the login screen instead of
#                the full GNOME session.  Pass --openbox to enable this.
#
# PERSISTENCE: SESSION-ONLY by default.
#              Run 05-persistent-setup.sh afterwards to persist dotfiles.
#              Openbox itself must be reinstalled every session (or added via
#              Tails' "Additional Software" feature).
#
# REQUIRES : Run as the amnesia user.
#            For --openbox: sudo / admin password set at Greeter + Tor.
#
# USAGE    : bash 09-desktop-setup.sh [--openbox] [--wallpaper-color HEX]
#              --openbox              Also install Openbox (needs sudo + Tor)
#              --wallpaper-color HEX  Solid wallpaper colour, e.g. #1a1a2e
#                                     Default: #1e1e2e (Catppuccin Mocha base)
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "  ${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "  ${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "  ${RED}[ERROR]${NC} $*"; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
INSTALL_OPENBOX=false
WALLPAPER_COLOR="#1e1e2e"

for arg in "$@"; do
    case "${arg}" in
        --openbox)
            INSTALL_OPENBOX=true
            ;;
        --wallpaper-color)
            # Next argument is the colour — handled below
            ;;
        \#*)
            # Colour value following --wallpaper-color
            WALLPAPER_COLOR="${arg}"
            ;;
        *)
            warn "Unknown argument: ${arg} (ignored)"
            ;;
    esac
done

# Handle --wallpaper-color <value> as a pair
PREV=""
for arg in "$@"; do
    if [[ "${PREV}" == "--wallpaper-color" ]]; then
        WALLPAPER_COLOR="${arg}"
    fi
    PREV="${arg}"
done

# ── Sanity checks ─────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — Minimalist Desktop Setup         ${NC}"
echo -e "${CYAN}  [SESSION-ONLY by default]                   ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Must NOT run as root for gsettings (it targets the current user's dconf)
if [[ "${EUID}" -eq 0 ]]; then
    die "Run this script as the amnesia user, not as root.
       (sudo is invoked internally where needed.)"
fi

# gsettings/dconf must be available
if ! command -v gsettings &>/dev/null; then
    die "gsettings not found. Is GNOME installed?"
fi

# DISPLAY / WAYLAND must be set so gsettings can reach the session bus
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    die "No graphical session detected (DISPLAY / WAYLAND_DISPLAY unset).
       Run this script from a terminal inside the desktop session."
fi

# ── Helper: safe gsettings set ────────────────────────────────────────────────
# Returns 0 on success, prints a warning on failure (never aborts).
gs_set() {
    local schema="$1" key="$2" value="$3"
    if gsettings set "${schema}" "${key}" "${value}" 2>/dev/null; then
        ok "  ${schema} ${key} = ${value}"
    else
        warn "  Could not set ${schema} ${key} (schema or key may not exist on this version)"
    fi
}

# ── 1. GTK / Visual theme ─────────────────────────────────────────────────────
echo "Applying theme settings..."

# Dark colour scheme (GNOME 42+)
gs_set "org.gnome.desktop.interface" "color-scheme"      "'prefer-dark'"
# GTK theme — Adwaita-dark is always available on Tails
gs_set "org.gnome.desktop.interface" "gtk-theme"         "'Adwaita-dark'"
# Icon theme
gs_set "org.gnome.desktop.interface" "icon-theme"        "'Adwaita'"
# Cursor theme (keep default, just ensure it's set)
gs_set "org.gnome.desktop.interface" "cursor-theme"      "'Adwaita'"
# Disable animations for a snappier feel
gs_set "org.gnome.desktop.interface" "enable-animations" "false"
# Prefer monospace font for terminals / editors
gs_set "org.gnome.desktop.interface" "monospace-font-name" "'Monospace 11'"

# ── 2. GNOME Shell / top bar ──────────────────────────────────────────────────
echo ""
echo "Configuring GNOME Shell top bar..."

# Show weekday in the clock
gs_set "org.gnome.desktop.interface" "clock-show-weekday" "true"
# Hide seconds (reduces visual noise)
gs_set "org.gnome.desktop.interface" "clock-show-seconds" "false"

# ── 3. Solid-colour wallpaper ─────────────────────────────────────────────────
echo ""
echo "Setting solid-colour wallpaper (${WALLPAPER_COLOR})..."

# Generate a 1×1 PNG in RAM and set it as the background
WALLPAPER_FILE="/tmp/tails-minimal-wallpaper.png"

if command -v convert &>/dev/null; then
    # ImageMagick is available
    convert -size 1x1 "xc:${WALLPAPER_COLOR}" "${WALLPAPER_FILE}" 2>/dev/null && \
        ok "  Wallpaper PNG created with ImageMagick."
elif command -v python3 &>/dev/null; then
    # Fallback: write a minimal valid 1×1 PNG using Python (no extra deps)
    python3 - "${WALLPAPER_COLOR}" "${WALLPAPER_FILE}" <<'PYEOF'
import sys, struct, zlib

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

color_hex = sys.argv[1]
out_path   = sys.argv[2]

r, g, b = hex_to_rgb(color_hex)

def png_chunk(name, data):
    c = zlib.crc32(name + data) & 0xffffffff
    return struct.pack('>I', len(data)) + name + data + struct.pack('>I', c)

signature = b'\x89PNG\r\n\x1a\n'
ihdr_data = struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0)  # 1x1, 8-bit RGB
ihdr = png_chunk(b'IHDR', ihdr_data)

raw_row   = b'\x00' + bytes([r, g, b])  # filter byte + RGB
compressed = zlib.compress(raw_row, 9)
idat = png_chunk(b'IDAT', compressed)

iend = png_chunk(b'IEND', b'')

with open(out_path, 'wb') as f:
    f.write(signature + ihdr + idat + iend)
PYEOF
    ok "  Wallpaper PNG created with Python."
else
    warn "  Neither ImageMagick nor Python3 found. Skipping wallpaper PNG creation."
    WALLPAPER_FILE=""
fi

if [[ -n "${WALLPAPER_FILE}" && -f "${WALLPAPER_FILE}" ]]; then
    gs_set "org.gnome.desktop.background" "picture-options"  "'none'"
    gs_set "org.gnome.desktop.background" "picture-uri"      "'file://${WALLPAPER_FILE}'"
    gs_set "org.gnome.desktop.background" "picture-uri-dark" "'file://${WALLPAPER_FILE}'"
    gs_set "org.gnome.desktop.background" "primary-color"    "'${WALLPAPER_COLOR}'"
    gs_set "org.gnome.desktop.background" "color-shading-type" "'solid'"
fi

# ── 4. GNOME Dash / Dock (hide it) ───────────────────────────────────────────
echo ""
echo "Hiding the GNOME dock / dash-to-dock..."

# GNOME Shell built-in dash visibility (GNOME 40+)
gs_set "org.gnome.shell" "favorite-apps" "[]"

# dash-to-dock extension (present on some Tails versions)
for schema in \
    "org.gnome.shell.extensions.dash-to-dock" \
    "org.gnome.shell.extensions.dash-to-panel"; do
    if gsettings list-keys "${schema}" &>/dev/null 2>&1; then
        case "${schema}" in
            *dash-to-dock*)
                gs_set "${schema}" "dock-fixed"          "false"
                gs_set "${schema}" "autohide"            "true"
                gs_set "${schema}" "intellihide"         "true"
                gs_set "${schema}" "hide-delay"          "0.2"
                gs_set "${schema}" "show-show-apps-button" "false"
                ;;
            *dash-to-panel*)
                gs_set "${schema}" "panel-size"          "32"
                ;;
        esac
    fi
done

# ── 5. Desktop icons (disable) ────────────────────────────────────────────────
echo ""
echo "Disabling desktop icons..."

# GNOME desktop icons extension
for schema in \
    "org.gnome.shell.extensions.ding" \
    "org.gnome.nautilus.desktop"; do
    if gsettings list-keys "${schema}" &>/dev/null 2>&1; then
        case "${schema}" in
            *ding*)
                gs_set "${schema}" "show-home"   "false"
                gs_set "${schema}" "show-trash"  "false"
                ;;
            *nautilus.desktop*)
                gs_set "${schema}" "home-icon-visible"    "false"
                gs_set "${schema}" "trash-icon-visible"   "false"
                gs_set "${schema}" "volumes-visible"      "false"
                ;;
        esac
    fi
done

# ── 6. Privacy / telemetry settings ──────────────────────────────────────────
echo ""
echo "Applying privacy settings..."

gs_set "org.gnome.desktop.privacy" "remember-recent-files"  "false"
gs_set "org.gnome.desktop.privacy" "recent-files-max-age"   "0"
gs_set "org.gnome.desktop.privacy" "remove-old-temp-files"  "true"
gs_set "org.gnome.desktop.privacy" "remove-old-trash-files" "true"

# ── 7. Window management tweaks ──────────────────────────────────────────────
echo ""
echo "Applying window management tweaks..."

# Focus follows mouse (sloppy) — more keyboard-friendly
gs_set "org.gnome.desktop.wm.preferences" "focus-mode"        "'sloppy'"
# Raise window on focus (convenient with sloppy focus)
gs_set "org.gnome.desktop.wm.preferences" "raise-on-click"    "true"
# Minimise button only — cleaner title bar
gs_set "org.gnome.desktop.wm.preferences" "button-layout"     "':minimize,close'"
# Attach modal dialogs to parent window
gs_set "org.gnome.mutter"                 "attach-modal-dialogs" "true"

# ── 8. GNOME Terminal — dark profile ─────────────────────────────────────────
echo ""
echo "Configuring GNOME Terminal..."

# Detect the default profile UUID
DEFAULT_PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null \
    | tr -d "'" || true)

if [[ -n "${DEFAULT_PROFILE}" ]]; then
    TP_SCHEMA="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${DEFAULT_PROFILE}/"
    gs_set "${TP_SCHEMA}" "use-system-font"       "true"
    gs_set "${TP_SCHEMA}" "use-theme-colors"      "false"
    gs_set "${TP_SCHEMA}" "background-color"      "'#1e1e2e'"
    gs_set "${TP_SCHEMA}" "foreground-color"      "'#cdd6f4'"
    gs_set "${TP_SCHEMA}" "bold-is-bright"        "true"
    gs_set "${TP_SCHEMA}" "scrollbar-policy"      "'never'"
    gs_set "${TP_SCHEMA}" "audible-bell"          "false"
else
    warn "Could not detect default GNOME Terminal profile. Skipping terminal theme."
fi

# ── 9. Optional: Install Openbox ─────────────────────────────────────────────
if [[ "${INSTALL_OPENBOX}" == true ]]; then
    echo ""
    echo "Installing Openbox (minimal window manager)..."

    if [[ "${EUID}" -ne 0 ]]; then
        SUDO_CMD="sudo"
    else
        SUDO_CMD=""
    fi

    # Check Tor
    if ! systemctl is-active --quiet tor@default 2>/dev/null && \
       ! systemctl is-active --quiet tor        2>/dev/null; then
        warn "Tor does not appear to be running. apt may fail."
    fi

    if ${SUDO_CMD} apt-get install -y --no-install-recommends \
            openbox obconf obmenu tint2 nitrogen feh 2>&1 | tail -5; then
        ok "Openbox and companion tools installed."
        info "To use Openbox this session, run:  openbox --replace &"
        info "To make it your default WM, log out and choose 'Openbox' at the login screen."
    else
        warn "Openbox installation failed. Check your Tor/network connection."
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  Minimalist desktop setup complete.          ${NC}"
echo ""
echo -e "${CYAN}  What was changed:${NC}"
echo -e "    • Dark GTK / GNOME Shell theme (Adwaita-dark)"
echo -e "    • Animations disabled"
echo -e "    • Solid-colour wallpaper: ${WALLPAPER_COLOR}"
echo -e "    • Dock set to auto-hide"
echo -e "    • Desktop icons hidden"
echo -e "    • Privacy: recent files disabled"
echo -e "    • Terminal: dark colour scheme"
echo -e "    • Window buttons: minimise + close only"
if [[ "${INSTALL_OPENBOX}" == true ]]; then
    echo -e "    • Openbox window manager installed"
fi
echo ""
echo -e "${YELLOW}  These changes are SESSION-ONLY.${NC}"
echo -e "${YELLOW}  Run bash scripts/05-persistent-setup.sh to persist dotfiles.${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
