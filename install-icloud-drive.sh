#!/bin/bash

# iCloud Drive as a folder: rclone mounts it at ~/iCloudDrive at every login
# (the unit comes with omarchy-dotfiles' rclone package). Files are fetched
# when they're opened, so nothing takes up disk space up front.
#
# The first run on a machine signs in to Apple, in this terminal: Apple ID,
# password, then the code the iPhone shows. What Apple returns stays in
# ~/.config/rclone/rclone.conf (the remote "icloud"), never in a repo. Two
# settings on the Apple account have to allow it, or Apple refuses the
# sign-in: Advanced Data Protection off, and "Access iCloud Data on the Web"
# on (iPhone: Settings > your name > iCloud).
#
# Apple's sign-in runs out every few weeks. Then run
#   rclone config reconnect icloud: && systemctl --user restart rclone-icloud
#
# Without a terminal to type into, this step says so and the rest of the
# setup goes on. Run it again afterwards.
set -e

REMOTE=icloud
UNIT=rclone-icloud.service
SELF=$(realpath "$0")

skip() {
  echo "iCloud Drive is not set up: $1" >&2
  exit 0
}

# A setting of a remote in rclone.conf, empty if it has none: remote_value <remote> <key>
remote_value() {
  rclone config dump 2>/dev/null | jq -r --arg remote "$1" --arg key "$2" '.[$remote][$key] // ""'
}

# fuse3 does the mounting; rclone only lists it as optional.
omarchy pkg add rclone fuse3

if [ ! -e "$HOME/.config/systemd/user/$UNIT" ]; then
  skip "missing $UNIT; run install-dotfiles.sh, then $SELF"
fi

# Signed in means the remote has a trust token, which Apple hands out once the
# iPhone's code is accepted. A remote without one is what an interrupted
# sign-in leaves behind, and is made again.
if [ -n "$(remote_value "$REMOTE" trust_token)" ]; then
  echo "Already set up: rclone remote $REMOTE"
else
  [ -t 0 ] || skip "the Apple sign-in needs a terminal. Run $SELF in one"

  # A sign-in that is given up or fails leaves no half-made remote behind.
  # Ctrl+C only skips this step: exiting normally lets install-all.sh go on.
  give_up() {
    echo
    rclone config delete "$REMOTE" >/dev/null 2>&1 || true
    skip "no Apple sign-in. Run $SELF to try again"
  }
  trap give_up INT

  echo "Sign in to iCloud. Not now? Press Ctrl+C and run this script again later."
  read -rp "Apple ID (email): " apple_id
  read -rsp "Apple ID password: " password
  echo
  [ -n "$apple_id" ] && [ -n "$password" ] || give_up

  # The remote is written into rclone.conf here, and rclone only does the
  # sign-in, with `config reconnect`. `rclone config create` can't: it sends
  # the code to the iPhone, then stops with 'unknown state "authenticate"'
  # instead of asking for it (rclone 1.75). Writing it here also keeps the
  # password out of rclone's arguments, where other processes could read it.
  # It goes in obscured, as rclone.conf keeps it, turned into that form
  # through stdin.
  conf=$(rclone config file | tail -1)
  if grep -q '^RCLONE_ENCRYPT_V0:' "$conf" 2>/dev/null; then
    skip "$conf is encrypted; add the remote with: rclone config"
  fi
  obscured=$(printf '%s' "$password" | rclone obscure -)
  unset password
  rclone config delete "$REMOTE" >/dev/null 2>&1 || true
  mkdir -p "$(dirname "$conf")"
  touch "$conf"
  chmod 600 "$conf"
  # A last line without its newline would otherwise be joined with this one.
  [ -z "$(tail -c1 "$conf")" ] || echo >>"$conf"
  printf '\n[%s]\ntype = iclouddrive\nservice = drive\napple_id = %s\npassword = %s\n' \
    "$REMOTE" "$apple_id" "$obscured" >>"$conf"
  unset obscured

  echo "Next, type the code your iPhone shows when rclone asks for it."
  rclone config reconnect "$REMOTE:" || give_up
  trap - INT
  [ -n "$(remote_value "$REMOTE" trust_token)" ] || give_up
  echo "Signed in: rclone remote $REMOTE"
fi

# Files (Nautilus): iCloud Drive in the sidebar. Nautilus rewrites this file
# itself, so add the line rather than own the file.
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"
BOOKMARK="file://$HOME/iCloudDrive iCloud Drive"
mkdir -p "$(dirname "$BOOKMARKS")"
touch "$BOOKMARKS"
if grep -qxF "$BOOKMARK" "$BOOKMARKS"; then
  echo "Already set up: $BOOKMARKS"
else
  # A last line without its newline would otherwise be joined with this one.
  [ -z "$(tail -c1 "$BOOKMARKS")" ] || echo >>"$BOOKMARKS"
  echo "$BOOKMARK" >>"$BOOKMARKS"
  echo "Added iCloud Drive to $BOOKMARKS"
fi

# Mount it now and at every login. With Type=notify this waits until the
# folder is really mounted, so a failure shows here.
systemctl --user daemon-reload
if systemctl --user enable "$UNIT" && systemctl --user start "$UNIT"; then
  echo "iCloud Drive is at ~/iCloudDrive"
else
  echo "Could not mount iCloud Drive; see: journalctl --user -u ${UNIT%.service} -e" >&2
fi
