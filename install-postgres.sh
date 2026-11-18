#!/bin/bash

# Postgres for development, the Omarchy way: Omarchy's own installer runs
# postgres:18 in a Docker container on 127.0.0.1:5432 (user postgres, no
# password needed). Apps run on the host and reach it on localhost; each
# worktree gets its own databases on it (see wt in omarchy-dotfiles).
set -e

# Omarchy starts Docker on first use rather than at boot. Start it at boot, so
# the container (restart unless-stopped) is back after every reboot.
sudo systemctl enable --now docker.service

if sudo docker container inspect postgres18 >/dev/null 2>&1; then
  echo "Postgres container already exists"
  sudo docker start postgres18 >/dev/null
else
  omarchy-install-docker-dbs PostgreSQL
fi
