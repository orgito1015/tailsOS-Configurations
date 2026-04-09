# Package Reference

This page explains every package installed by `scripts/04-package-install.sh`,
what it does, and when you would actually use it in a Tails session.

---

## Security / audit tools

### `lynis`

**What it is:** A system security auditing tool that scans the running OS for
hardening opportunities, misconfigurations, and known-bad settings.

**What it does:** Produces a scored report covering kernel parameters, file
permissions, installed services, and hundreds of other checks.

**When to use it:**
```bash
sudo lynis audit system
```
Run it after applying the hardening scripts to see what else lynis recommends.
Focus on the *suggestions* section — many will not apply to a Tails live session.

**Tails caveat:** Because Tails is a RAM-based live system, lynis will flag many
things as unusual (missing init scripts, unexpected filesystem layout, etc.).
The score it produces reflects those differences, not actual vulnerabilities.
Use the output as a guide, not an absolute measure.

---

### `chkrootkit`

**What it is:** A classic rootkit detector that checks for known rootkit
signatures, suspicious processes, and modified system binaries.

**What it does:** Scans files, processes, and network interfaces for signs of
commonly known rootkits.

**When to use it:**
```bash
sudo chkrootkit
```

**Tails caveat:** `chkrootkit` produces **false positives** in Tails because the
live environment looks unusual compared to a standard installed system.  Treat
any `INFECTED` result as something to investigate further, not as proof of
infection.  The most reliable use is to compare output between sessions.

---

### `rkhunter`

**What it is:** Another rootkit scanner, similar to `chkrootkit` but with a
different detection database and more checks.

**What it does:** Checks system binaries against known hashes, looks for hidden
files, backdoors, and unusual SUID/SGID files.

**When to use it:**
```bash
sudo rkhunter --check --sk     # --sk skips interactive prompts
```

**Tails caveat:** Like `chkrootkit`, `rkhunter` generates false positives on
Tails.  Run it for awareness but do not panic at warnings without investigation.

---

### `aide`

**What it is:** Advanced Intrusion Detection Environment — a file integrity checker
that creates a database of file hashes and attributes, then checks for changes.

**What it does:** Detects modifications to system files that could indicate
tampering.

**When to use it in a session:**
```bash
# Initialise the database (snapshot of current state)
sudo aide --init
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Later, check for changes
sudo aide --check
```

**Tails caveat:** Because Tails rebuilds from RAM on each boot, the database from
a previous session is meaningless.  `aide` is most useful if you initialise it
immediately after booting and then check for changes during the session.

---

### `nmap`

**What it is:** The Network Mapper — the industry-standard network discovery and
security scanning tool.

**What it does:** Discovers hosts on a network, identifies open ports and services,
and optionally detects OS versions and running software.

**When to use it:**
```bash
# Scan your local network for active hosts
nmap -sn 192.168.1.0/24

# Check what ports are open on a specific host
sudo nmap -sS -sV 192.168.1.1

# Always route through Tor for remote targets
torsocks nmap -sT <target>
```

**Tails note:** UDP and raw-packet SYN scans (`-sS`) require root.  Remote
scanning via Tor is limited to TCP connect scans (`-sT`).

---

### `netcat-openbsd`

**What it is:** The Swiss-army knife of TCP/UDP networking.

**What it does:** Can create TCP/UDP connections, listen on ports, transfer
files, or act as a simple proxy.

**When to use it:**
```bash
# Test if a port is open
nc -zv example.onion 443

# Transfer a file (receiver side)
nc -l -p 9999 > received_file

# Transfer a file (sender side)
nc <receiver_ip> 9999 < file_to_send
```

---

## Privacy tools

### `mat2`

**What it is:** Metadata Anonymisation Toolkit version 2 — the successor to MAT.

**What it does:** Strips metadata from a wide range of file types: PDFs, images
(JPEG, PNG), office documents, audio/video files, and more.

**When to use it:**
```bash
# Check what metadata a file contains
mat2 --show document.pdf

# Strip all metadata from a file
mat2 document.pdf            # creates document.cleaned.pdf

# In-place (overwrites original)
mat2 --inplace document.pdf
```

> **Always strip metadata before sharing any file.**  A JPEG taken on a phone
> can contain your GPS coordinates, device model, and exact timestamp.

---

### `exiftool`

**What it is:** A Perl library and command-line tool for reading, writing, and
manipulating metadata in files.

**What it does:** Works on an even wider range of file formats than `mat2`.
Useful for inspecting metadata before stripping it.

**When to use it:**
```bash
# Read all metadata from a file
exiftool photo.jpg

# Remove all metadata
exiftool -all= photo.jpg

# Remove GPS data specifically
exiftool -GPS:all= photo.jpg

# Process a whole directory
exiftool -all= /path/to/directory/
```

> Prefer `mat2` for common file types; use `exiftool` when `mat2` does not
> support a particular format.

---

### `secure-delete`

**What it is:** A collection of tools for secure deletion of files, memory, and
free disk space.

**What it does:** Overwrites data multiple times to make recovery harder, going
beyond a simple `rm`.

**When to use it:**
```bash
# Securely delete a file (25 passes by default)
srm sensitive_file.txt

# Faster: 1 pass of zeros + 1 of random
srm -z -n 2 sensitive_file.txt

# Wipe free space on a filesystem
sfill /tmp/

# Wipe RAM (useful before shutdown; Tails does this automatically)
sudo smem
```

**Note:** On SSDs and flash storage (including your Tails USB), secure deletion
is less effective because the drive's wear-levelling algorithm may retain data in
sectors not directly overwritten.  Tails' RAM wipe on shutdown (`sdmem`) remains
the strongest protection for in-session data.

---

## Utility tools

### `vim`

**What it is:** Vi IMproved — a powerful, highly configurable text editor.

**When to use it:**
```bash
vim file.txt
```

The `configs/dotfiles/.vimrc` in this repository pre-configures vim with sensible
defaults (line numbers, syntax highlighting, no swapfile).

---

### `tmux`

**What it is:** Terminal multiplexer — lets you run multiple terminal sessions
inside one window, and keeps sessions alive even if you close the terminal.

**When to use it:**
```bash
tmux                     # start a new session
tmux new -s mysession    # named session
tmux attach -t mysession # reattach
```

Useful for long-running operations (apt installs, downloads) that should not be
interrupted if the terminal window closes.

---

### `htop`

**What it is:** An interactive process viewer (improved top).

**When to use it:**
```bash
htop
```

Useful for monitoring CPU/RAM usage, identifying suspicious processes, or killing
runaway tasks.

---

### `tree`

**What it is:** Displays directory contents as a tree structure.

**When to use it:**
```bash
tree ~/tailsOS-Configurations
tree -L 2 /etc/tor/
```

---

### `jq`

**What it is:** A lightweight JSON processor for the command line.

**When to use it:**
```bash
# Pretty-print JSON
curl -s https://api.example.com/data | jq .

# Extract a specific field
curl -s https://check.torproject.org/api/ip | jq .IP
```

---

### `xxd`

**What it is:** Creates a hex dump of a file, or converts a hex dump back to
binary.

**When to use it:**
```bash
xxd suspicious_file | less     # inspect binary content
xxd -r hexdump > output.bin   # reverse a hex dump
```

Useful for inspecting unknown files or verifying binary data.

---

### `curl`

**What it is:** A command-line tool for transferring data with URLs.  Almost
certainly already installed in Tails.

**When to use it:**
```bash
# Always via torsocks to ensure Tor routing
torsocks curl -s https://check.torproject.org/api/ip

# Download a file
torsocks curl -O https://example.onion/file.tar.gz
```

---

### `wget`

**What it is:** A command-line file downloader that supports recursive downloads
and resuming.

**When to use it:**
```bash
# Via torsocks
torsocks wget https://example.onion/file.tar.gz

# Resume an interrupted download
torsocks wget -c https://example.onion/large_file.iso
```

**Note:** In Tails, set `WGETRC=/dev/null` to prevent wget from writing an HSTS
database to disk.  This is already done in `configs/dotfiles/.bashrc`.
