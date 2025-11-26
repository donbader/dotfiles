#!/bin/bash

if command -v opencode &> /dev/null; then
  echo "OpenCode is already installed ($(opencode --version))"
  exit 0
fi

echo "Installing OpenCode..."
curl -fsSL https://opencode.ai/install | bash

# Remove OpenCode PATH export from .zshrc since we manage it via dotfiles
if [ -f "$HOME/.zshrc" ]; then
  sed -i '' '/# opencode/d' "$HOME/.zshrc"
  sed -i '' '\|export PATH=.*\.opencode/bin.*PATH|d' "$HOME/.zshrc"
  echo "Removed OpenCode PATH export from .zshrc (managed via dotfiles)"
fi
