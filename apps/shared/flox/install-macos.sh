#!/bin/bash
# Flox installation for macOS

if command -v brew >/dev/null 2>&1; then
  brew install flox
else
  echo "Homebrew not found. Install Flox manually with:"
  echo "curl -fsSL https://downloads.flox.dev/by-env/stable/macos/install | bash"
  exit 1
fi
