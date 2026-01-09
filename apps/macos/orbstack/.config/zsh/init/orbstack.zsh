# OrbStack: command-line tools and integration (optimized)
# Only add PATH, defer sourcing init for faster startup
[[ -d ~/.orbstack/bin ]] && export PATH="$PATH:/Users/corey/.orbstack/bin"

# Defer loading completions
[[ -f ~/.orbstack/shell/init.zsh ]] && {
    _orbstack_lazy_init() {
        source ~/.orbstack/shell/init.zsh 2>/dev/null
        unfunction _orbstack_lazy_init
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _orbstack_lazy_init
}
