# ------------------------------
# Flox Post-Init Hook
# ------------------------------
# Restores compinit after zim initialization if it was stubbed in pre-init

# Restore original compinit if we stubbed it out in pre-init
if [[ -n "${_FLOX_STUBBED_COMPINIT}" ]]; then
  unfunction compinit 2>/dev/null
  [[ -n "${_orig_compinit}" ]] && autoload -Uz compinit
  unset _orig_compinit
  unset _FLOX_STUBBED_COMPINIT
fi
