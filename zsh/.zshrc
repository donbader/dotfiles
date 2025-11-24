# Source all configs from ~/.config/zsh/
for config in ~/.config/zsh/*.zsh; do
    [ -f "$config" ] && source "$config"
done
