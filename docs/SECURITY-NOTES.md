# Security Notes and Threat Model

This document describes the security assumptions, threat model, and known limitations of the scripts in this repository.

---

## Threat model

These scripts are designed to help defend against the following threat actors:

| Threat | Mitigated? | Notes |
|---|---|---|
| Passive network surveillance | ✅ | All traffic routed through Tor by Tails |
| Active network adversary (MITM) | ✅ | Tor encryption + HTTPS |
| Local network adversary | ✅ | Firewall rules block unsolicited inbound traffic |
| Metadata in files | ✅ (manual) | `mat2` / `exiftool` installed; user must strip metadata |
| USB cold-boot / DMA attacks | ⚠️ Partial | Firewire disabled; USB auto-auth disabled; RAM wipe on shutdown by Tails |
| Physical access to running machine | ❌ | No mitigation beyond Tails default screen lock |
| Adversary with your admin password | ❌ | This is the root of trust |
| Malicious scripts in this repo | ❌ | **Review all scripts before running them** |
| Compromised Tor exit node | ⚠️ Partial | Use HTTPS everywhere; avoid plaintext protocols |
| Global network adversary (traffic correlation) | ❌ | Tor does not protect against end-to-end correlation |

---

## Security assumptions

1. **You trust this repository.**  These scripts run as root.  Always read them before executing.
2. **Your Tails USB has not been tampered with.**  Always verify the Tails ISO signature before writing to USB.
3. **You set a strong admin password.**  The admin password protects all `sudo` access in the session.
4. **You use HTTPS / onion services** for all sensitive communications.
5. **You do not install untrusted software.**  Package installation in `04-package-install.sh` uses the official Debian repositories.

---

## What Tails already provides (before running these scripts)

Understanding the baseline helps you know what the scripts add on top:

- **All outbound traffic forced through Tor** via iptables OUTPUT rules in the `tails` chain.
- **DNS resolution via Tor** — no DNS leaks.
- **MAC address randomisation** at boot by default.
- **AppArmor** profiles for most applications.
- **Memory wiping** on shutdown (`sdmem`).
- **Tor Browser** with strong fingerprinting resistance.
- **Firewall** — the OUTPUT chain allows only Tor-related traffic.

These scripts extend those defaults; they do not replace them.

---

## Script-specific notes

### `01-network-hardening.sh`

- Does **not** modify the OUTPUT chain — modifying it could break Tor enforcement.
- The INPUT chain rules are additive.  If run multiple times, duplicate rules will accumulate.  This is harmless but you can inspect with `sudo iptables -L INPUT -v -n`.
- MAC randomisation: Tails randomises MACs by default.  This script verifies and re-randomises only if the MAC is not locally administered.

### `02-security-hardening.sh`

- **USB auto-authorisation (`/sys/bus/usb/drivers/usb/authorized_default = 0`)** prevents new USB devices from being authorised after the session starts.  Devices plugged in at boot (including your Tails USB) remain authorised.  To use a USB device plugged in after this setting is applied, run: `echo 1 | sudo tee /sys/bus/usb/devices/usbX/authorized`
- **`kernel.modules_disabled`** is deliberately left at `0` to preserve Wi-Fi and Tor functionality.  Setting it to `1` is the most locked-down configuration but will prevent loading any new kernel modules.
- **ptrace_scope = 1** may interfere with some debugging tools (`strace`, `gdb`) that attach to non-child processes.

### `03-dotfiles-setup.sh`

- Creates `.bak.*` backups of existing dotfiles before overwriting them.
- Does NOT back up files that are already symlinks (from Persistent Storage).

### `04-package-install.sh`

- Packages are installed from the official Debian Bookworm repositories over Tor.
- `rkhunter` and `chkrootkit` produce **false positives** in a Tails environment because the RAM-based live system differs from a typical installed system.  Their output should be interpreted with care.
- `aide` requires initialisation (`sudo aide --init`) before it can detect changes.

### `05-persistent-setup.sh`

- XDG autostart entries run as the `amnesia` user and use `sudo` without a password (relies on the admin password being set and `sudo` having been used at least once in the session, or you may be prompted).
- The scripts placed in `~/.config/tails-hardening/` run with `sudo` at each login.  Review them if you are concerned about what runs automatically.

---

## Known limitations

- These scripts do not harden the Tor Browser itself.  Use `about:config` or the Tor Browser Security Settings for that.
- These scripts do not configure application-level AppArmor profiles.
- Kernel hardening via sysctl only applies to the running session.  A sophisticated adversary with root access can undo them.
- The `05-persistent-setup.sh` autostart mechanism depends on GNOME; if Tails changes its desktop environment, autostart paths may change.
- No two-factor authentication or disk encryption beyond Persistent Storage is configured by these scripts.

---

## Verifying script integrity

Before running any script from this repository, verify the integrity of the repository:

```bash
# Check the git log for unexpected commits
git log --oneline

# Inspect a specific script before running
cat scripts/01-network-hardening.sh

# Optional: verify against a known-good commit hash
git verify-commit HEAD   # requires GPG signing to be set up
```

---

## Reporting security issues

If you find a security issue in these scripts, please open a GitHub Issue or contact the repository owner privately before disclosing publicly.
