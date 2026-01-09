# ------------------------------
# Flox Post-Init Hook  
# ------------------------------
# Smart compinit wrapper that only reinitializes when fpath changes

# When flox activates and changes fpath, it calls compinit to reload completions.
# This wrapper tracks fpath changes and only reinitializes when necessary,
# avoiding redundant calls while still supporting dynamic completion loading.

if (( ${+functions[compinit]} )); then
  # Store the current fpath state after initial compinit
  typeset -g _LAST_COMPINIT_FPATH="${(j.:.)fpath}"
  
  # Create a wrapper function with a different name
  _wrapped_compinit() {
    local current_fpath="${(j.:.)fpath}"
    
    # Check if fpath actually changed since last init
    if [[ "${current_fpath}" != "${_LAST_COMPINIT_FPATH}" ]]; then
      # Undefine our wrapper temporarily to call the real compinit
      unfunction compinit
      autoload -Uz compinit
      compinit -C "$@"  # -C skips security check and suppresses warnings
      typeset -g _LAST_COMPINIT_FPATH="${current_fpath}"
      
      # Re-establish the wrapper
      compinit() { _wrapped_compinit "$@" }
    fi
  }
  
  # Replace compinit with our wrapper
  compinit() { _wrapped_compinit "$@" }
fi
