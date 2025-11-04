#### fzf cross-platform setup (Ubuntu, macOS, manual git) ####

# 1) Find fzf base dir (where shell/* lives) and the bin dir
FZF_BASE=""
FZF_BIN_DIR=""

# Prefer Homebrew if present (macOS or Linuxbrew)
if command -v brew >/dev/null 2>&1; then
  if brew --prefix fzf >/dev/null 2>&1; then
    FZF_BASE="$(brew --prefix fzf)"
    FZF_BIN_DIR="$FZF_BASE/bin"
  fi
fi

# Manual installer (~/.fzf) fallback
if [ -z "$FZF_BASE" ] && [ -d "$HOME/.fzf" ]; then
  FZF_BASE="$HOME/.fzf"
  FZF_BIN_DIR="$HOME/.fzf/bin"
fi

# Ubuntu/Debian package common locations
# (Newer Debian/Ubuntu often provide /usr/share/fzf; older ones ship examples under /usr/share/doc/fzf/examples)
if [ -z "$FZF_BASE" ]; then
  if [ -d /usr/share/fzf ]; then
    FZF_BASE="/usr/share/fzf"
  elif [ -d /usr/share/doc/fzf/examples ]; then
    FZF_BASE="/usr/share/doc/fzf/examples"
  fi
fi

# If the binary is installed system-wide but not in the chosen base, just rely on PATH
if [ -z "$FZF_BIN_DIR" ] && command -v fzf >/dev/null 2>&1; then
  FZF_BIN_DIR="$(dirname "$(command -v fzf)")"
fi

# 2) Put fzf binary on PATH if needed
if [ -n "$FZF_BIN_DIR" ] && ! echo ":$PATH:" | grep -q ":$FZF_BIN_DIR:"; then
  export PATH="${PATH:+${PATH}:}$FZF_BIN_DIR"
fi

# 3) Source completion & key bindings (Zsh variants)
# Try typical locations in order; handle .gz on older Debian/Ubuntu.
_try_source() {
  # usage: _try_source /path/to/file(.zsh or .zsh.gz)
  if [ -f "$1" ]; then
    # plain file
    # shellcheck disable=SC1090
    source "$1" 2>/dev/null
    return $?
  elif [ -f "$1.gz" ]; then
    # gzipped file (Debian/Ubuntu examples)
    command -v gzip >/dev/null 2>&1 && \
      gzip -dc "$1.gz" 2>/dev/null | source /dev/stdin
    return $?
  fi
  return 1
}

# Only in interactive shells
case $- in
  *i*)
    # Completion
    _try_source "$FZF_BASE/shell/completion.zsh" || \
    _try_source "/usr/share/fzf/completion.zsh"  || \
    _try_source "/usr/share/doc/fzf/examples/completion.zsh"

    # Key bindings
    _try_source "$FZF_BASE/shell/key-bindings.zsh" || \
    _try_source "/usr/share/fzf/key-bindings.zsh"  || \
    _try_source "/usr/share/doc/fzf/examples/key-bindings.zsh"
  ;;
esac

# 4) Defaults
export FZF_DEFAULT_OPTS='--height 40% --reverse --border --inline-info'
