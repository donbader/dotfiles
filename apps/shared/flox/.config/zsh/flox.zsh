# Flox Configuration
# Disable flox's built-in prompt (Starship will handle it)
export FLOX_PROMPT_ENVIRONMENTS=0
export FLOX_PROMPT_COLOR_1=""
export FLOX_PROMPT_COLOR_2=""

# Hook to restore Starship prompt after flox activation
_flox_restore_prompt() {
    # If we're in a flox environment and prompt was modified, restore it
    if [[ -n "$FLOX_ENV" ]]; then
        # Clear any PS1 modifications flox made
        unset PS1
        # Force Starship to reinitialize
        eval "$(starship init zsh)"
    fi
}

# Add hook to run after directory changes (when flox might activate)
autoload -Uz add-zsh-hook
add-zsh-hook precmd _flox_restore_prompt
