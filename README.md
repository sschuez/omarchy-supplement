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
4. Ruby versions installed **before** this ran don't have `ruby-lsp` yet
   (Neovim's Ruby language server). Install it once in each:
   `mise exec ruby@<version> -- gem install ruby-lsp`. Rubies mise installs
   later get it automatically (see `~/.default-gems` in omarchy-dotfiles).
5. Optional: to run whole Docker stacks (`dcu`, `dcr`) without `sudo`, enable
   Omarchy's sudoless Docker (Setup > Security > Sudoless Docker, then reboot).
   It makes the `docker` group root-equivalent, which is why Omarchy leaves it
   off. Host development only needs the Postgres container this sets up.
6. Pair the AirPods in a terminal, not from the bar's Bluetooth panel: the
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
| `install-overrides.sh` | Adds one include line to each Omarchy config file that should load my overrides. |
| `install-keyboard.sh` | Sets fcitx5 to US International to match Hyprland. Needs a running desktop session; skips otherwise. |

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
any other `PreToolUse` hooks, and enables the cloned workspaces bar widget.

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

Some apps need no include line, because they load a whole folder by
themselves: LazyVim loads every file in `~/.config/nvim/lua/plugins/`, Neovim
loads `~/.config/nvim/plugin/`, and Omarchy reads
`~/.config/omarchy/keyboard-layouts`.

A few files can't be overlaid, so the dotfiles own them outright. They're
listed in `OWNED_FILES` in `install-dotfiles.sh`, which moves Omarchy's copy
aside (`*.bak.<timestamp>`) before linking. Currently
`~/.config/nvim/lazyvim.json` (LazyVim only accepts extras from there) and
`~/.config/herdr/config.toml` (Herdr can't include other files).

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
