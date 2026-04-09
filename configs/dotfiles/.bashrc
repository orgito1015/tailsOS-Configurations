# ~/.bashrc — Tails OS session shell configuration
# Managed by tailsOS-Configurations.
# This file is sourced for every interactive non-login bash shell.

# ── If not running interactively, don't do anything ─────────────────────────
case $- in
    *i*) ;;
      *) return;;
esac

# ── History settings ──────────────────────────────────────────────────────────
# Keep history in RAM only (HISTFILE="" disables disk persistence).
# This prevents command history from being accidentally saved.
HISTFILE=""
HISTSIZE=500
HISTCONTROL=ignoredups:erasedups:ignorespace

# ── Shell options ─────────────────────────────────────────────────────────────
shopt -s checkwinsize   # update LINES/COLUMNS after each command
shopt -s histappend     # append to history rather than overwrite (in-memory only)
shopt -s cmdhist        # save multi-line commands as single history entries
shopt -s cdspell        # auto-correct minor cd typos
shopt -s autocd         # type a directory name to cd into it

# ── Prompt ────────────────────────────────────────────────────────────────────
# Simple, clean prompt with working directory.  Displays a red "ROOT" indicator
# when running as root.
_tails_prompt() {
    local RESET='\[\033[0m\]'
    local BOLD='\[\033[1m\]'
    local RED='\[\033[31m\]'
    local GREEN='\[\033[32m\]'
    local YELLOW='\[\033[33m\]'
    local CYAN='\[\033[36m\]'

    if [[ "${EUID}" -eq 0 ]]; then
        PS1="${RED}[ROOT]${RESET} ${BOLD}${RED}\w${RESET} # "
    else
        PS1="${CYAN}\u${RESET}@${GREEN}tails${RESET}:${BOLD}\w${RESET} \$ "
    fi
}
PROMPT_COMMAND="_tails_prompt"

# ── Colour support ────────────────────────────────────────────────────────────
if [[ -x /usr/bin/dircolors ]]; then
    eval "$(dircolors -b)"
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'

# ── Pager ─────────────────────────────────────────────────────────────────────
export PAGER='less'
export LESS='-R --quit-if-one-screen'

# ── Editor ────────────────────────────────────────────────────────────────────
if command -v vim &>/dev/null; then
    export EDITOR='vim'
    export VISUAL='vim'
else
    export EDITOR='nano'
    export VISUAL='nano'
fi

# ── Privacy-friendly environment defaults ─────────────────────────────────────
# Do not save Python REPL history
export PYTHONDONTWRITEBYTECODE=1
export PYTHONHISTFILE=/dev/null

# Prevent less from saving history
export LESSHISTFILE=/dev/null

# Disable wget history (hsts)
export WGETRC=/dev/null

# ── Source aliases ────────────────────────────────────────────────────────────
if [[ -f ~/.bash_aliases ]]; then
    source ~/.bash_aliases
fi

# ── Completion ────────────────────────────────────────────────────────────────
if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        source /etc/bash_completion
    fi
fi

# ── PATH additions ────────────────────────────────────────────────────────────
# Add ~/.local/bin if it exists (user-installed scripts)
if [[ -d "${HOME}/.local/bin" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
fi
