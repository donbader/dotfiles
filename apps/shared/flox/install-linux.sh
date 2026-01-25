#!/bin/bash
# Flox installation for Linux

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y flox
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y flox
elif command -v yum >/dev/null 2>&1; then
  sudo yum install -y flox
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --noconfirm flox
else
  echo "No supported package manager found. Install Flox manually with:"
  echo "curl -fsSL https://downloads.flox.dev/by-env/stable/linux/install | bash"
  exit 1
fi
