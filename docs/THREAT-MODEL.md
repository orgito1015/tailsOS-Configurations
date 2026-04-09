# Threat Model

This document describes, in plain language, who you might be hiding from when
using Tails and these scripts, what protection you get at each layer, and where
the gaps are.

---

## Who is the adversary?

There is no single adversary.  The question is: *what is realistic for your
situation?*

| Adversary | Example | Capability |
|---|---|---|
| **Passive ISP / network provider** | Your home ISP logging your traffic | Can see which websites you visit (without Tor); cannot read HTTPS content |
| **Local network attacker** | Someone on the same Wi-Fi | Can intercept unencrypted traffic; may attempt ARP spoofing |
| **Website / service operator** | A website you visit | Can see your HTTP requests; knows your Tor exit IP, not your real IP |
| **Malicious Tor exit node** | A relay run by an adversary | Can read unencrypted HTTP traffic; cannot read HTTPS |
| **Global passive adversary** | Intelligence agency logging all Tor traffic | Can attempt entry-to-exit traffic correlation over time |
| **Physical adversary** | Someone with access to your device | Cold-boot attacks, evil maid, keyloggers |
| **Targeted law enforcement** | A warrant served to your ISP or hosting provider | Legal access to metadata at endpoints |

---

## Threat matrix

### What Tails itself protects against (before running these scripts)

| Threat | Tails protection | Limitation |
|---|---|---|
| Traffic surveillance by ISP | ✅ All traffic through Tor | Tor itself may be blocked or slowed |
| DNS leaks | ✅ DNS resolved through Tor | |
| Browser fingerprinting | ✅ Tor Browser standardises fingerprint | Screen resolution leak if window is maximised |
| Persistent malware | ✅ Amnesic OS; RAM wiped on shutdown | Malware in Persistent Storage can survive |
| Local disk forensics | ✅ Nothing written to the boot drive | Persistent Storage is encrypted at rest |
| MAC address tracking | ✅ Randomised at boot | Consistent within a session |
| Compromised apps leaking data | ✅ AppArmor profiles for most apps | Custom/installed apps may not have profiles |

### What the scripts in this repository add

| Threat | Script mitigation | Limitation |
|---|---|---|
| Unsolicited inbound TCP connections | `01-network-hardening.sh` — drops INVALID/SYN | Additive to Tails' own iptables |
| IPv6 traffic bypassing Tor | `01-network-hardening.sh` — ip6tables DROP all | Tails already blocks IPv6; this is belt-and-braces |
| Kernel pointer leaks to unprivileged users | `02-security-hardening.sh` — `kptr_restrict=2` | |
| ptrace-based process injection | `02-security-hardening.sh` — `ptrace_scope=1` | |
| DMA attacks via Firewire | `02-security-hardening.sh` — unloads `firewire_ohci` | Thunderbolt DMA not addressed |
| New USB devices after session start | `02-security-hardening.sh` — `authorized_default=0` | Devices plugged in at boot remain authorised |
| Clock fingerprinting via TCP timestamps | `02-security-hardening.sh` — `tcp_timestamps=0` | |
| Stray metadata in shared files | `04-package-install.sh` installs `mat2`, `exiftool` | User must still strip metadata manually |
| Rootkits / known malware | `04-package-install.sh` installs `rkhunter`, `chkrootkit` | Both tools produce false positives on live systems |
| Hardening not applied after reboot | `05-persistent-setup.sh` — XDG autostart re-applies | Depends on GNOME autostart; sudo cache timing |
| Hardening measures silently reverted | `06-verify.sh` — read-only audit with PASS/FAIL table | Only checks what the scripts set |
| Residual session artifacts on shutdown | `07-cleanup.sh` — clears history, /tmp, caches | RAM wipe on shutdown is Tails' own `sdmem` |
| curl/wget making clearnet connections | `configs/apparmor/` profiles | User must load profiles with `apparmor_parser` |
| SSH traffic not routed through Tor | `configs/ssh/config` — `ProxyCommand torsocks nc` | |
| GPG passphrase cached too long | `configs/gpg/gpg-agent.conf` — 300s TTL | |
| Accidental upgrade to Debian Testing/Unstable | `configs/apt/preferences` — pins Bookworm | |

### What neither Tails nor these scripts protect against

| Threat | Why it is out of scope | What you can do |
|---|---|---|
| **Global traffic correlation** | An adversary watching both entry and exit Tor nodes can correlate timing | Use long-lived streams; avoid persistent patterns of behaviour |
| **Compromised Tor Browser** | A 0-day in Firefox/Gecko can run arbitrary code | Use "Safest" security level; avoid unknown websites |
| **Malicious JavaScript** | At "Standard" or "Safer" security level, JS can fingerprint you | Use "Safest" or keep JS disabled |
| **Physical access to running machine** | Attackers with physical access can perform cold-boot, DMA, or screen observation attacks | Never leave a running Tails unattended; use screen lock |
| **Evil maid (tampered hardware/firmware)** | A BIOS or USB keylogger captures credentials before Tails even starts | Boot from a USB you keep physically secure; verify Tails integrity regularly |
| **Behavioural deanonymisation** | Logging into personal accounts, reusing usernames, writing identifying information | Practice compartmentalisation |
| **Endpoint compromise at the other end** | The server or person you communicate with may be compromised or compelled | Use end-to-end encryption; assume servers may be seized |
| **Timing attacks via Tor** | High-resolution timing of your Tor circuits can be used for correlation | Not practically mitigable at the user level |
| **Compromised Persistent Storage** | If your Persistent Storage passphrase is known, the encrypted volume can be decrypted | Use a long, random passphrase; keep the USB physically secure |
| **UEFI/Secure Boot bypass** | A sophisticated adversary may attack the firmware layer | Use a dedicated hardware device for Tails; check BIOS settings |

---

## Practical guidance by use case

### Journalist communicating with a source

- Use Tor Browser at "Safest" level
- Communicate via .onion addresses (Signal's onion address, SecureDrop)
- Strip all metadata from documents before sharing (`mat2`)
- Do not log into personal accounts during the same session
- Use a dedicated USB drive that never leaves your control

### Activist in a high-surveillance environment

- Use `01-network-hardening.sh` and `02-security-hardening.sh`
- Enable full-disk encryption on any files you save (store in an encrypted
  VeraCrypt volume in `~/Persistent/`)
- Be aware of physical surveillance; use the screen lock (5-minute timeout)
- Consider using Tails on a machine with no persistent storage at all

### Developer testing privacy tooling

- The full script suite is appropriate
- The verify script (`06-verify.sh`) is particularly useful to confirm settings
- Run `07-cleanup.sh` before handing back shared hardware

---

## How these layers stack up

```
┌──────────────────────────────────────────────────────────────────┐
│  Your activity (what you type, who you talk to)                  │  ← You are responsible
├──────────────────────────────────────────────────────────────────┤
│  Application layer (Tor Browser, email, SSH, GPG)                │  ← configs/ in this repo
├──────────────────────────────────────────────────────────────────┤
│  Operating system (Tails + these scripts)                        │  ← scripts/ in this repo
├──────────────────────────────────────────────────────────────────┤
│  Network layer (Tor)                                             │  ← Tails built-in
├──────────────────────────────────────────────────────────────────┤
│  Hardware / firmware (BIOS, USB, RAM)                            │  ← Physical security
└──────────────────────────────────────────────────────────────────┘
```

No tool protects every layer.  Understand where you sit on this stack and act
accordingly.
