#!/bin/bash

# Brain.fm in the bar: my player for it, a panel under an icon plus a terminal
# player, from its own repo. That repo is private, so cloning it needs GitHub
# to know who you are: on a new machine run `gh auth login` first. Without
# that, this step says so and stops there, and the rest of the setup goes on;
# run this script again afterwards.
#
# A copy that is already there is left as it is (pull it yourself to update).
# Its installer runs either way: it only changes what is out of date, and with
# --no-keybind it asks nothing and leaves the key (Super+B) to omarchy-dotfiles'
# Hyprland overrides. A failure here doesn't stop the rest of the setup.
set -e

REPO_URL="https://github.com/sschuez/brainfm-tui.git"
REPO_DIR="$HOME/Code/brainfm-tui"

# It plays through mpv; mpv-mpris lets the media keys and the bar pause and skip it.
omarchy pkg add mpv mpv-mpris

if [ -d "$REPO_DIR/.git" ]; then
  echo "brainfm-tui already cloned, skipping clone"
elif ! GIT_TERMINAL_PROMPT=0 git clone "$REPO_URL" "$REPO_DIR"; then
  echo "Could not clone brainfm-tui (a private repo): run 'gh auth login', then this script again" >&2
  exit 0
fi

bash "$REPO_DIR/install.sh" --no-keybind </dev/null ||
  echo "Could not install Brain.fm; run this script again" >&2
