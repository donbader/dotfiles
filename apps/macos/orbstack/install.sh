#!/bin/bash

# Check if OrbStack is already installed
if [[ -d "/Applications/OrbStack.app" ]]; then
    echo "OrbStack is already installed"
    exit 0
fi

brew install --cask orbstack
