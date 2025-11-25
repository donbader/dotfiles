#!/bin/bash

# Check if Warp is already installed
if [[ -d "/Applications/Warp.app" ]]; then
    echo "Warp is already installed"
    exit 0
fi

brew install --cask warp
