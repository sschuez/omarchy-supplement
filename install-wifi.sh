#!/bin/bash

# Wi-Fi networks from 1Password, with wifi-sync from omarchy-dotfiles' wifi
# package:
#
# 1. Now: add every network in the Wi-Fi vault of my personal account that
#    this machine doesn't know yet.
# 2. From now on: wifi-sync.service saves a network to that vault when this
#    machine joins a new one, and says so in a notification.
#
# Both need the 1Password app signed in, with Settings > Developer > "Integrate
# with 1Password CLI" turned on. On a new machine that usually isn't done yet:
# this step then says so and the rest of the setup goes on. Run `wifi-sync`
# afterwards.
set -e

# First, before the service: two syncs at once would add each network twice.
"$HOME/.local/bin/wifi-sync" pull ||
  echo "Could not fetch the Wi-Fi networks: once the 1Password app is signed in, run 'wifi-sync'" >&2

systemctl --user daemon-reload
systemctl --user enable --now wifi-sync.service ||
  echo "Could not start wifi-sync.service; see: journalctl --user -u wifi-sync -e" >&2
