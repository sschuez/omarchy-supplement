#!/bin/bash

# Add include lines to Omarchy's config files so they load our overrides.
# Each line is only added if it isn't there yet, so this is safe to re-run.
set -e

add_line() {
  local file="$1"
  local line="$2"
  local comment="${3:-#}"   # comment marker for this file type; defaults to #

  if [ ! -f "$file" ]; then
    echo "Missing $file. Is Omarchy installed?" >&2
    exit 1
  fi

  if grep -qxF "$line" "$file"; then
    echo "Already set up: $file"
  else
    printf '\n%s Personal overrides from omarchy-dotfiles\n%s\n' "$comment" "$line" >> "$file"
    echo "Added overrides to $file"
  fi
}

# Bash: load personal aliases after Omarchy's
add_line "$HOME/.bashrc" '[[ -r ~/.config/bash/aliases ]] && source ~/.config/bash/aliases'

# Hyprland: load personal overrides last (Lua comments use --)
HYPR_LINE='if io.open(os.getenv("HOME") .. "/.config/hypr/overrides.lua") then require("hypr.overrides") end'
add_line "$HOME/.config/hypr/hyprland.lua" "$HYPR_LINE" '--'

# Apply the Hyprland changes right away (does nothing if Hyprland isn't running)
hyprctl reload >/dev/null 2>&1 || true

# XCompose: Windows-style dead keys (I'm, not Iḿ), loaded after Omarchy's rules
add_line "$HOME/.XCompose" 'include "%H/.config/xcompose/dead-keys"'
omarchy restart xcompose >/dev/null 2>&1 || true

# tmux: load personal overrides at the end of Omarchy's tmux.conf
add_line "$HOME/.config/tmux/tmux.conf" 'source-file -q ~/.config/tmux/overrides.conf'
tmux source-file ~/.config/tmux/tmux.conf >/dev/null 2>&1 || true
