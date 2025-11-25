#!/bin/bash

# Check if Brave is already installed
if [[ -d "/Applications/Brave Browser.app" ]]; then
    echo "Brave Browser is already installed"
    exit 0
fi

brew install --cask brave-browser
