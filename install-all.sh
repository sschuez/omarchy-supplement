#!/bin/bash

# Set up everything on a fresh Omarchy install.
# Every script is idempotent, so running this agian is alwasy safe

set -e                # stop at the first error
cd "$(dirname "$0")"  # run from this repo's folder, wherever we're called from

# Programs (order matters: Stow must exist before the dotfiles step)
bash ./install-stow.sh
