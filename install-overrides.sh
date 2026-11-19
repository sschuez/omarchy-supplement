#!/bin/bash

# Hook omarchy-dotfiles into Omarchy and Claude Code, without owning their files:
# - one include line per Omarchy config file (bash, Hyprland, XCompose, tmux),
#   added only if it isn't there yet
# - the cloned workspaces widget switched on in Omarchy's bar, my Window
#   Overview plugin installed from its own repo, and the AirPods plugin with
#   its daemon
# - my Herdr plugins (Ctrl+h/j/k/l navigation, tab names) registered with Herdr
# - Claude Code hooks merged into ~/.claude/settings.json, and its fullscreen
#   renderer switched off
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

# AirPods in the bar (battery per pod and case, listening modes):
# thisisgm/omarchy-pods from the plugin marketplace. The plugin only draws the
# panel; its `setup` installs build packages (asks for sudo), builds the
# librepods daemon into ~/.local and enables librepods.service. setup runs only
# while the daemon is missing; update with `omarchy plugin update`, then run
# setup again by hand. Failures here don't stop the rest of this script.
AIRPODS="io.github.thisisgm.omapods"
AIRPODS_DIR="$HOME/.config/omarchy/plugins/$AIRPODS"
if [ -e "$AIRPODS_DIR" ]; then
  omarchy plugin enable "$AIRPODS" >/dev/null 2>&1 || true
  echo "Already set up: $AIRPODS"
else
  omarchy plugin add https://github.com/thisisgm/omarchy-pods --enable --yes ||
    echo "Could not install $AIRPODS; run this script again" >&2
fi
if [ -x "$AIRPODS_DIR/setup" ] && [ ! -x "$HOME/.local/bin/librepods" ]; then
  "$AIRPODS_DIR/setup" ||
    echo "Could not build the AirPods daemon; run $AIRPODS_DIR/setup" >&2
fi

# Herdr: my two plugins. Their files come with the herdr dotfiles package, but
# Herdr only runs a plugin once it's linked. Linking works without Herdr
# running and is safe to repeat (it also repairs a link to a folder that has
# moved). Failures here don't stop the rest of this script.
#   navigate-plugin  Ctrl+h/j/k/l across panes and Neovim splits, like tmux.
#                    The keys are in Herdr's config.toml; unlinked, they do
#                    nothing.
#   tabs-plugin      Tab names like tmux's automatic-rename: "2 nvim". Its
#                    shell hook is at the end of ~/.config/bash/aliases; open
#                    a new terminal for it.
if ! command -v herdr >/dev/null 2>&1; then
  echo "Herdr isn't installed; skipping its plugins"
else
  # Tab names used to come from the community plugin herdr-automatic-rename:
  # 5,000 lines of shell that took about 100 ms a run, on every focus change.
  # Where it's still installed, remove it, hand its "[2] name" tabs over to
  # tabs-plugin (a bare number is a tab it may name) and clear what it left.
  HERDR_OLD_RENAME="herdr-automatic-rename"
  if herdr plugin list --json 2>/dev/null |
    jq -e --arg id "$HERDR_OLD_RENAME" '.result.plugins[]? | select(.plugin_id == $id)' >/dev/null 2>&1; then
    if herdr plugin uninstall "$HERDR_OLD_RENAME" >/dev/null 2>&1; then
      echo "Removed: Herdr plugin $HERDR_OLD_RENAME"
    else
      echo "Could not remove the Herdr plugin $HERDR_OLD_RENAME; run: herdr plugin uninstall $HERDR_OLD_RENAME" >&2
    fi
    herdr workspace list 2>/dev/null | jq -r '.result.workspaces[]?.workspace_id' 2>/dev/null |
      while IFS= read -r workspace; do
        herdr tab list --workspace "$workspace" 2>/dev/null |
          jq -r '.result.tabs[]? | select(.label | test("^\\[[0-9]+\\] ")) | .tab_id' 2>/dev/null
      done | while IFS= read -r tab; do
        herdr tab rename "$tab" 1 >/dev/null 2>&1 || true
      done
  fi
  # Its settings were a dotfiles link; Stow leaves the link behind once the
  # file is gone from the package.
  if [ -L "$HOME/.config/$HERDR_OLD_RENAME" ] && [ ! -e "$HOME/.config/$HERDR_OLD_RENAME" ]; then
    rm "$HOME/.config/$HERDR_OLD_RENAME"
  fi
  rm -rf "$HOME/.local/state/$HERDR_OLD_RENAME"

  for herdr_plugin in navigate tabs; do
    herdr_id="stephen.$herdr_plugin"
    herdr_dir="$HOME/.config/herdr/$herdr_plugin-plugin"
    if [ ! -f "$herdr_dir/herdr-plugin.toml" ]; then
      echo "Missing $herdr_dir; run install-dotfiles.sh, then this script again" >&2
    elif herdr_output=$(herdr plugin link "$herdr_dir" 2>&1) &&
      herdr_output=$(herdr plugin list 2>&1) &&
      grep -qF -- "- $herdr_id " <<<"$herdr_output"; then
      herdr plugin enable "$herdr_id" >/dev/null 2>&1 || true
      echo "Linked: Herdr plugin $herdr_id"
    else
      echo "Could not link the Herdr plugin $herdr_id; run this script again. Herdr said:" >&2
      echo "$herdr_output" >&2
    fi
  done

  # Name the tabs that are open now; later ones follow Herdr's events. Does
  # nothing when Herdr isn't running.
  "$HOME/.config/herdr/tabs-plugin/tabname" all >/dev/null 2>&1 || true
fi

# Claude Code hooks. Claude Code writes settings.json itself, so merge them in
# rather than own the file:
# - WorktreeCreate/WorktreeRemove go through `wt` (omarchy-dotfiles), so
#   `claude --worktree <name>` gets its own ports and databases, and full cleanup
# - PreToolUse safety hooks (~/.claude/hooks, claude package): no bare bin/ci on
#   protected branches, no destructive database commands. Other PreToolUse
#   hooks are kept.
# - No "tui": "fullscreen": it draws on the alternate screen, so Herdr/tmux copy
#   mode (prefix [) can't scroll back through a session. /tui or Claude Code's
#   fullscreen prompt can switch it back on; re-running this script undoes that.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
[ -f "$CLAUDE_SETTINGS" ] || echo '{}' >"$CLAUDE_SETTINGS"
tmp=$(mktemp)
jq 'del(.tui)
  | .hooks.WorktreeCreate = [{"hooks": [{"type": "command", "command": "$HOME/.local/bin/wt hook create"}]}]
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
  cat "$tmp" >"$CLAUDE_SETTINGS"; rm "$tmp"; echo "Updated Claude Code settings in $CLAUDE_SETTINGS"
fi
