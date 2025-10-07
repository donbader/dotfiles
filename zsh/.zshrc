# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.dotfiles/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Environment
export DOTFILES=$HOME/.dotfiles
export ZSH=$DOTFILES/zsh/ohmyzsh
export ZDOTDIR=$DOTFILES/zsh

# Paths
# Brew
export PATH=/opt/homebrew/bin:$PATH

export PATH="/usr/local/bin:$PATH"
export PATH="/usr/local/sbin:$PATH"

# RVM
export PATH="$PATH:$HOME/.rvm/bin"

source $ZDOTDIR/aliases.zsh
source $ZDOTDIR/config.zsh

export PATH=${PATH}:/usr/local/mysql/bin


# For building
export MAKEFLAGS="--jobs $(sysctl -n hw.ncpu)"

# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/corey/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/corey/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/corey/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/corey/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

# bun completions
[ -s "/Users/corey/.bun/_bun" ] && source "/Users/corey/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
source "$HOME/.cargo/env"

# To customize prompt, run `p10k configure` or edit ~/.dotfiles/zsh/.p10k.zsh.
[[ ! -f ~/.dotfiles/zsh/.p10k.zsh ]] || source ~/.dotfiles/zsh/.p10k.zsh

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"
