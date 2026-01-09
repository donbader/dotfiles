# ====================
# Zsh Configuration
# ====================
#
# Modular zsh configuration with three-stage initialization
# Apps can add their configs to ~/.config/zsh/{pre-init,init,post-init}/
#
# Execution order:
#   1. pre-init/   - Runs FIRST (e.g., stub functions before frameworks load)
#   2. init/       - Main initialization (options, zim, most configs)
#   3. post-init/  - Runs LAST (e.g., keybindings, instant prompts, overrides)

# Source all files from a directory, sorted alphabetically
_zsh_source_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    for file in "$dir"/*.zsh(N); do
      [[ -f "$file" ]] && source "$file"
    done
  fi
}

# 1. Pre-init stage (before everything)
_zsh_source_dir ~/.config/zsh/pre-init

# 2. Init stage (main initialization, includes zim)
_zsh_source_dir ~/.config/zsh/init

# 3. Post-init stage (after everything)
_zsh_source_dir ~/.config/zsh/post-init

# Cleanup
unfunction _zsh_source_dir
