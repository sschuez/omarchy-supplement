#!/bin/bash

# Clone omarchy-dotfiles (if needed) and symlink its packages into ~ with Stow.
set -e

REPO_URL="https://github.com/sschuez/omarchy-dotfiles.git"
REPO_DIR="$HOME/Code/omarchy-dotfiles"
PACKAGES=(bash)   # add more as you create them, e.g. (bash ghostty hypr)

# Make sure Stow is installed (reuses install-stow.sh; does nothing if already there)
if ! command -v stow >/dev/null 2>&1; then
  bash "$(dirname "$0")/install-stow.sh"
fi

if [ -d "$REPO_DIR/.git" ]; then
  echo "omarchy-dotfiles already cloned, skipping clone"
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

for package in "${PACKAGES[@]}"; do
  echo "Stowing $package"
  stow --restow --dir="$REPO_DIR" --target="$HOME" "$package"
done
