# tailsOS-Configurations

A collection of shell scripts and configuration files for hardening and customising a [Tails OS](https://tails.boum.org) 6.x live session. All scripts are run **manually** by the user after booting into Tails with an admin password set in the Greeter.

> **Security notice:** These scripts are provided as-is. Review every script before running it. Never blindly execute code you have not read.

---

## Table of contents

- [Requirements](#requirements)
- [Repository layout](#repository-layout)
- [Quick start](#quick-start)
- [Scripts overview](#scripts-overview)
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
├── .gitignore
├── scripts/
│   ├── 00-setup-check.sh            # Pre-flight environment checks       [session-only]
│   ├── 01-network-hardening.sh      # Firewall & network security          [session-only]
│   ├── 02-security-hardening.sh     # Kernel sysctl & system hardening     [session-only]
│   ├── 03-dotfiles-setup.sh         # Apply dotfiles / shell config        [session or persistent]
│   ├── 04-package-install.sh        # Install extra packages via apt       [session-only]
│   ├── 05-persistent-setup.sh       # Wire configs into Persistent Storage [survives reboot]
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
│   └── security/
│       └── sysctl-hardening.conf    # Kernel hardening sysctl parameters
└── docs/
    ├── USAGE.md                     # Step-by-step usage guide
    ├── PERSISTENCE.md               # How Tails Persistent Storage works
    └── SECURITY-NOTES.md            # Security assumptions and threat model
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

# 4. Run the pre-flight check first
bash scripts/00-setup-check.sh

# 5. Run individual scripts as needed, or run all at once
bash scripts/run-all.sh
```

---

## Scripts overview

| Script | Purpose | Survives reboot? |
|---|---|---|
| `00-setup-check.sh` | Verify Tails version, admin password, and Persistent Storage | No |
| `01-network-hardening.sh` | Harden firewall, disable IPv6, randomise MAC address | No |
| `02-security-hardening.sh` | Apply sysctl hardening, lock screen, restrict USB | No |
| `03-dotfiles-setup.sh` | Copy dotfiles to `~` (optionally into Persistent Storage) | No (see `05`) |
| `04-package-install.sh` | Install privacy/security tools via `apt` over Tor | No |
| `05-persistent-setup.sh` | Symlink configs through Persistent Storage so they reload on next boot | **Yes** |
| `run-all.sh` | Convenience wrapper for scripts 00–04 | No |

Each script prints a `[SESSION-ONLY]` or `[PERSISTENT]` header so you always know what you are running.

---

## Persistence

Changes made in a Tails session are **lost on reboot by default**. The `05-persistent-setup.sh` script places selected configuration files inside the Persistent Storage volume (`/live/persistence/TailsData_unlocked/`) and creates the necessary symlinks so Tails reloads them on the next boot.

See [`docs/PERSISTENCE.md`](docs/PERSISTENCE.md) for a full explanation.

---

## Further reading

- [Tails documentation](https://tails.boum.org/doc/)
- [Tails Persistent Storage](https://tails.boum.org/doc/persistent_storage/)
- [Tor Project](https://www.torproject.org/)
- [`docs/USAGE.md`](docs/USAGE.md)
- [`docs/SECURITY-NOTES.md`](docs/SECURITY-NOTES.md)
