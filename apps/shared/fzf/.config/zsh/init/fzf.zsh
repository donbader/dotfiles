# ----------------
# FZF Configuration
# ----------------
# Fuzzy finder setup and key bindings

export FZF_DEFAULT_OPTS='--height 40% --reverse --border --inline-info'

# fzf key bindings - platform detection
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  if command -v brew &> /dev/null; then
    source $(brew --prefix)/opt/fzf/shell/key-bindings.zsh
  fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux - Ubuntu/Debian package location
  if [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
  fi
fi
