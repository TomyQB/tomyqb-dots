#!/usr/bin/env bash
# TomyQB.dots installer
# Backs up existing configs to ~/.tomyqb-backup-<timestamp>/ and writes new ones.
# Idempotent: re-running re-syncs without harm.
set -euo pipefail

# Resolve the repo root from this script's location: lib/install.sh -> repo root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
BREWFILE="$REPO_ROOT/Brewfile"
BACKUP_DIR="$HOME/.tomyqb-backup-$(date +%Y%m%d-%H%M%S)"

# --- Logging helpers ---
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }

# --- Backup + copy ---
# Moves an existing file/dir (non-symlink) to the backup tree before writing.
backup_then_install() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    local rel="${dest#$HOME/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$dest" "$BACKUP_DIR/$rel"
  elif [ -L "$dest" ]; then
    rm -f "$dest"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
}

# --- Steps ---

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew not found. Install it first: https://brew.sh"
    exit 1
  fi
}

install_brew_packages() {
  log "Installing packages from Brewfile..."
  brew bundle --file="$BREWFILE" --no-lock
  ok "Brew packages installed"
}

install_configs() {
  log "Installing configs (backup -> $BACKUP_DIR)"

  # AeroSpace
  backup_then_install "$CONFIG_DIR/aerospace/aerospace.toml" "$HOME/.aerospace.toml"
  mkdir -p "$HOME/.config/aerospace"
  backup_then_install "$CONFIG_DIR/aerospace/open-at-cwd.sh"          "$HOME/.config/aerospace/open-at-cwd.sh"
  backup_then_install "$CONFIG_DIR/aerospace/toggle-lazydocker.sh"    "$HOME/.config/aerospace/toggle-lazydocker.sh"
  chmod +x "$HOME/.config/aerospace/"*.sh

  # Ghostty
  mkdir -p "$HOME/.config/ghostty/shaders"
  backup_then_install "$CONFIG_DIR/ghostty/config" "$HOME/.config/ghostty/config"
  backup_then_install "$CONFIG_DIR/ghostty/shaders/cursor_smear_gentleman.glsl" \
                      "$HOME/.config/ghostty/shaders/cursor_smear_gentleman.glsl"

  # Starship
  backup_then_install "$CONFIG_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

  # Fish
  mkdir -p "$HOME/.config/fish"
  backup_then_install "$CONFIG_DIR/fish/config.fish"  "$HOME/.config/fish/config.fish"
  backup_then_install "$CONFIG_DIR/fish/fish_plugins" "$HOME/.config/fish/fish_plugins"

  # Tmux
  backup_then_install "$CONFIG_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

  # Borders
  mkdir -p "$HOME/.config/borders"
  backup_then_install "$CONFIG_DIR/borders/bordersrc" "$HOME/.config/borders/bordersrc"
  chmod +x "$HOME/.config/borders/bordersrc"

  if [ ! -d "$BACKUP_DIR" ]; then
    ok "Configs installed (nothing to back up — fresh machine)"
  else
    ok "Configs installed (backup at $BACKUP_DIR)"
  fi
}

bootstrap_fish_plugins() {
  log "Bootstrapping fisher + fish plugins..."
  fish -c '
    if not functions -q fisher
      curl -sL https://git.io/fisher | source
      and fisher install jorgebucaran/fisher
    end
    fisher update
  ' || warn "fisher bootstrap had issues (continuing)"
  ok "Fish plugins synced"
}

bootstrap_tmux_plugins() {
  log "Bootstrapping tmux plugin manager (tpm) + plugins..."
  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone --quiet https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || warn "tpm install_plugins had issues"
  ok "tmux plugins installed"
}

set_fish_default_shell() {
  local fish_path
  fish_path="$(command -v fish || true)"
  if [ -z "$fish_path" ]; then
    warn "fish not found in PATH — skipping default shell change"
    return
  fi
  if ! grep -q "^$fish_path$" /etc/shells 2>/dev/null; then
    log "Adding fish to /etc/shells (requires sudo)..."
    echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
  fi
  if [ "$SHELL" != "$fish_path" ]; then
    log "Setting fish as default shell..."
    chsh -s "$fish_path" || warn "chsh failed — run manually: chsh -s $fish_path"
  fi
  ok "Default shell: $fish_path"
}

start_services() {
  log "Starting background services..."
  brew services start felixkratz/formulae/borders >/dev/null 2>&1 || warn "borders service didn't start"
  open -ga AeroSpace 2>/dev/null || warn "couldn't open AeroSpace"
  ok "Services started"
}

print_done() {
  cat <<EOF

$(printf '\033[1;32m')✓ TomyQB.dots installed$(printf '\033[0m')

Next steps:
  1. Grant Accessibility permission to AeroSpace and borders:
       System Settings → Privacy & Security → Accessibility
  2. If 'code' CLI is missing (for \$EDITOR), open VSCode and run:
       Cmd+Shift+P → "Shell Command: Install 'code' command in PATH"
  3. Open a new terminal — fish + starship + atuin will activate.

Backups (if any): $BACKUP_DIR
EOF
}

# --- Entry point ---

main() {
  ensure_brew
  install_brew_packages
  install_configs
  bootstrap_fish_plugins
  bootstrap_tmux_plugins
  set_fish_default_shell
  start_services
  print_done
}

main "$@"
