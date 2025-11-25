#!/bin/bash

# Check if tig is already installed
if command -v tig &> /dev/null; then
    echo "tig is already installed"
    exit 0
fi

brew install tig
