#!/bin/bash

# Install zsh
brew install zsh

# Install Zim framework if not already installed
if [[ ! -d "${HOME}/.zim" ]]; then
    echo "Installing Zim framework..."
    curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
fi

# Set zsh as default shell
if [[ "$SHELL" != */zsh ]]; then
    echo "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
fi
