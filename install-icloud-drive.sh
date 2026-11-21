#!/bin/bash

# iCloud Drive as a folder: rclone mounts it at ~/iCloudDrive at every login
# (the unit comes with omarchy-dotfiles' rclone package). Files are fetched
# when they're opened, so nothing takes up disk space up front.
#
# The first run on a machine signs in to Apple, in this terminal: the Apple ID
# and its password come from 1Password, then rclone asks for the code the
# iPhone shows. What Apple hands back, a session, stays in
# ~/.config/rclone/rclone.conf (the remote "icloud"), never in a repo. The
# password is not kept there or anywhere else on this machine: rclone gets it
# for the sign-in only. The 1Password item is "idmsa.apple.com
# (stephens@hey.com)", a Login in my personal account; ICLOUD_OP_ACCOUNT and
# ICLOUD_OP_ITEM choose another account or item.
#
# Two settings on the Apple account have to allow all this, or Apple refuses:
# Advanced Data Protection off, and "Access iCloud Data on the Web" on
# (iPhone: Settings > your name > iCloud).
#
# Apple's sign-in lasts 30 days. Once it has run out, a notification says so
# and runs this again when clicked: 1Password and a new code, and it remounts.
#
# That needs the 1Password app signed in, with Settings > Developer >
# "Integrate with 1Password CLI" turned on, and a terminal to type the code
# into. Without either, this step says so and the rest of the setup goes on.
# Run it again afterwards.
set -e

REMOTE=icloud
UNIT=rclone-icloud.service
TIMER=rclone-icloud-check.timer    # asks every hour whether Apple still takes the sign-in
CHECK="$HOME/.local/bin/icloud-signin-check"
OP_ACCOUNT=${ICLOUD_OP_ACCOUNT:-my.1password.eu}
OP_ITEM=${ICLOUD_OP_ITEM:-idmsa.apple.com (stephens@hey.com)}
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

  item=$(op item get "$OP_ITEM" --account "$OP_ACCOUNT" --format json </dev/null) ||
    skip "can't read \"$OP_ITEM\" from 1Password ($OP_ACCOUNT). Once the 1Password app is signed in, run $SELF"
  field() { # the value of the item's username or password: field USERNAME
    jq -r --arg purpose "$1" '[.fields[]? | select(.purpose == $purpose) | .value // ""] | first // ""' <<<"$item"
  }
  apple_id=$(field USERNAME)
  password=$(field PASSWORD)
  unset item
  if [ -z "$apple_id" ] || [ -z "$password" ]; then
    skip "\"$OP_ITEM\" in 1Password has no username or no password"
  fi

  if [ "$sign_in" = again ]; then
    echo "The Apple sign-in has run out. Signing in again as $(remote_value "$REMOTE" apple_id)."
  else
    # The remote is written into rclone.conf here, and rclone only does the
    # sign-in, with `config reconnect` below. `rclone config create` can't
    # sign in: it answers the question for the iPhone's code itself, with
    # nothing, and stops with 'unknown state "authenticate"' (rclone 1.75).
    # No password in it: rclone's own setup would save one, obscured but not
    # encrypted, so whoever can read the file could get it back.
    conf=$(rclone config file | tail -1)
    if grep -q '^RCLONE_ENCRYPT_V0:' "$conf" 2>/dev/null; then
      skip "$conf is encrypted; add the remote \"$REMOTE\" (iclouddrive) with: rclone config"
    fi
    rclone config delete "$REMOTE" >/dev/null 2>&1 || true
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    chmod 600 "$conf"
    # A last line without its newline would otherwise be joined with this one.
    [ -z "$(tail -c1 "$conf")" ] || echo >>"$conf"
    printf '\n[%s]\ntype = iclouddrive\nservice = drive\napple_id = %s\n' \
      "$REMOTE" "$apple_id" >>"$conf"
    echo "Signing in to iCloud as $apple_id."
  fi

  # rclone gets the password for this sign-in only, in its environment, which
  # only my own processes can read (its arguments are open to all). It wants
  # it obscured, and stdin is how it gets that way without being an argument.
  # A mount runs on the session Apple hands back, without the password.
  echo "Type the code your iPhone shows when rclone asks for it. Not now? Press Ctrl+C."
  RCLONE_ICLOUDDRIVE_PASSWORD=$(printf '%s' "$password" | rclone obscure -) \
    rclone config reconnect "$REMOTE:" || give_up
  unset password
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
