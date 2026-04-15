# Getting Admin Access in Tails OS

By default Tails boots with **no administrator (root / sudo) privileges**.
This is intentional: limiting what programs can do protects your anonymity
and the integrity of the system.  However, the scripts in this repository
need admin rights to install packages, change firewall rules, and write
system configuration files.

This page explains exactly how to unlock admin access, how to use it, and
how to keep yourself safe while doing so.

---

## What "admin access" means in Tails

Tails uses `sudo` — the standard Linux privilege-escalation tool.  When you
have an admin password, you can prefix any command with `sudo` to run it as
root:

```bash
sudo apt-get install vim
sudo iptables -L
sudo bash scripts/02-security-hardening.sh
```

The password is only valid **for the current session**.  It is forgotten when
you shut down or reboot Tails.  You must set it again each time.

---

## Step 1 — Set an admin password at the Greeter

The Greeter is the screen that appears **before the Tails desktop loads**.

1. Boot your Tails USB as normal.
2. At the Greeter, look for the **"Additional Settings"** section (bottom-left,
   click the `+` button or the gear icon depending on your Tails version).
3. Click **"Administration Password"**.
4. Enter a strong password.  Write it down on paper if needed — you will need
   to type it every time you run `sudo` this session.
5. Click **"Add"** to confirm, then click **"Start Tails"**.

> ⚠️ **Security note:** The admin password you set is valid only for this
> session.  Anyone who learns it can modify the live system and potentially
> deanonymise you.  Set a new, random password each boot.

---

## Step 2 — Open a terminal

After the desktop loads:

*Applications → System Tools → Terminal*

or press **Super** (Windows key) and search for "Terminal".

---

## Step 3 — Verify sudo works

```bash
sudo echo "Admin access confirmed"
```

You will be prompted for the password you set at the Greeter.  Type it and
press **Enter**.  If you see `Admin access confirmed`, you are ready.

---

## Step 4 — Run the scripts in this repository

Most scripts in this repository either call `sudo` internally (they will
re-launch themselves with root) or need to be called with `sudo` directly.

```bash
# Clone the repository (if you haven't already)
cd ~
git clone https://github.com/orgito1015/tailsOS-Configurations.git
cd tailsOS-Configurations

# Make all scripts executable
chmod +x scripts/*.sh configs/network/iptables-rules.sh

# Run the pre-flight check first (no sudo needed)
bash scripts/00-setup-check.sh

# Run everything in one go
bash scripts/run-all.sh

# Or run scripts individually:
bash scripts/01-network-hardening.sh
bash scripts/02-security-hardening.sh
bash scripts/03-dotfiles-setup.sh          # no sudo needed
bash scripts/04-package-install.sh         # needs sudo + Tor
bash scripts/09-desktop-setup.sh           # no sudo needed
bash scripts/09-desktop-setup.sh --openbox # needs sudo + Tor
```

---

## Troubleshooting

### "sudo: command not found"
Tails always ships with sudo.  If this message appears, something is very
wrong with your Tails installation.  Re-download and verify the ISO.

### "Sorry, try again." (wrong password)
Type the password you entered at the Greeter.  Note that the terminal does
**not** show any characters while you type (this is normal for security).

### "amnesia is not in the sudoers file"
You did not set an admin password at the Greeter.  **Reboot Tails** and set
the admin password before the desktop starts.  There is no way to add sudo
access once the session has begun without a pre-set admin password.

### "sudo: no tty present and no askpass program specified"
A script tried to call `sudo` non-interactively before you had cached the
password.  Run the script from a normal interactive terminal, not from a
cron job or background process.

---

## Escalating to a full root shell (use with care)

If you need to run many commands as root, you can open a root shell for the
entire session:

```bash
sudo -i
```

This gives you a root prompt (`#`).  Exit with `exit` or **Ctrl+D** when
done.  Be careful — mistakes in a root shell can damage the running system.

---

## Security reminders

| Do | Don't |
|---|---|
| Set a new admin password each boot | Reuse the same admin password across sessions |
| Use `sudo <command>` for single commands | Stay in a root shell longer than necessary |
| Close the terminal when done | Leave a root shell open and unattended |
| Verify scripts before running them | Pipe untrusted content directly into `bash` (e.g. `curl … | bash`) |
| Check `sudo -l` to see what is allowed | Run `sudo` for tasks that don't need it |

---

## Further reading

- [Tails documentation — Administration password](https://tails.boum.org/doc/first_steps/welcome_screen/administration_password/)
- [`docs/FIRST-BOOT.md`](FIRST-BOOT.md) — complete first-boot checklist
- [`docs/SECURITY-NOTES.md`](SECURITY-NOTES.md) — security assumptions in this repo
- [`docs/THREAT-MODEL.md`](THREAT-MODEL.md) — understanding your threat model
