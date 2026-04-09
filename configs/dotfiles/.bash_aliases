# ~/.bash_aliases — Shell aliases for Tails OS sessions
# Sourced by ~/.bashrc.

# ── Navigation ────────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# ── ls variants ───────────────────────────────────────────────────────────────
alias ll='ls -lhF --color=auto'
alias la='ls -lAhF --color=auto'
alias l='ls -CF --color=auto'
alias lt='ls -lhFt --color=auto'        # sort by modification time
alias lS='ls -lhFS --color=auto'        # sort by size

# ── Safety aliases ────────────────────────────────────────────────────────────
alias rm='rm -I --preserve-root'        # prompt before removing >3 files
alias mv='mv -i'                        # prompt before overwrite
alias cp='cp -i'                        # prompt before overwrite
alias ln='ln -i'                        # prompt before overwrite
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'

# ── Disk / filesystem ─────────────────────────────────────────────────────────
alias df='df -h'
alias du='du -h --max-depth=1'
alias free='free -h'

# ── Networking / Tor ──────────────────────────────────────────────────────────
alias myip='torsocks curl -s https://check.torproject.org/api/ip'
alias torcheck='torsocks curl -s https://check.torproject.org/api/ip | python3 -m json.tool'
alias ports='ss -tulanp'
alias fw='sudo iptables -L -v -n'      # show firewall rules
alias fw6='sudo ip6tables -L -v -n'    # show IPv6 firewall rules

# ── System info ───────────────────────────────────────────────────────────────
alias psa='ps auxf'
alias top='htop 2>/dev/null || top'
alias syslog='sudo journalctl -xe'
alias dmesg='sudo dmesg --color=always | less -R'

# ── Security tools ────────────────────────────────────────────────────────────
alias checksudo='sudo -v && echo "sudo OK" || echo "sudo NOT available"'
alias scrub='shred -vuz'                # securely wipe a file
alias wipe='sudo wipe -rf'             # wipe (requires wipe package)

# ── Git ───────────────────────────────────────────────────────────────────────
alias gs='git status'
alias gl='git log --oneline --graph --decorate --all'
alias gd='git diff'
alias ga='git add'
alias gc='git commit'

# ── Misc utilities ────────────────────────────────────────────────────────────
alias h='history'
alias j='jobs -l'
alias now='date +"%Y-%m-%d %H:%M:%S"'
alias path='echo -e ${PATH//:/\\n}'
alias reload='source ~/.bashrc && echo "bashrc reloaded."'

# ── Tails-specific ────────────────────────────────────────────────────────────
alias persist='ls -la /live/persistence/TailsData_unlocked/ 2>/dev/null || echo "Persistent Storage not found."'
alias tailsver='grep TAILS_VERSION_ID /etc/os-release 2>/dev/null || cat /etc/tails_version 2>/dev/null || echo "Not a Tails system."'

# ── Metadata stripping helpers ────────────────────────────────────────────────
alias stripexif='exiftool -all= '      # strip all EXIF from file(s)
alias stripmat='mat2 '                 # strip metadata via mat2
