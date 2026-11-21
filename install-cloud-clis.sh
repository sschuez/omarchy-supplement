#!/bin/bash

# The command lines of the clouds my projects run on. They're used through
# `infomaniak` and `exoscale` from omarchy-dotfiles' clouds package, which
# hand them their keys from 1Password (see README, "Clouds"):
#
# - openstack and aws: Infomaniak's Public Cloud (chalet), the project and
#   its buckets.
# - exo: Exoscale (submissio). Not packaged for Arch, so mise installs
#   Exoscale's own release from GitHub; `mise up` updates it.
set -e

yay -S --noconfirm --needed python-openstackclient aws-cli-v2
mise use --global github:exoscale/cli@latest
