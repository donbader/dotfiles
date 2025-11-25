#!/bin/bash

# Check if vim is already installed
if command -v vim &> /dev/null; then
    echo "vim is already installed"
    exit 0
fi

brew install vim
