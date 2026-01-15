#!/bin/bash

# Link .zshenv to home directory
ln -sf "$(pwd)/.zshenv" "$HOME/.zshenv"

echo "Linked .zshenv (Linux-specific zsh environment configuration)"
