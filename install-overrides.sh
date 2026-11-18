#!/bin/bash

# Hook omarchy-dotfiles into Omarchy and Claude Code, without owning their files:
# - one include line per Omarchy config file (bash, Hyprland, XCompose, tmux),
#   added only if it isn't there yet
# - the cloned workspaces widget switched on in Omarchy's bar, and my Window
#   Overview plugin installed from its own repo
# - Claude Code hooks merged into ~/.claude/settings.json
# Safe to re-run.
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

# Omarchy bar: use my copy of the workspaces widget (shows all ten workspaces).
# It replaces the built-in omarchy.workspaces; needs the shell running.
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable stephen.workspaces >/dev/null 2>&1 || true

# Window Overview and its Alt+Tab switcher (keys are in the Hyprland overrides):
# my own plugin, fetched from its own repo. A copy that is already there,
# installed or linked for development, is left alone and only switched on.
# A failure here (offline, shell not running) doesn't stop the rest of this
# script; run it again later.
WINDOW_OVERVIEW="io.github.sschuez.window-overview"
if [ -e "$HOME/.config/omarchy/plugins/$WINDOW_OVERVIEW" ]; then
  omarchy plugin enable "$WINDOW_OVERVIEW" >/dev/null 2>&1 || true
  echo "Already set up: $WINDOW_OVERVIEW"
else
  omarchy plugin add https://github.com/sschuez/omarchy-window-overview --enable --yes ||
    echo "Could not install $WINDOW_OVERVIEW; run this script again" >&2
fi

# Claude Code hooks. Claude Code writes settings.json itself, so merge them in
# rather than own the file:
# - WorktreeCreate/WorktreeRemove go through `wt` (omarchy-dotfiles), so
#   `claude --worktree <name>` gets its own ports and databases, and full cleanup
# - PreToolUse safety hooks (~/.claude/hooks, claude package): no bare bin/ci on
#   protected branches, no destructive database commands. Other PreToolUse
#   hooks are kept.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
[ -f "$CLAUDE_SETTINGS" ] || echo '{}' >"$CLAUDE_SETTINGS"
tmp=$(mktemp)
jq '.hooks.WorktreeCreate = [{"hooks": [{"type": "command", "command": "$HOME/.local/bin/wt hook create"}]}]
  | .hooks.WorktreeRemove = [{"hooks": [{"type": "command", "command": "$HOME/.local/bin/wt hook remove"}]}]
  | .hooks.PreToolUse = ((.hooks.PreToolUse // [])
      | map(select([.hooks[]?.command] | any(test("/\\.claude/hooks/block-")) | not)))
    + [{"matcher": "Bash", "hooks": [
        {"type": "command", "command": "$HOME/.claude/hooks/block-bin-ci-on-protected.sh"},
        {"type": "command", "command": "$HOME/.claude/hooks/block-destructive-db.sh"}]}]' \
  "$CLAUDE_SETTINGS" >"$tmp"
if cmp -s "$tmp" "$CLAUDE_SETTINGS"; then
  echo "Already set up: $CLAUDE_SETTINGS"; rm "$tmp"
else
  cat "$tmp" >"$CLAUDE_SETTINGS"; rm "$tmp"; echo "Updated Claude Code hooks in $CLAUDE_SETTINGS"
fi
