#!/bin/bash

# Check if iTerm2 is already installed
if [[ ! -d "/Applications/iTerm.app" ]]; then
    brew install --cask iterm2
else
    echo "iTerm2 is already installed"
fi
