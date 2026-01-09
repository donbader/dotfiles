# Flox Configuration
# Disable flox's built-in prompt (Powerlevel10k will handle it)
export FLOX_PROMPT_ENVIRONMENTS=0
export FLOX_PROMPT_COLOR_1=""
export FLOX_PROMPT_COLOR_2=""

# Note: Flox/zim compinit integration is handled in:
# - zim pre-init: stubs compinit when starting shell inside flox
# - zim init: restores compinit after zim initialization
# - flox post-init: wraps compinit to suppress warnings on flox activate
