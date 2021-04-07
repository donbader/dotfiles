# Environment
export DOTFILES=$HOME/.dotfiles
export ZSH=$DOTFILES/zsh/ohmyzsh
export ZDOTDIR=$DOTFILES/zsh

# Paths
# Brew
export PATH="/usr/local/bin:$PATH"
export PATH="/usr/local/sbin:$PATH"

# RVM
export PATH="$PATH:$HOME/.rvm/bin"

source $ZDOTDIR/aliases.zsh
source $ZDOTDIR/config.zsh

export PATH=${PATH}:/usr/local/mysql/bin
