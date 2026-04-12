#!/usr/bin/env bash
# =============================================================================
# 08-cybersecurity-tools.sh — Install cybersecurity tools for this session
# =============================================================================
# PURPOSE : Install a curated set of offensive and defensive cybersecurity
#           tools via apt over Tor.  Tools are grouped by discipline so you
#           can comment out any category you do not need.
#
#           All packages come from the standard Debian Bookworm repositories
#           (the same ones Tails 6.x uses), so no third-party sources are
#           required.
#
# PERSISTENCE: SESSION-ONLY — packages must be reinstalled every session.
#              Use Tails' "Additional Software" feature to auto-install on
#              boot: Applications → Tails → Additional Software.
#
# REQUIRES : sudo / admin password set at Greeter.
#            Active Tor connection.
# USAGE    : bash scripts/08-cybersecurity-tools.sh [--category <name>]
#              --category  Install only one category.  Available categories:
#                          network, web, passwords, forensics, wireless,
#                          reversing, osint, all (default)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "  ${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "  ${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "  ${RED}[ERROR]${NC} $*"; exit 1; }
heading() { echo -e "\n${CYAN}${BOLD}── $* ${NC}"; }

# ── Require root (sudo) ───────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    exec sudo --preserve-env=HOME,USER bash "$0" "$@"
fi

# ── Argument parsing ──────────────────────────────────────────────────────────
CATEGORY="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --category)
            shift
            CATEGORY="${1:-all}"
            ;;
        --category=*)
            CATEGORY="${1#--category=}"
            ;;
        *)
            warn "Unknown argument: $1 (ignored)"
            ;;
    esac
    shift
done

# ── Package lists by discipline ───────────────────────────────────────────────
# Each array holds: "package"  # short description
# Packages already installed by 04-package-install.sh (nmap, netcat-openbsd,
# lynis, chkrootkit, rkhunter, aide) are intentionally omitted here.

# -- Network analysis & traffic capture ---------------------------------------
# shellcheck disable=SC2034
PKGS_NETWORK=(
    "tcpdump"            # command-line packet analyser
    "tshark"             # Wireshark CLI — capture and decode network traffic
    "wireshark"          # full GUI packet analyser (optional, opens an xterm)
    "masscan"            # high-speed TCP port scanner
    "hping3"             # TCP/IP packet assembler/analyser
    "netdiscover"        # active/passive ARP network scanner
    "arp-scan"           # ARP-based host discovery
    "dnsutils"           # dig, nslookup, host — DNS interrogation tools
    "whois"              # domain/IP WHOIS lookup
    "traceroute"         # trace network routes
    "mtr"                # network diagnostic tool (combines ping + traceroute)
    "ncat"               # Nmap's improved netcat
    "socat"              # multipurpose relay for bidirectional data transfer
    "proxychains4"       # force any TCP connection through a proxy chain
    "sslscan"            # fast SSL/TLS scanner
    "sslyze"             # SSL/TLS configuration analyser
    "openssh-client"     # SSH client
)

# -- Web application testing --------------------------------------------------
# shellcheck disable=SC2034
PKGS_WEB=(
    "nikto"              # web server vulnerability scanner
    "sqlmap"             # automated SQL injection & takeover tool
    "dirb"               # web content scanner (dictionary-based)
    "gobuster"           # directory/file & DNS busting tool
    "whatweb"            # web application fingerprinter
    "wapiti"             # web application vulnerability scanner
    "cutycapt"           # capture screenshots of web pages (Qt-based)
    "python3-requests"   # Python HTTP library (scripting dependency)
    "python3-bs4"        # BeautifulSoup4 — HTML/XML parser for scripting
)

# -- Password auditing & credential tools -------------------------------------
# shellcheck disable=SC2034
PKGS_PASSWORDS=(
    "john"               # John the Ripper — password cracker
    "hashcat"            # GPU-accelerated password recovery
    "hydra"              # fast parallelised login brute-forcer
    "medusa"             # parallel network login auditor
    "crunch"             # wordlist generator
    "cewl"               # custom wordlist generator from web pages
    "wordlists"          # collection of wordlists (includes rockyou)
    "hashid"             # identify hash types
    "ophcrack"           # Windows password cracker using rainbow tables
)

# -- Digital forensics --------------------------------------------------------
# shellcheck disable=SC2034
PKGS_FORENSICS=(
    "foremost"           # file carving / data recovery tool
    "binwalk"            # firmware analysis and extraction
    "sleuthkit"          # CLI tools for NTFS/FAT/ext forensic analysis
    "dc3dd"              # patched GNU dd for forensic imaging
    "ddrescue"           # data recovery tool (also known as gddrescue)
    "volatility3"        # memory forensics framework
    "bulk-extractor"     # stream-based forensic feature extractor
    "exifprobe"          # examine and display EXIF data in image files
    "scalpel"            # file carver based on foremost
    "testdisk"           # data recovery and partition repair
    "photorec"           # file recovery tool (ships with testdisk)
    "hexedit"            # interactive hex editor
    "bless"              # GTK hex editor
)

# -- Wireless security --------------------------------------------------------
# shellcheck disable=SC2034
PKGS_WIRELESS=(
    "aircrack-ng"        # WiFi security auditing suite
    "kismet"             # wireless network detector/sniffer/IDS
    "wavemon"            # ncurses wireless network monitor
    "reaver"             # WPS brute-force attack tool
    "bully"              # WPS brute-force tool (alternative to reaver)
    "wifite"             # automated wireless auditing tool
    "hostapd"            # user-space daemon for access point functionality
    "iw"                 # nl80211-based CLI tool for wireless devices
    "wireless-tools"     # tools for manipulating Linux wireless extensions
    "rfkill"             # enable/disable wireless devices
)

# -- Reverse engineering & binary analysis ------------------------------------
# shellcheck disable=SC2034
PKGS_REVERSING=(
    "gdb"                # GNU debugger
    "gdb-multiarch"      # GDB with multi-architecture support
    "radare2"            # reverse engineering framework
    "ghidra"             # NSA Software Reverse Engineering suite
    "ltrace"             # library call tracer
    "strace"             # system call tracer
    "binutils"           # collection of binary utilities (includes objdump)
    "nasm"               # x86/x64 assembler
    "patchelf"           # modify ELF binaries
    "upx-ucl"            # executable packer/unpacker
    "checksec"           # check security properties of ELF binaries
)

# -- OSINT & reconnaissance ---------------------------------------------------
# shellcheck disable=SC2034
PKGS_OSINT=(
    "theharvester"       # OSINT tool for gathering emails, subdomains, IPs
    "recon-ng"           # modular web reconnaissance framework
    "maltego"            # interactive data mining and link analysis
    "amass"              # in-depth attack surface mapping
    "sublist3r"          # subdomain enumeration tool
    "fierce"             # DNS reconnaissance tool
    "metagoofil"         # metadata extractor from public documents
    "python3-shodan"     # Python Shodan API client
)

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Tails OS — Cybersecurity Tools Installer     ${NC}"
echo -e "${CYAN}  [SESSION-ONLY] — packages lost on reboot     ${NC}"
echo -e "${CYAN}  Category: ${BOLD}${CATEGORY}${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# ── Check Tor is running ─────────────────────────────────────────────────────
if ! systemctl is-active --quiet tor@default 2>/dev/null && \
   ! systemctl is-active --quiet tor        2>/dev/null; then
    warn "Tor does not appear to be running.  apt will still work but"
    warn "traffic routing cannot be guaranteed."
fi

# ── Build the install list from the requested category(ies) ──────────────────
INSTALL_LIST=()

add_category() {
    local cat_name="$1"
    local -n cat_array="$2"
    heading "${cat_name}"
    for pkg in "${cat_array[@]}"; do
        INSTALL_LIST+=("${pkg}")
    done
}

case "${CATEGORY}" in
    network)   add_category "Network Analysis"          PKGS_NETWORK    ;;
    web)       add_category "Web Application Testing"   PKGS_WEB        ;;
    passwords) add_category "Password Auditing"         PKGS_PASSWORDS  ;;
    forensics) add_category "Digital Forensics"         PKGS_FORENSICS  ;;
    wireless)  add_category "Wireless Security"         PKGS_WIRELESS   ;;
    reversing) add_category "Reverse Engineering"       PKGS_REVERSING  ;;
    osint)     add_category "OSINT & Reconnaissance"    PKGS_OSINT      ;;
    all)
        add_category "Network Analysis"          PKGS_NETWORK
        add_category "Web Application Testing"   PKGS_WEB
        add_category "Password Auditing"         PKGS_PASSWORDS
        add_category "Digital Forensics"         PKGS_FORENSICS
        add_category "Wireless Security"         PKGS_WIRELESS
        add_category "Reverse Engineering"       PKGS_REVERSING
        add_category "OSINT & Reconnaissance"    PKGS_OSINT
        ;;
    *)
        die "Unknown category '${CATEGORY}'.  Valid options: network web passwords forensics wireless reversing osint all"
        ;;
esac

echo ""
info "Total packages to consider: ${#INSTALL_LIST[@]}"
echo ""

# ── Update package lists ──────────────────────────────────────────────────────
info "Updating apt package lists..."
if ! apt-get update -qq 2>&1 | tail -5; then
    warn "apt-get update encountered errors — continuing anyway."
fi
ok "Package lists updated."
echo ""

# ── Install packages ──────────────────────────────────────────────────────────
INSTALLED=()
SKIPPED=()
FAILED=()

for pkg in "${INSTALL_LIST[@]}"; do
    if dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
        info "  [skip]  ${pkg} — already installed."
        SKIPPED+=("${pkg}")
    else
        if apt_output=$(apt-get install -y --no-install-recommends "${pkg}" 2>&1); then
            ok "  [done]  ${pkg}"
            INSTALLED+=("${pkg}")
        else
            warn "  [fail]  ${pkg} — could not be installed."
            # Show the last meaningful error line (skip blank lines)
            last_err=$(echo "${apt_output}" | grep -v '^$' | tail -2 || true)
            [[ -n "${last_err}" ]] && warn "          ${last_err}"
            FAILED+=("${pkg}")
        fi
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "  ${GREEN}Installed : ${#INSTALLED[@]}${NC}"
echo -e "  ${YELLOW}Skipped   : ${#SKIPPED[@]}${NC}  (already present)"
echo -e "  ${RED}Failed    : ${#FAILED[@]}${NC}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    warn "Packages that could not be installed:"
    for pkg in "${FAILED[@]}"; do
        warn "    - ${pkg}"
    done
    warn "Possible reasons: package name changed, not in Bookworm, or network error."
    warn "Search Debian packages at: https://packages.debian.org/bookworm/"
fi

echo ""
info "TIP: To auto-install packages on every boot, use Tails' built-in"
info "'Additional Software' feature (requires Persistent Storage enabled):"
info "  Applications → Tails → Additional Software"
echo ""
info "To install only one category next time:"
info "  bash scripts/08-cybersecurity-tools.sh --category <name>"
info "  Categories: network  web  passwords  forensics  wireless  reversing  osint"
echo -e "${CYAN}================================================${NC}"
echo ""
