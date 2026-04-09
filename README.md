# tailsOS-Configurations

A collection of shell scripts and configuration files for hardening and customising a [Tails OS](https://tails.boum.org) 6.x live session. All scripts are run **manually** by the user after booting into Tails with an admin password set in the Greeter.

> **Security notice:** These scripts are provided as-is. Review every script before running it. Never blindly execute code you have not read.

---

## Table of contents

- [Requirements](#requirements)
- [Repository layout](#repository-layout)
- [Quick start](#quick-start)
- [Scripts overview](#scripts-overview)
- [Configs overview](#configs-overview)
- [Persistence](#persistence)
- [Further reading](#further-reading)

---

## Requirements

| Requirement | Details |
|---|---|
| Tails version | 6.x (Debian 12 Bookworm base) |
| Admin password | Must be set in the Greeter before booting |
| Persistent Storage | Should be enabled and unlocked |
| Internet connection | Required only for `04-package-install.sh` |

---

## Repository layout

```
tailsOS-Configurations/
├── README.md                        # This file
├── Makefile                         # make harden / make packages / make persist etc.
├── .gitignore
├── scripts/
│   ├── setup-wizard.sh              # Interactive wizard — start here if unsure
│   ├── 00-setup-check.sh            # Pre-flight environment checks       [session-only]
│   ├── 01-network-hardening.sh      # Firewall & network security          [session-only]
│   ├── 02-security-hardening.sh     # Kernel sysctl & system hardening     [session-only]
│   ├── 03-dotfiles-setup.sh         # Apply dotfiles / shell config        [session or persistent]
│   ├── 04-package-install.sh        # Install extra packages via apt       [session-only]
│   ├── 05-persistent-setup.sh       # Wire configs into Persistent Storage [survives reboot]
│   ├── 06-verify.sh                 # Post-setup hardening audit           [read-only]
│   ├── 07-cleanup.sh                # Wipe session artifacts before shutdown
│   ├── usb-whitelist.sh             # Authorise known-good USB devices by VID:PID
│   └── run-all.sh                   # Run scripts 00–04 in sequence        [session-only]
├── configs/
│   ├── dotfiles/
│   │   ├── .bashrc                  # Interactive shell configuration
│   │   ├── .bash_aliases            # Handy shell aliases
│   │   ├── .vimrc                   # Vim editor settings
│   │   └── .gitconfig               # Git settings (no credentials stored)
│   ├── network/
│   │   ├── iptables-rules.sh        # Extra iptables hardening rules
│   │   └── torrc-custom             # Custom Tor configuration snippet
│   ├── security/
│   │   └── sysctl-hardening.conf    # Kernel hardening sysctl parameters
│   ├── gpg/
│   │   └── gpg-agent.conf           # GPG agent: cache TTL, pinentry program
│   ├── ssh/
│   │   └── config                   # Hardened SSH client config routing through Tor
│   ├── tor-browser/
│   │   └── user.js                  # Tor Browser extra hardening (WebGL, JS, etc.)
│   ├── apt/
│   │   └── preferences              # APT pinning: keep packages on Debian Bookworm
│   └── apparmor/
│       ├── usr.bin.curl             # AppArmor profile restricting curl
│       └── usr.bin.wget             # AppArmor profile restricting wget
└── docs/
    ├── FIRST-BOOT.md                # Start here: checklist for first-time Tails users
    ├── USAGE.md                     # Step-by-step usage guide
    ├── PERSISTENCE.md               # How Tails Persistent Storage works
    ├── PACKAGES.md                  # What every package in 04-package-install.sh does
    ├── THREAT-MODEL.md              # Who you're hiding from and what each layer protects
    └── SECURITY-NOTES.md            # Security assumptions and known limitations
```

---

## Quick start

```bash
# 1. Open a terminal in Tails (Applications → Terminal)
# 2. Clone this repo (requires internet / Tor)
cd ~
git clone https://github.com/orgito1015/tailsOS-Configurations.git
cd tailsOS-Configurations

# 3. Make all scripts executable
chmod +x scripts/*.sh configs/network/iptables-rules.sh

# 4a. New to Tails? Use the interactive wizard
bash scripts/setup-wizard.sh

# 4b. Or run the pre-flight check and then all scripts at once
bash scripts/00-setup-check.sh
bash scripts/run-all.sh

# 4c. Or use make
make help
make harden
```

> **First time with Tails?** Read [`docs/FIRST-BOOT.md`](docs/FIRST-BOOT.md) before cloning anything.

---

## Scripts overview

| Script | Purpose | Survives reboot? |
|---|---|---|
| `setup-wizard.sh` | Interactive wizard — choose what to run | No |
| `00-setup-check.sh` | Verify Tails version, admin password, and Persistent Storage | No |
| `01-network-hardening.sh` | Harden firewall, disable IPv6, randomise MAC address | No |
| `02-security-hardening.sh` | Apply sysctl hardening, lock screen, restrict USB | No |
| `03-dotfiles-setup.sh` | Copy dotfiles to `~` (optionally into Persistent Storage) | No (see `05`) |
| `04-package-install.sh` | Install privacy/security tools via `apt` over Tor | No |
| `05-persistent-setup.sh` | Symlink configs through Persistent Storage so they reload on next boot | **Yes** |
| `06-verify.sh` | Read-only audit — prints PASS/FAIL for every hardening measure | No |
| `07-cleanup.sh` | Clear bash history, /tmp, apt cache, thumbnails before shutdown | No |
| `usb-whitelist.sh` | Authorise specific USB devices by VID:PID after blocking auto-auth | No |
| `run-all.sh` | Convenience wrapper for scripts 00–04 | No |

Each script prints a `[SESSION-ONLY]` or `[PERSISTENT]` header so you always know what you are running.

---

## Configs overview

| Config file | Purpose | How to deploy |
|---|---|---|
| `configs/dotfiles/` | Shell, editor, git config | `bash scripts/03-dotfiles-setup.sh` |
| `configs/network/iptables-rules.sh` | Extra iptables rules | Applied by `01-network-hardening.sh` |
| `configs/network/torrc-custom` | Custom Tor snippets | `sudo tee -a /etc/tor/torrc` |
| `configs/security/sysctl-hardening.conf` | Kernel hardening parameters | Applied by `02-security-hardening.sh` |
| `configs/gpg/gpg-agent.conf` | GPG agent cache TTL and pinentry | `cp` to `~/.gnupg/`; `gpg-connect-agent reloadagent /bye` |
| `configs/ssh/config` | Hardened SSH client config routing all SSH through Tor | `cp` to `~/.ssh/config`; `chmod 600` |
| `configs/tor-browser/user.js` | Extra Tor Browser hardening (disable WebGL, JS, WebRTC, etc.) | `cp` to your Tor Browser profile directory |
| `configs/apt/preferences` | APT pinning to Debian Bookworm | `sudo cp` to `/etc/apt/preferences.d/99-tails-pinning` |
| `configs/apparmor/usr.bin.curl` | AppArmor profile restricting curl | `sudo cp` to `/etc/apparmor.d/`; `sudo apparmor_parser -r` |
| `configs/apparmor/usr.bin.wget` | AppArmor profile restricting wget | `sudo cp` to `/etc/apparmor.d/`; `sudo apparmor_parser -r` |

---

## Persistence

Changes made in a Tails session are **lost on reboot by default**. The `05-persistent-setup.sh` script places selected configuration files inside the Persistent Storage volume (`/live/persistence/TailsData_unlocked/`) and creates the necessary symlinks so Tails reloads them on the next boot.

See [`docs/PERSISTENCE.md`](docs/PERSISTENCE.md) for a full explanation.

---

## Further reading

- [Tails documentation](https://tails.boum.org/doc/)
- [Tails Persistent Storage](https://tails.boum.org/doc/persistent_storage/)
- [Tor Project](https://www.torproject.org/)
- [`docs/FIRST-BOOT.md`](docs/FIRST-BOOT.md) — checklist for new Tails users
- [`docs/USAGE.md`](docs/USAGE.md)
- [`docs/PERSISTENCE.md`](docs/PERSISTENCE.md)
- [`docs/PACKAGES.md`](docs/PACKAGES.md) — what every installed package does
- [`docs/THREAT-MODEL.md`](docs/THREAT-MODEL.md) — who are you hiding from?
- [`docs/SECURITY-NOTES.md`](docs/SECURITY-NOTES.md)
