# Makefile — Convenience shortcuts for tailsOS-Configurations
# =============================================================================
# USAGE:
#   make check      — Run the pre-flight environment check
#   make harden     — Run network + system hardening (01 + 02)
#   make dotfiles   — Install dotfiles into ~/
#   make packages   — Install extra packages via apt over Tor
#   make persist    — Wire settings into Persistent Storage
#   make verify     — Run the post-setup hardening audit
#   make cleanup    — Clean session artifacts before shutdown
#   make wizard     — Launch the interactive setup wizard
#   make all        — Run check, harden, dotfiles, packages (same as run-all.sh)
#   make help       — Show this message
#
# NOTE: Individual targets that require root will auto-elevate via sudo.
#       Run make from the repository root directory.
# =============================================================================

SHELL := /bin/bash
SCRIPTS_DIR := scripts

.PHONY: all check harden network security dotfiles packages cybersec persist \
        verify cleanup wizard usb-whitelist help

# Default target
all: check network security dotfiles packages cybersec

# ── Pre-flight check ──────────────────────────────────────────────────────────
check:
	@bash $(SCRIPTS_DIR)/00-setup-check.sh

# ── Network hardening ─────────────────────────────────────────────────────────
network:
	@bash $(SCRIPTS_DIR)/01-network-hardening.sh

# ── System / kernel hardening ─────────────────────────────────────────────────
security:
	@bash $(SCRIPTS_DIR)/02-security-hardening.sh

# ── Combined hardening (network + system) ────────────────────────────────────
harden: network security

# ── Dotfiles ──────────────────────────────────────────────────────────────────
dotfiles:
	@bash $(SCRIPTS_DIR)/03-dotfiles-setup.sh
	@echo ""
	@echo "  Run: source ~/.bashrc   to apply shell changes to this session."

# ── Package installation ──────────────────────────────────────────────────────
packages:
	@bash $(SCRIPTS_DIR)/04-package-install.sh

# ── Cybersecurity tools ───────────────────────────────────────────────────────
cybersec:
	@bash $(SCRIPTS_DIR)/08-cybersecurity-tools.sh

# ── Persistent Storage setup ─────────────────────────────────────────────────
persist:
	@bash $(SCRIPTS_DIR)/05-persistent-setup.sh

# ── Post-setup hardening audit ────────────────────────────────────────────────
verify:
	@bash $(SCRIPTS_DIR)/06-verify.sh

# ── Session cleanup ───────────────────────────────────────────────────────────
cleanup:
	@bash $(SCRIPTS_DIR)/07-cleanup.sh

# ── Session cleanup + free space wipe ────────────────────────────────────────
cleanup-full:
	@bash $(SCRIPTS_DIR)/07-cleanup.sh --wipe-free-space

# ── Interactive wizard ────────────────────────────────────────────────────────
wizard:
	@bash $(SCRIPTS_DIR)/setup-wizard.sh

# ── USB whitelist ─────────────────────────────────────────────────────────────
usb-whitelist:
	@bash $(SCRIPTS_DIR)/usb-whitelist.sh

# ── Help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  tailsOS-Configurations — available make targets"
	@echo ""
	@echo "  make check          Pre-flight environment check (no changes)"
	@echo "  make harden         Network + system hardening (01 + 02)"
	@echo "  make network        Network hardening only (01)"
	@echo "  make security       Kernel/system hardening only (02)"
	@echo "  make dotfiles       Install dotfiles into ~/"
	@echo "  make packages       Install packages via apt over Tor"
	@echo "  make cybersec       Install cybersecurity tools via apt over Tor"
	@echo "  make persist        Wire settings into Persistent Storage"
	@echo "  make verify         Post-setup hardening audit (read-only)"
	@echo "  make cleanup        Clean session artifacts before shutdown"
	@echo "  make cleanup-full   Cleanup + wipe free space (slow)"
	@echo "  make wizard         Interactive setup wizard"
	@echo "  make usb-whitelist  Authorise whitelisted USB devices"
	@echo "  make all            Run check + harden + dotfiles + packages"
	@echo "  make help           Show this message"
	@echo ""
