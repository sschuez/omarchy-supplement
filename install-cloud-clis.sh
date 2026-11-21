#!/bin/bash

# The command lines of the clouds my projects run on. They're used through
# `infomaniak` and `exoscale` from omarchy-dotfiles' clouds package, which
# hand them their keys from 1Password (see README, "Clouds"):
#
# - openstack and aws: Infomaniak's Public Cloud (chalet), the project and
#   its buckets.
# - exo: Exoscale (submissio). Not packaged for Arch, so mise installs
#   Exoscale's own release from GitHub; `mise up` updates it.
#
# Nothing else in the setup needs them, so a step that fails (a mirror or
# GitHub out of reach) says so and the rest of the setup goes on. Run this
# again afterwards.

SELF=$(realpath "$0")

yay -S --noconfirm --needed python-openstackclient aws-cli-v2 ||
  echo "Could not install openstack and aws; run $SELF again" >&2

mise use --global github:exoscale/cli@latest ||
  echo "Could not install exo; run $SELF again" >&2

exit 0
