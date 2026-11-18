#!/bin/bash

# 1Password CLI (op): secrets such as Rails master keys come from 1Password
# instead of being copied between machines. Omarchy packages it; --needed
# makes this a no-op when it's already installed.
omarchy pkg add 1password-cli
