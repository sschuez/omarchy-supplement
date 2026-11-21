# omarchy-supplement

My setup on top of a fresh [Omarchy](https://omarchy.org) install: the programs
I want, my dotfiles, and the hooks that load my overrides, all without editing
Omarchy itself, so Omarchy updates keep working.

The config files themselves live in
[omarchy-dotfiles](https://github.com/sschuez/omarchy-dotfiles). This repo
installs and wires them up.

## New machine

1. Install Omarchy. Any keyboard layout is fine: US International is set by
   these scripts, because Omarchy's installer doesn't offer it.
2. Log in to the desktop, open a terminal and run the following. It asks for
   your password once (packages, Docker, the Postgres container) and for
   1Password approval if a step needs it:

   ```sh
   git clone https://github.com/sschuez/omarchy-supplement ~/Code/omarchy-supplement
   ~/Code/omarchy-supplement/install-all.sh
   ```

3. Per project, restore the secrets that aren't in git from 1Password, e.g.
   submissio's Rails key:
   `op read "op://Shared/Rails Master Key (Production)/password" --account submissioag.1password.com > config/master.key`.
   New worktrees copy it from the main checkout automatically.
4. The Wi-Fi networks I know come from 1Password too, and that step is
   skipped until the 1Password app is signed in with Settings > Developer >
   Integrate with 1Password CLI turned on. Then run `wifi-sync`: it adds every
   network in the Wi-Fi vault of my personal account. A network joined later
   is saved to the vault by itself, with a notification.
5. Google Drive (`~/GoogleDrive`) waits for 1Password in the same way, and
   then for a Google sign-in. Run
   `~/Code/omarchy-supplement/install-google-drive.sh` and sign in to Google in
   the browser window it opens (see [Google Drive](#google-drive)).
   iCloud Drive (`~/iCloudDrive`) asks for an Apple sign-in in the terminal
   during `install-all.sh`; skipped, run
   `~/Code/omarchy-supplement/install-icloud-drive.sh` later (see
   [iCloud Drive](#icloud-drive)).
6. Ruby versions installed **before** this ran don't have `ruby-lsp` yet
   (Neovim's Ruby language server). Install it once in each:
   `mise exec ruby@<version> -- gem install ruby-lsp`. Rubies mise installs
   later get it automatically (see `~/.default-gems` in omarchy-dotfiles).
7. Optional: to run whole Docker stacks (`dcu`, `dcr`) without `sudo`, enable
   Omarchy's sudoless Docker (Setup > Security > Sudoless Docker, then reboot).
   It makes the `docker` group root-equivalent, which is why Omarchy leaves it
   off. Host development only needs the Postgres container this sets up.
8. Brain.fm in the bar comes from a private repo, so its step is skipped
   until GitHub knows who you are: run `gh auth login`, then
   `~/Code/omarchy-supplement/install-brainfm.sh`. Sign in to Brain.fm in the
   panel (`Super+B`) afterwards.
9. Pair the AirPods in a terminal, not from the bar's Bluetooth panel: the
   panel picks up one of their rotating Bluetooth LE addresses, which connects
   without audio or AirPods controls. Run `bluetoothctl`, then `scan bredr`,
   put the AirPods in pairing mode (Pro 3: lid open, double-tap the front of
   the case until the light flashes white), and `pair`, `trust` and `connect`
   the entry with a fixed address (the one not named like `6F-9B-…`). The
   AirPods widget appears in the bar once they're connected.

Every script is idempotent: running it again changes nothing that's already
set up. Re-run `install-all.sh` any time, for example after `omarchy refresh`
has reset a config file and dropped an include line.

## Scripts

| Script | Does |
|---|---|
| `install-all.sh` | Runs everything below, in order. Stops at the first error. |
| `install-stow.sh` | Installs GNU Stow. |
| `install-postgres.sh` | PostgreSQL 18 for development, the Omarchy way: `omarchy install docker dbs` runs it in a container on `localhost:5432` (user `postgres`). Also starts Docker at boot, so the database is back after every reboot. Needs `sudo`. |
| `install-1password-cli.sh` | 1Password CLI (`op`), for secrets such as Rails master keys. Omarchy packages it. |
| `install-dotfiles.sh` | Clones omarchy-dotfiles to `~/Code/omarchy-dotfiles` and symlinks its packages into `~` with Stow. |
| `install-overrides.sh` | Adds one include line to each Omarchy config file that should load my overrides, and sets up the plugins and Claude Code hooks described below. |
| `install-keyboard.sh` | Sets fcitx5 to US International to match Hyprland. Needs a running desktop session; skips otherwise. |
| `install-wifi.sh` | Adds the Wi-Fi networks kept in 1Password to this machine, with `wifi-sync pull` from omarchy-dotfiles, and starts `wifi-sync.service`, which saves a newly joined network there. Needs the 1Password app signed in and its CLI integration turned on; says so and goes on otherwise. |
| `install-brainfm.sh` | Brain.fm in the bar: clones my player ([brainfm-tui](https://github.com/sschuez/brainfm-tui), a private repo) to `~/Code/brainfm-tui` and runs its installer, which sets up the `brainfm` command and the bar panel. Installs `mpv-mpris` so the media keys control it. Needs GitHub to know who you are (`gh auth login`); says so and skips otherwise. |
| `install-google-drive.sh` | Google Drive as the folder `~/GoogleDrive`: installs rclone, signs in to Google once per machine (in the browser), mounts the folder (My Drive and the shared drives) now and at every login, and adds it to the Files sidebar. Needs the 1Password app signed in (my Google API client is kept there); says so and skips otherwise. See [Google Drive](#google-drive). |
| `install-icloud-drive.sh` | iCloud Drive as the folder `~/iCloudDrive`, the same way: signs in to Apple once per machine (in the terminal: Apple ID, password, a code from the iPhone), mounts the folder now and at every login, and adds it to the Files sidebar. See [iCloud Drive](#icloud-drive). |

## How the overrides work

There are three layers, and only the last one is mine:

1. **Omarchy's core**, `/usr/share/omarchy/`. Never edited; updated by Omarchy.
2. **Omarchy's copies in `~/.config`**, placed at install time. Kept exactly as
   Omarchy wrote them, plus one include line at the end, so Omarchy's update
   migrations still find what they expect.
3. **My files** from omarchy-dotfiles, symlinked into place by Stow. The
   include lines load them last, so they win over Omarchy's defaults.

The include lines `install-overrides.sh` adds:

| Omarchy file | Line added | Loads |
|---|---|---|
| `~/.bashrc` | `[[ -r ~/.config/bash/aliases ]] && source ~/.config/bash/aliases` | Bash aliases and functions |
| `~/.config/hypr/hyprland.lua` | `if io.open(…) then require("hypr.overrides") end` | Hyprland overrides |
| `~/.XCompose` | `include "%H/.config/xcompose/dead-keys"` | Dead-key rules |
| `~/.config/tmux/tmux.conf` | `source-file -q ~/.config/tmux/overrides.conf` | tmux overrides |

`install-overrides.sh` also merges two hooks into Claude Code's
`~/.claude/settings.json` (Claude Code writes that file itself, so it can't be
owned): `WorktreeCreate` and `WorktreeRemove` call `wt hook create|remove`
(from omarchy-dotfiles), so `claude --worktree <name>` gets its own ports,
Docker project and databases, and removing it at the exit prompt cleans all of
that up. It also adds two `PreToolUse` safety hooks from omarchy-dotfiles (no
bare `bin/ci` on protected branches, no destructive database commands), keeping
any other `PreToolUse` hooks. It removes `"tui": "fullscreen"` there too:
fullscreen mode draws on the alternate screen, so Herdr or tmux copy mode
(`prefix [`) can't scroll back through a Claude Code session. If `/tui` turns
it back on, re-run the script. It also enables the cloned workspaces bar widget.

Last, it installs my [Window Overview](https://github.com/sschuez/omarchy-window-overview)
shell plugin (`Super+E`, `Alt+Tab`) with `omarchy plugin add` and enables it.
The plugin lives in its own repo; its keys are in omarchy-dotfiles' Hyprland
overrides. A copy that is already there is left alone, and a failed download
doesn't stop the script: run it again.

It also installs the [AirPods](https://github.com/thisisgm/omarchy-pods) bar
widget (battery per pod and case, listening modes) from the plugin marketplace,
then runs the plugin's own `setup` if its daemon isn't built yet: that installs
a few build packages (asks for `sudo`), builds `librepods` into `~/.local` and
enables `librepods.service`. The icon only shows while AirPods are connected.
After `omarchy plugin update io.github.thisisgm.omapods`, run
`~/.config/omarchy/plugins/io.github.thisisgm.omapods/setup` again so the
daemon matches.

And it links my two Herdr plugins, whose files come with omarchy-dotfiles'
`herdr` package (Herdr only runs a plugin once it's linked):

- `navigate-plugin`: `Ctrl+h/j/k/l` across panes and Neovim splits, like tmux.
  The keys are in Herdr's config; until the plugin is linked they do nothing.
- `tabs-plugin`: tab names like tmux's automatic-rename (`2 nvim`). Its shell
  hook is at the end of `~/.config/bash/aliases`; open a new terminal for it.

Linking is repeated on every run, which also repairs a link after the dotfiles
folder has moved, and the tabs that are open get their names right away. Where
the community plugin herdr-automatic-rename is still installed (it named the
tabs before `tabs-plugin` did), the script removes it and hands its tabs over.
A failure doesn't stop the script.

Some apps need no include line, because they load a whole folder by
themselves: LazyVim loads every file in `~/.config/nvim/lua/plugins/`, Neovim
loads `~/.config/nvim/plugin/`, and Omarchy reads
`~/.config/omarchy/keyboard-layouts`.

A few files can't be overlaid, so the dotfiles own them outright. They're
listed in `OWNED_FILES` in `install-dotfiles.sh`, which moves Omarchy's copy
aside (`*.bak.<timestamp>`) before linking. Currently
`~/.config/nvim/lazyvim.json` (LazyVim only accepts extras from there) and
`~/.config/herdr/config.toml` (Herdr can't include other files).

Stow links a whole folder when the folder doesn't exist yet, which is wrong for
folders other programs write into. `REAL_DIRS` in `install-dotfiles.sh` lists
the ones created as real folders first, so only my files inside are linked:
`~/.local/bin`, the workspaces widget's folder, `~/.claude/hooks`,
`~/.config/herdr` (Herdr keeps its logs, session and plugin registry there)
and `~/.config/systemd/user` (systemd puts its own links there when a unit is
enabled).

## Google Drive

`install-google-drive.sh` makes Google Drive a folder, `~/GoogleDrive`, with
[rclone](https://rclone.org/drive/). It is mounted, not synced: a file is
fetched when it's opened, and what was opened stays on disk for a while (up to
10 GB, 30 days), so nothing takes up space up front and only those files work
offline. Inside are `My Drive` and one folder per shared drive; after joining
a new shared drive, run the script again. Google Docs, Sheets and Slides show
up as links that open in the browser. The mount is a systemd user service,
`rclone-gdrive`, whose unit comes with omarchy-dotfiles' `rclone` package; the
flags are explained there.

Two things are not in a repo:

- **My Google API client.** rclone talks to Google as an "app", and the one
  shared by all rclone users is being retired, so I have my own. Its client ID
  and secret are in 1Password, in the item `rclone Google Drive` in the Shared
  vault of the submissio account (an API Credential: the client ID as username,
  the secret as credential). The script reads them from there. To make a new
  one, follow rclone's
  [Making your own client_id](https://rclone.org/drive/#making-your-own-client-id):
  a Google Cloud project with the Google Drive API enabled and an OAuth client
  of type "Desktop app". Publish the app (or make it "Internal" in a Google
  Workspace): left in "Testing", the sign-in expires every week.
- **The sign-in.** The script opens a browser window for it once per machine.
  The token stays in `~/.config/rclone/rclone.conf`, as the rclone remote
  `gdrive`. The script writes a second remote there, `gdrive-all`, which puts
  My Drive and the shared drives side by side: that one is mounted.

If something goes wrong:

- `systemctl --user status rclone-gdrive` shows whether it's mounted, and
  `journalctl --user -u rclone-gdrive -f` the live log.
- A folder that looks empty or stuck: `systemctl --user restart rclone-gdrive`.
- Signed in to the wrong account, or the sign-in no longer works:
  `rclone config delete gdrive`, then the script again.
- `systemctl --user disable rclone-gdrive` also removes the unit's link from
  `~/.config/systemd/user`, as systemd does for a unit that is a link. Run
  `install-dotfiles.sh` and this script again to get it back.

## iCloud Drive

`install-icloud-drive.sh` makes iCloud Drive a folder, `~/iCloudDrive`, with
rclone's [iCloud Drive backend](https://rclone.org/iclouddrive/), mounted
like Google Drive (fetched when opened, up to 10 GB kept for 30 days). The
mount is the systemd user service `rclone-icloud`, whose unit comes with
omarchy-dotfiles' `rclone` package. iCloud doesn't report changes made
elsewhere, so a file added on the iPhone shows up within 5 minutes.

- **The Apple account has to allow it:** Advanced Data Protection off, and
  "Access iCloud Data on the Web" on (iPhone: Settings > your name > iCloud).
  Otherwise Apple refuses the sign-in.
- **The sign-in** happens in the terminal, once per machine: Apple ID,
  password, then the code the iPhone shows. It stays in
  `~/.config/rclone/rclone.conf`, as the rclone remote `icloud`.
- **It runs out every few weeks.** The folder then shows errors, and
  `journalctl --user -u rclone-icloud -e` mentions authentication. Run
  `rclone config reconnect icloud:` (password and code again), then
  `systemctl --user restart rclone-icloud`.
- Signed in to the wrong account: `rclone config delete icloud`, then the
  script again.

## Adding things

- **A program:** create `install-<name>.sh` containing
  `yay -S --noconfirm --needed <package>`, make it executable, and add a
  `bash ./install-<name>.sh` line to `install-all.sh`.
- **A config change:** put the file in omarchy-dotfiles (see its README), add
  the package name to `PACKAGES` in `install-dotfiles.sh`, and, if the app
  needs an include line, add an `add_line` call to `install-overrides.sh`:

  ```sh
  add_line "<Omarchy's file>" '<exact line to add>' '<comment marker, default #>'
  ```

## Conventions

For anyone, human or agent, changing these repos:

- Never edit `/usr/share/omarchy/`.
- Overlay rather than replace: leave Omarchy's file as it is and load a
  separate file from it. Own a file outright only when the app offers no
  include mechanism, and add it to `OWNED_FILES`.
- Keep machine-specific settings (monitors, scaling) out. Omarchy writes
  those per machine.
- Every script must be idempotent and safe to re-run. They're bash, run with
  `set -e`.
- `add_line` matches the whole line exactly, so a changed include line gets
  appended again. Update the old line in the Omarchy file by hand first.
- No secrets. Both repos are public.
