# TomyQB.dots

Personal development environment for macOS. One command installs the shell stack
(fish + starship + atuin), the terminal (Warp), the tiling window manager
(AeroSpace) with custom keybindings, and everything in between.

## Install on a new Mac

```bash
brew install TomyQB/tap/tomyqb-dots
tomyqb-dots install
```

That's it. The installer:

1. `brew bundle`s every package in `Brewfile`
2. Backs up any existing configs to `~/.tomyqb-backup-<timestamp>/`
3. Drops the dotfiles in place
4. Bootstraps fisher (fish plugins) and tpm (tmux plugins)
5. Sets fish as the default shell
6. Starts `borders` and AeroSpace as background services

It's idempotent — re-run it any time.

## What's included

| Tool       | Purpose                          | Config location                       |
|------------|----------------------------------|---------------------------------------|
| fish       | Shell                            | `~/.config/fish/config.fish`          |
| starship   | Prompt (Gentleman palette)       | `~/.config/starship.toml`             |
| atuin      | Shell history                    | (initialised on first run)            |
| carapace   | Completions bridge               | (autoinit from fish config)           |
| tmux       | Terminal multiplexer + kanagawa  | `~/.tmux.conf`                        |
| Warp       | Terminal emulator                | `~/.warp/`                            |
| AeroSpace  | Tiling window manager            | `~/.config/aerospace/aerospace.toml`  |
| borders    | Focused-window outline           | `~/.config/borders/bordersrc`         |
| lazygit    | Git TUI                          | —                                     |
| lazydocker | Docker TUI                       | —                                     |
| mprocs     | Process multiplexer (TUI)        | (per-project, e.g. `mprocs.yaml`)     |

## Keybindings cheat sheet

### AeroSpace (window manager)

| Key                       | Action                                              |
|---------------------------|-----------------------------------------------------|
| `alt + shift + j/l`       | Focus window (left/right)                           |
| `alt + shift + ↓/↑`       | Focus window (down/up)                              |
| `alt + ctrl + ←/↓/↑/→`    | Move window                                         |
| `alt + 1..0`              | Go to workspace 1..10                               |
| `alt + shift + 1..0`      | Move window to workspace 1..10                      |
| `alt + tab`               | Back-and-forth between last two workspaces          |
| `alt + enter`             | Toggle accordion ↔ tiles layout                     |
| `alt + slash`             | Toggle tiles orientation                            |
| `alt + shift + m`         | Fullscreen current window                           |
| `alt + w`                 | Close window (and quit app if it was the last)      |
| `alt + minus` / `alt + =` | Resize                                              |
| `alt + f`                 | Open Finder (floating) at terminal's CWD            |
| `alt + q`                 | Open new Warp window                                |
| `alt + g`                 | Open new Chrome window                              |
| `alt + shift + ;`         | Enter service mode (esc=reload, r=reset, f=float)   |

### Warp (terminal)

Warp ships with native tabs, panes, and AI features — keybindings are managed
inside Warp itself. Personal overrides live in `~/.warp/keybindings.yaml`
(synced from `config/warp/keybindings.yaml`).

| Key                       | Action                                              |
|---------------------------|-----------------------------------------------------|
| `alt + n`                 | New tab                                             |
| `alt + b`                 | Close active tab                                    |
| `alt + i` / `alt + k`     | Previous / next tab                                 |
| `alt + shift + i`         | Move tab up in the left sidebar                     |
| `alt + shift + k`         | Move tab down in the left sidebar                   |
| `alt + u`                 | Toggle left panel / project explorer                |
| `alt + v`                 | Split pane right                                    |
| `alt + h`                 | Split pane down                                     |
| `cmd + w`                 | Close panel / workflow                              |

Note: tmux is intentionally **not** auto-started inside Warp (fish guards on
`$TERM_PROGRAM == WarpTerminal`) — Warp's shell integration and block model
conflict with tmux. The tmux bindings below apply to any non-Warp terminal.

### tmux

Prefix: `ctrl + a` (not `ctrl + b`)

| Key                       | Action                          |
|---------------------------|---------------------------------|
| `prefix + v`              | Split pane right                |
| `prefix + d`              | Split pane down                 |
| `alt + g`                 | Toggle floating scratch session |
| `prefix + K`              | Kill all other sessions         |

## Updating

```bash
brew upgrade tomyqb-dots
tomyqb-dots install
```

Or, if you cloned the repo:

```bash
tomyqb-dots update
```

## Undoing

```bash
tomyqb-dots uninstall
```

Restores the latest backup snapshot to `~/`. Doesn't remove the brew packages
(use `brew bundle cleanup --file=Brewfile --force` for that).

## Repo layout

```
tomyqb-dots/
├── bin/tomyqb-dots          # CLI entry point
├── lib/install.sh           # main installer
├── Brewfile                 # dependencies (used by `brew bundle`)
├── config/                  # source of truth for all dotfiles
│   ├── aerospace/
│   ├── warp/
│   ├── starship/
│   ├── fish/
│   ├── tmux/
│   └── borders/
└── Formula/tomyqb-dots.rb   # local copy; canonical lives in TomyQB/homebrew-tap
```

## License

MIT
