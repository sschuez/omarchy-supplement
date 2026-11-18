#!/bin/bash

# Clone omarchy-dotfiles (if needed) and symlink its packages into ~ with Stow.
set -e

REPO_URL="https://github.com/sschuez/omarchy-dotfiles.git"
REPO_DIR="$HOME/Code/omarchy-dotfiles"
PACKAGES=(bash hypr omarchy xcompose tmux nvim mise herdr bin claude)   # add more as you create them

# Files we own outright instead of overlaying (relative to ~). Omarchy ships its
# own copy, and Stow won't replace a real file, so it's moved aside first.
OWNED_FILES=(
  .config/nvim/lazyvim.json   # LazyVim extras; edit with :LazyExtras
  .config/herdr/config.toml   # Herdr has no include mechanism
)

# Make sure Stow is installed (reuses install-stow.sh; does nothing if already there)
if ! command -v stow >/dev/null 2>&1; then
  bash "$(dirname "$0")/install-stow.sh"
fi

if [ -d "$REPO_DIR/.git" ]; then
  echo "omarchy-dotfiles already cloned, skipping clone"
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

for file in "${OWNED_FILES[@]}"; do
  target="$HOME/$file"
  # -L: is a symlink (already ours). Only move real files out of the way.
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "Backing up Omarchy's $file"
    mv "$target" "$target.bak.$(date +%s)"
  fi
done

# Stow links a whole folder when it doesn't exist yet. These must be real
# folders with only the files inside linked: ~/.local/bin is shared with other
# tools, and Omarchy's shell only loads plugins from real folders.
REAL_DIRS=(
  .local/bin
  .config/omarchy/plugins/stephen.workspaces
  .claude/hooks
)
for dir in "${REAL_DIRS[@]}"; do
  [ -L "$HOME/$dir" ] && rm "$HOME/$dir" # a folder link from an earlier run
  mkdir -p "$HOME/$dir"
done

for package in "${PACKAGES[@]}"; do
  echo "Stowing $package"
  stow --restow --dir="$REPO_DIR" --target="$HOME" "$package"
done
