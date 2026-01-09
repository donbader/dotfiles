# ------------------------------
# Flox Post-Init Hook  
# ------------------------------
# Suppresses the "compinit being called again" warning when flox activates

# When flox activates and changes fpath, it calls compinit to reload completions.
# This triggers a warning because zim already initialized completions.
# Solution: Just make compinit a no-op since completions are already loaded.
# New completions from flox packages will work after restarting the shell.

if (( ${+functions[compinit]} )); then
  # Replace compinit with a no-op that silently succeeds
  # This prevents the warning and avoids reinitializing completions unnecessarily
  compinit() { return 0; }
fi
