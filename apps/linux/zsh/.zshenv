# ====================
# Zsh Environment (Linux)
# ====================
# This file is sourced on all shell invocations.
# Keep it minimal - only set environment variables here.

# Skip Ubuntu's system-wide compinit call in /etc/zsh/zshrc
# This prevents double initialization of the completion system
# which causes a warning when zimfw initializes completions.
# See: https://github.com/zimfw/zimfw/wiki/Troubleshooting#completion-is-not-working
skip_global_compinit=1
