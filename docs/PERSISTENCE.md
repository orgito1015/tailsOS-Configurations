# Persistent Storage in Tails OS

Understanding what persists and what does not is critical for safely using Tails.

---

## How Tails handles persistence

Tails is designed as an **amnesic** operating system.  By default:

- Every file written during a session is stored in RAM.
- All RAM is wiped when you shut down or reboot.
- No trace of your session is left on the boot USB drive.

**Persistent Storage** is an optional, encrypted partition on your Tails USB drive.  It survives reboots and is unlocked at the Greeter (login screen).

---

## Persistent Storage location

When Persistent Storage is unlocked, it is mounted at:

```
/live/persistence/TailsData_unlocked/
```

Tails automatically mounts selected subdirectories of this volume over their live counterparts using bind mounts.

---

## What Tails can persist (built-in features)

Enable these in: **Applications → Tails → Configure Persistent Volume**

| Feature | What is persisted |
|---|---|
| **Personal Data** | `~/Persistent/` — your documents, downloads, etc. |
| **Welcome Screen** | Greeter settings (language, keyboard, admin password hint) |
| **Additional Software** | List of apt packages to auto-install on each boot |
| **Dotfiles** | Files in `TailsData_unlocked/dotfiles/` are symlinked into `~/` |
| **Tor Browser Bookmarks** | Tor Browser bookmarks |
| **Network Connections** | Wi-Fi passwords and other NetworkManager connections |
| **Bitcoin Wallet** | Electrum wallet |
| **GnuPG** | GPG keys and configuration |
| **Pidgin** | Off-the-record chat accounts and logs |
| **SSH Client** | SSH keys and `~/.ssh/config` |
| **Thunderbird** | Email account configuration |

---

## The Dotfiles mechanism

The **Dotfiles** feature in Persistent Storage works as follows:

1. At boot, Tails reads files from `/live/persistence/TailsData_unlocked/dotfiles/`.
2. Each file (or directory subtree) is symlinked into the amnesia home directory `~/`.
3. Example: `TailsData_unlocked/dotfiles/.bashrc` → `~/.bashrc`

### What `05-persistent-setup.sh` does

```
TailsData_unlocked/
└── dotfiles/
    ├── .bashrc                          # symlinked to ~/.bashrc
    ├── .bash_aliases                    # symlinked to ~/.bash_aliases
    ├── .vimrc                           # symlinked to ~/.vimrc
    ├── .gitconfig                       # symlinked to ~/.gitconfig
    └── .config/
        ├── autostart/
        │   ├── tails-sysctl-hardening.desktop    # runs sysctl at login
        │   └── tails-iptables-hardening.desktop  # runs iptables at login
        └── tails-hardening/
            ├── sysctl-hardening.conf    # kernel parameters
            └── iptables-rules.sh        # firewall rules
```

The XDG autostart `.desktop` files cause GNOME to automatically re-apply the sysctl and iptables settings at the start of each desktop session.

### Prerequisites

Before running `05-persistent-setup.sh`:

1. Persistent Storage must be enabled.
2. The **Dotfiles** feature must be turned on in the Persistent Volume configuration.

```
Applications → Tails → Configure Persistent Volume → Dotfiles → Enable
```

---

## What does NOT persist

- Installed packages (unless listed in *Additional Software*)
- Changes to `/etc/` (unless you set up a custom persistence configuration)
- The bash command history (the scripts deliberately disable history file writing)
- Browser history (Tor Browser resets on each boot)
- sudo password cache

---

## Enabling persistence for extra `/etc/` files

For advanced users: you can persist arbitrary file paths by adding entries to
`/live/persistence/TailsData_unlocked/persistence.conf`.

Example — persist `/etc/sysctl.d/99-hardening.conf`:

```
/etc/sysctl.d	source=sysctl.d,link
```

Then create `TailsData_unlocked/sysctl.d/99-hardening.conf`.

⚠️ **Warning:** Modifying `persistence.conf` incorrectly can prevent Persistent Storage from loading.  Back up the file before editing.

---

## Security considerations

- Persistent Storage is encrypted with LUKS using the passphrase you set when creating it.
- If your USB drive is seized and the passphrase is unknown, the data is inaccessible.
- Do not store highly sensitive secrets in Persistent Storage without additional encryption (e.g. GPG-encrypted files or a KeePassXC database with a strong password).
- The Dotfiles mechanism creates symlinks visible to any process running as `amnesia`.  Ensure the files themselves do not contain secrets.
