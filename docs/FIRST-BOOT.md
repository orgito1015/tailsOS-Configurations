# First Boot on Tails OS — Quick Start Checklist

Welcome to Tails.  This page is for people who have just booted Tails for the
first time.  You do not need to clone any repository yet — just work through
this list in order.

---

## Before you even boot

- [ ] **Download Tails from the official website only:** https://tails.boum.org
- [ ] **Verify the download** using the Tails verification extension or the
  command-line instructions on the download page.  A forged ISO is the most
  common attack on Tails users.
- [ ] **Write the ISO to a USB drive** using Balena Etcher, `dd`, or the Tails
  installer (if upgrading from an existing Tails).
  - Use a USB drive you trust and have not used for anything sensitive.
  - 8 GB minimum; 16 GB or more if you want Persistent Storage.

---

## At the Tails login screen (the Greeter)

The Greeter appears before the desktop loads.  Configure it carefully:

- [ ] **Set an admin password.**  Click the `+` button next to *Additional Settings*
  and set a strong, memorable password.  **Without this, none of the hardening
  scripts in this repository will work.**  The password is only valid for this
  session.
- [ ] **Enable Persistent Storage** if you have it set up (it will ask for your
  passphrase).  If this is your first boot, skip this — you can set it up later.
- [ ] **Check the keyboard layout** is correct for your language.
- [ ] Click **Start Tails**.

---

## First things to do on the desktop

1. **Wait for Tor to connect.**  Look at the onion icon in the top-right of the
   screen.  It will show a loading animation while connecting.  Wait until it
   turns solid / green before doing anything that requires the internet.

2. **Open a terminal:**
   *Applications → System Tools → Terminal*

3. **Check which version of Tails you are running:**
   ```
   cat /etc/os-release
   ```
   Make sure you are on Tails 6.x (Debian 12 Bookworm base).

4. **Verify Tor is working:**
   ```
   torsocks curl -s https://check.torproject.org/api/ip
   ```
   You should see `"IsTor":true` in the output.

---

## Setting up Persistent Storage (recommended)

Persistent Storage lets you save files across reboots.  Without it, everything
— files, settings, installed packages — is lost when you shut down.

1. *Applications → Tails → Configure Persistent Volume*
2. Choose a strong passphrase and write it down somewhere safe offline.
3. Enable at minimum:
   - **Personal Data** — your files in `~/Persistent/`
   - **Dotfiles** — needed by the hardening scripts in this repo
   - **SSH Client** — persist `~/.ssh/` if you use SSH
   - **GnuPG** — persist your GPG keys
4. Click **Save**.
5. Reboot Tails and unlock Persistent Storage at the Greeter.

> ⚠️ If you forget your Persistent Storage passphrase, the data is
> **unrecoverable** — it is encrypted with LUKS and there is no recovery key.

---

## Clone this repository and run the setup wizard

Once Persistent Storage is set up and Tor is connected:

```bash
cd ~
git clone https://github.com/orgito1015/tailsOS-Configurations.git
cd tailsOS-Configurations
chmod +x scripts/*.sh configs/network/iptables-rules.sh
```

Then run the interactive wizard:

```bash
bash scripts/setup-wizard.sh
```

Or if you prefer to do things step by step, see [`docs/USAGE.md`](USAGE.md).

---

## Security habits to build from day one

| Habit | Why |
|---|---|
| Always verify the Tails ISO before flashing | Protects against tampered downloads |
| Set a new admin password each session | Limits damage if someone watches you type |
| Wait for Tor before browsing or cloning | Prevents clearnet connections |
| Never reuse the same Tails for different identities | Partition your threat models |
| Save sensitive files to `~/Persistent/` only | Everything else vanishes on reboot |
| Strip metadata from files before sharing | Use `mat2` or `exiftool -all= <file>` |
| Do not install software outside Tails' package repos | Unverified binaries undermine Tails' security |
| Do not maximise the Tor Browser window | Full-screen leaks your screen resolution |
| Use HTTPS / .onion addresses whenever possible | Protects against malicious Tor exit nodes |

---

## What Tails does NOT protect you from

Tails is a powerful privacy tool, but it has limits.  Know them:

- **A compromised Tor Browser** (e.g. via malicious JavaScript) can potentially
  deanonymise you.  Use the *Safest* security level for sensitive browsing.
- **Your behaviour** — writing your name in a document, logging into a personal
  account, or reusing usernames defeats anonymisation.
- **Physical observation** — someone watching your screen or noting when you
  plug in your Tails USB.
- **Global network adversaries** — Tor does not protect against an adversary who
  can watch both the entry and exit of your connection (traffic correlation).
- **Compromised hardware** — a keylogger or a tampered BIOS can capture
  everything.

See [`docs/THREAT-MODEL.md`](THREAT-MODEL.md) for a full threat matrix.

---

## Further reading

- [Tails documentation](https://tails.boum.org/doc/)
- [Tails — How Tor works](https://tails.boum.org/doc/anonymous_internet/tor/)
- [Tor Project](https://www.torproject.org/)
- [`docs/USAGE.md`](USAGE.md) — step-by-step guide to the scripts in this repo
- [`docs/SECURITY-NOTES.md`](SECURITY-NOTES.md) — security assumptions
- [`docs/THREAT-MODEL.md`](THREAT-MODEL.md) — who are you hiding from?
- [`docs/PACKAGES.md`](PACKAGES.md) — what does each installed package do?
