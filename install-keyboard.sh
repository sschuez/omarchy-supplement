#!/bin/bash

# Make fcitx5 use US International too (" then a = ä).
# Hyprland reads the layout from ~/.config/omarchy/keyboard-layouts (stowed from
# omarchy-dotfiles), but fcitx5 re-sends every keystroke with its own layout,
# so it must match. `omarchy setup keyboard` would do both, but its list has
# no US International. Setting the same value again is harmless (idempotent).

FCITX=(busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1)

if ! "${FCITX[@]}" InputMethodGroupInfo s Default >/dev/null 2>&1; then
  echo "fcitx5 isn't running (not logged into Hyprland?). Skipping; re-run later." >&2
  exit 0
fi

# Group "Default": layout us-intl, with one input method, keyboard-us-intl
"${FCITX[@]}" SetInputMethodGroupInfo 'ssa(ss)' Default us-intl 1 keyboard-us-intl ""
"${FCITX[@]}" Save
echo "fcitx5 set to US International"
