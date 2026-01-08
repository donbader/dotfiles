#!/bin/bash

# Check if powerlevel10k is already installed
if command -v p10k &> /dev/null; then
    echo "powerlevel10k is already installed"
    exit 0
fi

# Install powerlevel10k for Linux
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.powerlevel10k
