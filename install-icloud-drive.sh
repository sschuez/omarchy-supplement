#!/bin/bash

# iCloud Drive as a folder: rclone mounts it at ~/iCloudDrive at every login
# (the unit comes with omarchy-dotfiles' rclone package). Files are fetched
# when they're opened, so nothing takes up disk space up front.
#
# The first run on a machine signs in to Apple, in this terminal: Apple ID,
# password, then the code the iPhone shows. The sign-in stays in
# ~/.config/rclone/rclone.conf (the remote "icloud"), never in a repo. That
# includes the Apple ID password, which rclone needs at every start and keeps
# obscured, not encrypted: whoever can read that file can get it back. Two
# settings on the Apple account have to allow all this, or Apple refuses:
# Advanced Data Protection off, and "Access iCloud Data on the Web" on
# (iPhone: Settings > your name > iCloud).
#
# Apple's sign-in lasts 30 days. Once it has run out, a notification says so
# and runs this again when clicked: it asks for a new code only, and remounts.
#
# Without a terminal to type into, this step says so and the rest of the
# setup goes on. Run it again afterwards.
set -e

REMOTE=icloud
UNIT=rclone-icloud.service
TIMER=rclone-icloud-check.timer    # asks every hour whether Apple still takes the sign-in
CHECK="$HOME/.local/bin/icloud-signin-check"
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

if [ ! -e "$HOME/.config/systemd/user/$UNIT" ] || [ ! -x "$CHECK" ]; then
  skip "missing $UNIT or $CHECK; run install-dotfiles.sh, then $SELF"
fi

# Does Apple refuse the saved sign-in? The mount's unit asks the same script.
# Offline, it can't tell and says no: the mount is tried.
signed_out() {
  ! "$CHECK" -q >/dev/null
}

# A remote with a trust token has been signed in once. Without one there is no
# remote yet, or the leftover of a sign-in that was cut short: made from
# scratch. With one that Apple no longer takes, only the sign-in is done again.
if [ -z "$(remote_value "$REMOTE" trust_token)" ]; then
  sign_in=new
elif signed_out; then
  sign_in=again
else
  sign_in=""
  echo "Already set up: rclone remote $REMOTE"
fi

remounts=""
if [ -n "$sign_in" ]; then
  [ -t 0 ] || skip "the Apple sign-in needs a terminal. Run $SELF in one"

  # A first sign-in that is given up or fails leaves no half-made remote
  # behind. One that had worked before is kept: a mount may be running on it.
  # Ctrl+C only skips this step: exiting normally lets install-all.sh go on.
  give_up() {
    echo
    [ -n "$(remote_value "$REMOTE" trust_token)" ] ||
      rclone config delete "$REMOTE" >/dev/null 2>&1 || true
    skip "no Apple sign-in. Run $SELF to try again"
  }
  trap give_up INT

  if [ "$sign_in" = again ]; then
    echo "The Apple sign-in has run out. Signing in again as $(remote_value "$REMOTE" apple_id)."
    echo "Not now? Press Ctrl+C and run this script again later."
  else
    echo "Sign in to iCloud. Not now? Press Ctrl+C and run this script again later."
    read -rp "Apple ID (email): " apple_id || give_up
    read -rsp "Apple ID password: " password || give_up
    echo
    [ -n "$apple_id" ] && [ -n "$password" ] || give_up

    # The remote is written into rclone.conf here, and rclone only does the
    # sign-in, with `config reconnect` below. `rclone config create` can't
    # sign in: it answers the question for the iPhone's code itself, with
    # nothing, and stops with 'unknown state "authenticate"' (rclone 1.75).
    # Writing it here also keeps the password out of rclone's arguments, where
    # other processes could read it. It goes in obscured, as rclone keeps it,
    # turned into that form through stdin.
    conf=$(rclone config file | tail -1)
    if grep -q '^RCLONE_ENCRYPT_V0:' "$conf" 2>/dev/null; then
      skip "$conf is encrypted; add the remote \"$REMOTE\" (iclouddrive) with: rclone config"
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
  fi

  echo "Next, type the code your iPhone shows when rclone asks for it."
  rclone config reconnect "$REMOTE:" || give_up
  trap - INT
  [ -n "$(remote_value "$REMOTE" trust_token)" ] || give_up
  remounts=yes
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

# Mount it now and at every login, again after a new sign-in: a running mount
# keeps using the old one. With Type=notify this waits until the folder is
# really mounted, so a failure shows here. A unit skipped for want of a
# sign-in counts as started for systemctl, hence the second look.
systemctl --user daemon-reload
if systemctl --user enable "$UNIT" && systemctl --user enable --now "$TIMER" &&
  systemctl --user "${remounts:+re}start" "$UNIT" &&
  systemctl --user --quiet is-active "$UNIT"; then
  echo "iCloud Drive is at ~/iCloudDrive"
else
  echo "Could not mount iCloud Drive; see: journalctl --user -u ${UNIT%.service} -e" >&2
fi
