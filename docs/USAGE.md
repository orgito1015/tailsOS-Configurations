# Usage Guide

This document walks you through every step needed to set up and harden a Tails OS 6.x live session using the scripts and configuration files in this repository.

---

## Prerequisites

Before you begin:

1. **Boot Tails 6.x** from a USB drive.
2. **Set an admin password** in the Tails Greeter (login screen) — this is required by every script that uses `sudo`.
3. **Unlock Persistent Storage** in the Greeter if you have it enabled.
4. **Wait for Tor to connect** (the onion icon in the top bar should be green / solid) before running network-dependent scripts.

---

## Step 1 — Get the repository

Open a terminal: **Applications → Terminal**

```bash
# The repo is cloned through Tor automatically in Tails
cd ~
git clone https://github.com/orgito1015/tailsOS-Configurations.git
cd tailsOS-Configurations

# Make scripts executable
chmod +x scripts/*.sh configs/network/iptables-rules.sh
```

If you already have the repository in Persistent Storage (set up in a previous session by `05-persistent-setup.sh`), use that copy instead:

```bash
cd ~/tailsOS-Configurations
git pull   # optional: update to latest
```

---

## Step 2 — Run the pre-flight check

```bash
bash scripts/00-setup-check.sh
```

This performs the following checks and prints a pass/fail for each:

| Check | What it verifies |
|---|---|
| Tails OS | Confirms you are running on Tails, prints the version |
| User | Confirms you are the `amnesia` user |
| sudo | Confirms admin password is set and sudo works |
| Persistent Storage | Detects `/live/persistence/TailsData_unlocked/` |
| Tor | Checks that `tor` service is running and traffic is routed through Tor |
| Required commands | Checks that `iptables`, `sysctl`, `ip`, `curl`, `apt-get`, and `git` are available |

Fix any failures before proceeding.

---

## Step 3 — Apply hardening (choose individually or use run-all)

### Option A — Run everything at once

```bash
bash scripts/run-all.sh
```

This runs scripts `00` through `04` in sequence.  A failure in one script does not stop the others (use `--strict` to abort on first failure).

### Option B — Run scripts individually

```bash
# Network hardening (firewall, IPv6, MAC randomisation)
bash scripts/01-network-hardening.sh

# Kernel / system hardening (sysctl, ptrace, USB, screen lock)
bash scripts/02-security-hardening.sh

# Dotfiles (shell config, vim, aliases)
bash scripts/03-dotfiles-setup.sh
source ~/.bashrc   # apply shell changes immediately

# Extra packages (installed over Tor, session-only)
bash scripts/04-package-install.sh
```

> **Note:** Scripts `01` and `02` automatically re-invoke themselves with `sudo` when run as a regular user.

---

## Step 4 (optional) — Make settings survive reboot

By default all changes are lost when Tails reboots.  To persist them:

```bash
bash scripts/05-persistent-setup.sh
```

This requires Persistent Storage to be enabled and the **Dotfiles** feature to be turned on.  See [PERSISTENCE.md](PERSISTENCE.md) for details.

---

## Script reference

### `00-setup-check.sh`

- **Persistence:** SESSION-ONLY (read-only, makes no changes)
- **Run as:** `amnesia` user (no sudo needed)
- **Purpose:** Verify environment before running other scripts

### `01-network-hardening.sh`

- **Persistence:** SESSION-ONLY
- **Run as:** `amnesia` (auto-elevates to sudo)
- **What it does:**
  - Disables IPv6 via sysctl
  - Enables reverse-path filtering
  - Disables ICMP redirects and IP source routing
  - Enables SYN cookies
  - Adds extra iptables INPUT rules (drop INVALID, rate-limit SYN)
  - Blocks all traffic with ip6tables
  - Verifies / attempts MAC address randomisation

### `02-security-hardening.sh`

- **Persistence:** SESSION-ONLY
- **Run as:** `amnesia` (auto-elevates to sudo)
- **What it does:**
  - Sets kernel ASLR to full (mode 2)
  - Restricts ptrace to parent-child scope
  - Hides kernel pointers from unprivileged users
  - Restricts dmesg access
  - Disables core dumps
  - Disables SysRq
  - Enables hard/symlink protections
  - Disables TCP timestamps
  - Sets GNOME screen lock to 5-minute timeout
  - Blocks USB auto-authorisation for new devices
  - Unloads and blacklists `firewire_ohci`

### `03-dotfiles-setup.sh`

- **Persistence:** SESSION-ONLY by default (see `05-persistent-setup.sh`)
- **Run as:** `amnesia` (no sudo needed)
- **What it does:**
  - Copies `.bashrc`, `.bash_aliases`, `.vimrc`, `.gitconfig` to `~/`
  - Creates `.bak.*` backups of any existing files
- **After running:** `source ~/.bashrc`

### `04-package-install.sh`

- **Persistence:** SESSION-ONLY
- **Run as:** `amnesia` (auto-elevates to sudo)
- **What it does:**
  - Runs `apt-get update` over Tor
  - Installs: `lynis`, `chkrootkit`, `rkhunter`, `aide`, `nmap`, `netcat-openbsd`, `mat2`, `exiftool`, `secure-delete`, `vim`, `tmux`, `htop`, `tree`, `jq`, `xxd`, `curl`, `wget`
- **Tip:** Use Tails' *Additional Software* feature to auto-install packages on every boot.

### `05-persistent-setup.sh`

- **Persistence:** ✅ SURVIVES REBOOT
- **Run as:** `amnesia` (auto-elevates to sudo)
- **What it does:**
  - Copies dotfiles into `/live/persistence/TailsData_unlocked/dotfiles/`
  - Creates XDG autostart entries that re-apply sysctl and iptables rules at each login
  - Optionally copies the repository into Persistent Storage

---

## Verifying your setup

After running the scripts:

```bash
# Confirm Tor routing
torsocks curl -s https://check.torproject.org/api/ip

# Check iptables rules
sudo iptables -L INPUT -v -n

# Check sysctl hardening
sudo sysctl kernel.randomize_va_space kernel.yama.ptrace_scope kernel.kptr_restrict

# Check IPv6 is disabled
cat /proc/sys/net/ipv6/conf/all/disable_ipv6   # should print 1

# Check installed packages
dpkg -l lynis mat2 tmux 2>/dev/null
```
