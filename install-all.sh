#!/bin/bash

# Set up everything on a fresh Omarchy install.
# Every script is idempotent, so running this again is always safe.

set -e                # stop at the first error
cd "$(dirname "$0")"  # run from this repo's folder, wherever we're called from

# Programs (order matters: Stow must exist before the dotfiles step)
bash ./install-stow.sh
bash ./install-postgres.sh
bash ./install-1password-cli.sh
bash ./install-cloud-clis.sh
bash ./install-ngrok.sh

# dotfiles and overrides
bash ./install-dotfiles.sh
bash ./install-overrides.sh
bash ./install-keyboard.sh

# Wi-Fi networks from 1Password (after the dotfiles: wifi-sync comes with them)
bash ./install-wifi.sh

# My own tools (after the dotfiles: their keys are in the Hyprland overrides)
bash ./install-brainfm.sh

# Google Drive at ~/GoogleDrive (after the dotfiles: the mount's unit comes with
# them). Last, because its first run waits for a Google sign-in in the browser.
bash ./install-google-drive.sh
# iCloud Drive at ~/iCloudDrive, the same way. Its first run asks for the Apple
# ID, password and a code from the iPhone, in the terminal.
bash ./install-icloud-drive.sh
