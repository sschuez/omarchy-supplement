#!/bin/bash

# Add include lines to Omarchy's config files so they load our overrides.
# Each line is only added if it isn't there yet, so this is safe to re-run.
set -e

add_line() {
  local file="$1"
  local line="$2"

  if [ ! -f "$file" ]; then
    echo "Missing $file. Is Omarchy installed?" >&2
    exit 1
  fi

  if grep -qxF "$line" "$file"; then
    echo "Already set up: $file"
  else
    printf '\n# Personal overrides from omarchy-dotfiles\n%s\n' "$line" >> "$file"
    echo "Added overrides to $file"
  fi
}

add_line "$HOME/.bashrc" '[[ -r ~/.config/bash/aliases ]] && source ~/.config/bash/aliases'

