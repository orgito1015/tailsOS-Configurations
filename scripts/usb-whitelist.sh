#!/usr/bin/env bash
# =============================================================================
# usb-whitelist.sh — Authorise specific known-good USB devices
# =============================================================================
# PURPOSE : After running 02-security-hardening.sh (which sets
#           /sys/bus/usb/drivers/usb/authorized_default = 0 to block all
#           new USB devices), this script selectively authorises known-good
#           devices by their USB vendor ID (VID) and product ID (PID).
#
#           Edit the WHITELIST array below to match your own devices.
#
# PERSISTENCE: SESSION-ONLY — runs once after hardening.
# REQUIRES : sudo / admin password set at Greeter.
# USAGE    : bash scripts/usb-whitelist.sh
#
# HOW TO FIND YOUR DEVICE'S VID:PID
#   Plug in the device and run (before running 02-security-hardening.sh):
#     lsusb
#   Output format:  Bus 001 Device 003: ID 0781:5591 SanDisk Corp. ...
#                                          ^^^^ ^^^^
#                                          VID  PID
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
die()   { echo -e "  ${RED}[ERROR]${NC} $*"; exit 1; }

# ── Require root (sudo) ───────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    exec sudo --preserve-env=HOME,USER bash "$0" "$@"
fi

# =============================================================================
# EDIT THIS WHITELIST — add entries in "VID:PID" format.
# Each entry can optionally have a human-readable label after a space.
#
# Examples (these are sample values — replace with your own):
#   "0781:5591"   SanDisk Ultra USB 3.0
#   "058f:6387"   Generic USB flash drive
#   "046d:c52b"   Logitech Unifying receiver
# =============================================================================
WHITELIST=(
    # "VID:PID"
    # Add your own devices here — see the usage note above.
)

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — USB Device Whitelist              ${NC}"
echo -e "${CYAN}  [SESSION-ONLY]                               ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# ── Check that USB blocking is active ────────────────────────────────────────
USB_AUTH_PATH="/sys/bus/usb/drivers/usb/authorized_default"
if [[ ! -f "${USB_AUTH_PATH}" ]]; then
    warn "USB authorization_default sysfs path not found."
    warn "This script requires 02-security-hardening.sh to have been run first."
    exit 1
fi

AUTH_DEFAULT=$(cat "${USB_AUTH_PATH}")
if [[ "${AUTH_DEFAULT}" != "0" ]]; then
    warn "USB auto-authorisation is still enabled (authorized_default = ${AUTH_DEFAULT})."
    warn "Run 02-security-hardening.sh first to block new USB devices."
    warn "Continuing anyway — authorising whitelisted devices."
fi

# ── List currently connected USB devices ─────────────────────────────────────
info "Currently connected USB devices (from /sys/bus/usb/devices/):"
while IFS= read -r -d '' dev; do
    dev_vendor=$(cat "${dev}/idVendor"  2>/dev/null || echo "????")
    dev_product=$(cat "${dev}/idProduct" 2>/dev/null || echo "????")
    dev_name=$(cat "${dev}/product"     2>/dev/null || echo "(no product string)")
    dev_mfr=$(cat "${dev}/manufacturer" 2>/dev/null || echo "")
    dev_auth=$(cat "${dev}/authorized"  2>/dev/null || echo "?")
    auth_label="authorised"
    [[ "${dev_auth}" == "0" ]] && auth_label="${RED}blocked${NC}"
    echo -e "    ${dev_vendor}:${dev_product}  ${dev_mfr} ${dev_name}  [${auth_label}]"
done < <(find /sys/bus/usb/devices/ -maxdepth 1 -name '[0-9]*' -print0 2>/dev/null)
echo ""

# ── Whitelist check ───────────────────────────────────────────────────────────
if [[ ${#WHITELIST[@]} -eq 0 ]]; then
    warn "No devices in WHITELIST array."
    warn "Edit the WHITELIST section of this script to add devices."
    warn "To authorise a specific device manually:"
    warn "  echo 1 | sudo tee /sys/bus/usb/devices/<bus-addr>/authorized"
    echo ""
    exit 0
fi

# ── Authorise whitelisted devices ─────────────────────────────────────────────
AUTHORISED=0

for entry in "${WHITELIST[@]}"; do
    vid=$(echo "${entry}" | cut -d: -f1 | tr '[:upper:]' '[:lower:]')
    pid=$(echo "${entry}" | cut -d: -f2 | tr '[:upper:]' '[:lower:]')

    if [[ -z "${vid}" || -z "${pid}" ]]; then
        warn "Skipping malformed whitelist entry: '${entry}'"
        continue
    fi

    info "Looking for ${vid}:${pid}..."

    FOUND=false
    while IFS= read -r -d '' dev; do
        dev_vendor=$(cat "${dev}/idVendor"  2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
        dev_product=$(cat "${dev}/idProduct" 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")

        if [[ "${dev_vendor}" == "${vid}" && "${dev_product}" == "${pid}" ]]; then
            FOUND=true
            DEV_ADDR=$(basename "${dev}")
            AUTH_FILE="${dev}/authorized"

            if [[ ! -f "${AUTH_FILE}" ]]; then
                warn "  ${vid}:${pid} found at ${DEV_ADDR} but no 'authorized' file."
                continue
            fi

            if [[ "$(cat "${AUTH_FILE}")" == "1" ]]; then
                ok "  ${vid}:${pid} at ${DEV_ADDR} is already authorised."
            else
                echo 1 > "${AUTH_FILE}" 2>/dev/null \
                    && { ok "  ${vid}:${pid} at ${DEV_ADDR} authorised."; AUTHORISED=$((AUTHORISED + 1)); } \
                    || warn "  Failed to authorise ${vid}:${pid} at ${DEV_ADDR}."
            fi
        fi
    done < <(find /sys/bus/usb/devices/ -maxdepth 1 -name '[0-9]*' -print0 2>/dev/null)

    if [[ "${FOUND}" == false ]]; then
        info "  ${vid}:${pid} not currently connected."
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  USB whitelist applied.                       ${NC}"
echo -e "  ${AUTHORISED} device(s) newly authorised.           "
echo -e "${YELLOW}  Devices not in the whitelist remain blocked.  ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
