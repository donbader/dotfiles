# ------------------------------
# Flox Pre-Init Hook
# ------------------------------
# Prevents duplicate compinit calls when flox is activated
# This runs BEFORE zim initialization to stub out compinit

# If compinit was already called (by flox), stub it out temporarily for zim
if [[ -n "${FLOX_ENV}" ]] && typeset -f compinit > /dev/null; then
  # compinit already exists (called by flox), so stub it out temporarily
  _orig_compinit=$(which compinit)
  compinit() { : ; }  # No-op function
  
  # Store flag to restore compinit after zim init
  typeset -g _FLOX_STUBBED_COMPINIT=1
fi
