# ------------------------------
# Powerlevel10k Post-Init Hook
# ------------------------------
# Enables instant prompt after zim initialization
# This runs AFTER zim has been initialized and loaded the p10k theme

# Enable Powerlevel10k instant prompt
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# 
# Skip instant prompt when in flox-activated shells to avoid compinit warnings
# since flox may call compinit again when fpath changes
if [[ -z "${FLOX_ENV}" && -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
