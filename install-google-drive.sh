#!/bin/bash

# Google Drive as a folder: rclone mounts it at ~/GoogleDrive at every login
# (the unit comes with omarchy-dotfiles' rclone package). Files are fetched
# when they're opened, so nothing takes up disk space up front. Inside are
# "My Drive" and one folder per shared drive. Run this again after joining a
# new shared drive: the list is read from Google on every run.
#
# The first run on a machine signs in to Google: a browser window opens, and
# the token it returns stays in ~/.config/rclone/rclone.conf, never in a repo.
# rclone needs a Google API client of my own for that (the one shared by all
# rclone users is being retired). Its client ID and secret are in 1Password,
# in an API Credential item in submissio's account, the client ID as its
# username and the secret as its credential (fields named "client id" and
# "client secret" work too). It is named below by its IDs: the account's and
# the item's names are the company's, not this public repo's.
# GDRIVE_OP_ACCOUNT and GDRIVE_OP_ITEM choose another account or item.
#
# That needs the 1Password app signed in, with Settings > Developer >
# "Integrate with 1Password CLI" turned on. Without it, or without the Google
# sign-in, this step says so and the rest of the setup goes on. Run it again
# afterwards.
set -e

REMOTE=gdrive          # the Google sign-in; by itself only My Drive
ALL=gdrive-all         # My Drive and the shared drives together: what gets mounted
UNIT=rclone-gdrive.service
OP_ACCOUNT=${GDRIVE_OP_ACCOUNT:-LYQ2QZB6QBCS3DQDPVKNWJ2OKI}   # submissio's 1Password
OP_ITEM=${GDRIVE_OP_ITEM:-zdf7yhucmf67uphcgeccecwxqy}         # my Google API client for rclone
SELF=$(realpath "$0")

skip() {
  echo "Google Drive is not set up: $1" >&2
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

# Signed in means the remote has a token. A remote without one is what an
# interrupted sign-in can leave behind, and is made again.
if [ -n "$(remote_value "$REMOTE" token)" ]; then
  echo "Already set up: rclone remote $REMOTE"
else
  item=$(op item get "$OP_ITEM" --account "$OP_ACCOUNT" --format json </dev/null) ||
    skip "can't read \"$OP_ITEM\" from 1Password ($OP_ACCOUNT). Once the 1Password app is signed in, run $SELF"
  field() { # the value of the first field with one of these labels
    jq -r --args '[.fields[]? | select((.label // "" | ascii_downcase) as $label | $ARGS.positional | index($label)) | .value // ""]
      | map(select(. != "")) | first // ""' "$@" <<<"$item"
  }
  client_id=$(field "client id" "client_id" "username")
  client_secret=$(field "client secret" "client_secret" "credential" "password")
  if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
    skip "\"$OP_ITEM\" in 1Password has no client ID or no client secret"
  fi

  # A sign-in that is given up or fails leaves no half-made remote behind.
  # Ctrl+C only skips this step: exiting normally lets install-all.sh go on.
  give_up() {
    rclone config delete "$REMOTE" >/dev/null 2>&1 || true
    skip "no Google sign-in. Run $SELF to try again"
  }
  trap give_up INT
  echo "Sign in to Google in the browser window that opens now, and allow rclone."
  echo "Not now? Press Ctrl+C and run this script again later."
  # rclone only takes these as arguments, where other processes on this
  # machine can read them while the sign-in waits. Acceptable for the secret
  # of a desktop app's client, which Google doesn't treat as confidential.
  # rclone then prints the new remote, token and secret included: not on the
  # screen.
  rclone config create "$REMOTE" drive scope=drive \
    client_id="$client_id" client_secret="$client_secret" >/dev/null || give_up
  trap - INT
  [ -n "$(remote_value "$REMOTE" token)" ] || give_up
  echo "Signed in: rclone remote $REMOTE"
fi

# One folder for everything: an rclone "combine" remote with "My Drive" and
# each shared drive side by side. It is written to rclone.conf, not kept in a
# repo, because the shared drives' names and IDs are not for a public one.
# Sorted, so the same drives always give the same remote. A name that is taken
# gets the drive's ID added: two folders with one name would stop the whole
# mount. Without a network the list can't be read (asked once, not retried for
# minutes) and the remote stays as it was.
remounts=""
if drives=$(rclone backend drives "$REMOTE:" --retries 1 --low-level-retries 1); then
  upstreams=$(jq -r --arg remote "$REMOTE" '
    def entry($dir; $from): "\"" + ($dir | gsub("\""; "\"\"")) + "=" + $from + "\"";
    reduce ((. // []) | sort_by(.name, .id))[] as $drive (
      {taken: ["My Drive"], entries: [entry("My Drive"; $remote + ":")]};
      ($drive.name | gsub("[/=]"; "-")) as $name
      | (if .taken | index($name) then "\($name) (\($drive.id))" else $name end) as $dir
      | .taken += [$dir]
      | .entries += [entry($dir; "\($remote),team_drive=\($drive.id),root_folder_id=:")])
    | .entries | join(" ")' <<<"$drives")
  if [ "$(remote_value "$ALL" upstreams)" = "$upstreams" ]; then
    echo "Already set up: rclone remote $ALL"
  else
    rclone config create "$ALL" combine upstreams="$upstreams" >/dev/null
    remounts=yes
    echo "Updated the rclone remote $ALL: My Drive and $(jq '(. // []) | length' <<<"$drives") shared drive(s)"
  fi
elif [ -n "$(remote_value "$ALL" upstreams)" ]; then
  echo "Could not read the list of shared drives; keeping the one from last time" >&2
else
  skip "could not read the list of shared drives. Run $SELF to try again"
fi

# Files (Nautilus): Google Drive in the sidebar. Nautilus rewrites this file
# itself, so add the line rather than own the file.
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"
BOOKMARK="file://$HOME/GoogleDrive Google Drive"
mkdir -p "$(dirname "$BOOKMARKS")"
touch "$BOOKMARKS"
if grep -qxF "$BOOKMARK" "$BOOKMARKS"; then
  echo "Already set up: $BOOKMARKS"
else
  # A last line without its newline would otherwise be joined with this one.
  [ -z "$(tail -c1 "$BOOKMARKS")" ] || echo >>"$BOOKMARKS"
  echo "$BOOKMARK" >>"$BOOKMARKS"
  echo "Added Google Drive to $BOOKMARKS"
fi

# Mount it now and at every login, again if the list of drives changed. With
# Type=notify this waits until the folder is really mounted, so a failure
# shows here.
systemctl --user daemon-reload
if systemctl --user enable "$UNIT" && systemctl --user "${remounts:+re}start" "$UNIT"; then
  echo "Google Drive is at ~/GoogleDrive"
else
  echo "Could not mount Google Drive; see: journalctl --user -u ${UNIT%.service} -e" >&2
fi
