#!/bin/bash

# Check if powerlevel10k is already installed
if command -v p10k &> /dev/null; then
    echo "powerlevel10k is already installed"
    exit 0
fi

brew install powerlevel10k
