# Easier navigation: .., ..., ...., ....., ~ and -
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~" # `cd` is probably faster to type though
alias -- -="cd -"

# Shortcuts
alias reload="source ~/.zshrc"
alias .files="git --git-dir=$DOTFILES/.git --work-tree=$DOTFILES $@"
function .cmp!() { .files add --all; .files commit; .files push }
function .edit!() { code $DOTFILES }
function .bbundle!() { exec 3>&1; zsh -c "cd $DOTFILES && brew bundle 1>&3 2>&3" }


alias otp="BUNDLE_GEMFILE=/Users/corey/Projects/useful-utils/Gemfile bundle exec ruby /Users/corey/Projects/useful-utils/bin/otp"
alias vpn_connect_fazz="BUNDLE_GEMFILE=/Users/corey/Projects/useful-utils/Gemfile bundle exec ruby /Users/corey/Projects/useful-utils/bin/connect_fazz_vpn"
alias vpn_disconnect_fazz="/Applications/Pritunl.app/Contents/Resources/pritunl-client stop rsruva15yinkim5g"
alias vpn_watch="/Applications/Pritunl.app/Contents/Resources/pritunl-client watch"

# Error correcting
alias gti=git
