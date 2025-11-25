#!/bin/bash

# Check if Homebrew is already installed
if command -v brew &> /dev/null; then
    echo "Homebrew is already installed"
    exit 0
fi

# Install Homebrew
echo "Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "Homebrew installed successfully"
echo "Note: Stow the homebrew config to add Homebrew to your PATH"
