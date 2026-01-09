# ------------------------------
# Flox Init Hook (runs after zim)
# ------------------------------
# Restores compinit if it was stubbed in pre-init
# This file is named to load AFTER zim.zsh alphabetically

# Restore original compinit if flox stubbed it out in pre-init
# This handles the case when starting a shell inside an existing flox environment
# We stubbed compinit before zim (in pre-init), and now restore it after zim initialization
if [[ -n "${_FLOX_STUBBED_COMPINIT}" ]]; then
  unfunction compinit 2>/dev/null
  [[ -n "${_orig_compinit}" ]] && autoload -Uz compinit
  unset _orig_compinit
  unset _FLOX_STUBBED_COMPINIT
fi
