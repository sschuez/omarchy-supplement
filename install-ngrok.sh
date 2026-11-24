#!/bin/bash

# ngrok: a public URL for a local port, e.g. `ngrok http 3001` to show a
# development server to someone or to receive webhooks.
#
# From the AUR, so system updates keep it current. When the AUR is out of
# reach, ngrok's own release goes to ~/.local/bin instead (`ngrok update`
# updates that one). Already installed either way: nothing to do.
#
# Nothing else in the setup needs it, so a failure says so and the rest of the
# setup goes on. Run this again afterwards.

command -v ngrok >/dev/null && exit 0

yay -S --noconfirm --needed ngrok && exit 0

echo "The AUR is out of reach; installing ngrok's own release to ~/.local/bin" >&2
case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  *) echo "No ngrok release for $(uname -m)" >&2; exit 0 ;;
esac

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if curl -fsSL "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-$ARCH.tgz" |
  tar -xz -C "$TMP" ngrok; then
  install -Dm755 "$TMP/ngrok" ~/.local/bin/ngrok
else
  echo "Could not install ngrok; run $(realpath "$0") again" >&2
fi

exit 0
