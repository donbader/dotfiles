#!/bin/bash

# Check if VS Code is already installed
if [[ -d "/Applications/Visual Studio Code.app" ]]; then
    echo "Visual Studio Code is already installed"
    exit 0
fi

brew install --cask visual-studio-code
