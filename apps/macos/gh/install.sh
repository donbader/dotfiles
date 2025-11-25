#!/bin/bash

# Check if gh is already installed
if command -v gh &> /dev/null; then
    echo "GitHub CLI is already installed"
    exit 0
fi

brew install gh
