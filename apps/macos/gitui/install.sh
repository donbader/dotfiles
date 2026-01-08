#!/bin/bash

# Check if gitui is already installed
if command -v gitui &> /dev/null; then
    echo "gitui is already installed"
    exit 0
fi

brew install gitui
