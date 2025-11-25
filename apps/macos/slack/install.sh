#!/bin/bash

# Check if Slack is already installed
if [[ -d "/Applications/Slack.app" ]]; then
    echo "Slack is already installed"
    exit 0
fi

brew install --cask slack
