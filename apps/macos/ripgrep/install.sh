#!/bin/bash

# Check if ripgrep is already installed
if command -v rg &> /dev/null; then
    echo "ripgrep is already installed"
    exit 0
fi

brew install ripgrep
