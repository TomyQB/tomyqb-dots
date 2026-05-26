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

# --- Prompts ---
# Honors TOMYQB_DOTS_YES=1 for non-interactive runs (CI, scripted setup).
confirm() {
  local prompt="$1"
  if [ "${TOMYQB_DOTS_YES:-0}" = "1" ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    # No TTY available and not auto-confirmed: refuse to guess.
    return 1
  fi
  local reply
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# --- Steps ---

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    return
  fi
  log "Xcode Command Line Tools not found"
  if ! confirm "Install them now? (opens a system dialog and waits until it finishes)"; then
    err "Xcode CLT are required (git, compilers). Aborting."
    exit 1
  fi
  xcode-select --install >/dev/null 2>&1 || true
  log "Waiting for Xcode CLT installation to finish..."
  # The GUI installer runs out-of-band; poll until xcode-select -p succeeds.
  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
  done
  ok "Xcode Command Line Tools installed"
}

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi
  log "Homebrew not found"
  if ! confirm "Install Homebrew now? (runs the official installer from brew.sh)"; then
    err "Homebrew is required. Aborting."
    exit 1
  fi
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Make `brew` resolvable in the current shell session.
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew install completed but \`brew\` is still not on PATH. Aborting."
    exit 1
  fi
  ok "Homebrew installed"
}

install_brew_packages() {
  log "Installing packages from Brewfile..."
  brew bundle --file="$BREWFILE"
  ok "Brew packages installed"
}

install_configs() {
  log "Installing configs (backup -> $BACKUP_DIR)"

  # AeroSpace
  mkdir -p "$HOME/.config/aerospace"
  backup_then_install "$CONFIG_DIR/aerospace/aerospace.toml"           "$HOME/.config/aerospace/aerospace.toml"
  backup_then_install "$CONFIG_DIR/aerospace/open-at-cwd.sh"           "$HOME/.config/aerospace/open-at-cwd.sh"
  backup_then_install "$CONFIG_DIR/aerospace/open-chrome.sh"           "$HOME/.config/aerospace/open-chrome.sh"
  backup_then_install "$CONFIG_DIR/aerospace/focus-workspace-here.sh"  "$HOME/.config/aerospace/focus-workspace-here.sh"
  chmod +x "$HOME/.config/aerospace/"*.sh
  # Remove legacy single-file config so AeroSpace does not see two configs.
  if [ -f "$HOME/.aerospace.toml" ]; then
    rm -f "$HOME/.aerospace.toml"
  fi

  # Warp
  mkdir -p "$HOME/.warp/launch_configurations" "$HOME/.warp/tab_configs"
  backup_then_install "$CONFIG_DIR/warp/settings.toml"     "$HOME/.warp/settings.toml"
  backup_then_install "$CONFIG_DIR/warp/keybindings.yaml"  "$HOME/.warp/keybindings.yaml"
  for f in "$CONFIG_DIR/warp/launch_configurations/"*.yaml; do
    [ -e "$f" ] || continue
    backup_then_install "$f" "$HOME/.warp/launch_configurations/$(basename "$f")"
  done
  for f in "$CONFIG_DIR/warp/tab_configs/"*.toml; do
    [ -e "$f" ] || continue
    backup_then_install "$f" "$HOME/.warp/tab_configs/$(basename "$f")"
  done

  # Starship
  backup_then_install "$CONFIG_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

  # Fish
  mkdir -p "$HOME/.config/fish"
  backup_then_install "$CONFIG_DIR/fish/config.fish"  "$HOME/.config/fish/config.fish"
  backup_then_install "$CONFIG_DIR/fish/fish_plugins" "$HOME/.config/fish/fish_plugins"

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

configure_dock() {
  log "Configuring the macOS Dock to stay hidden..."
  # autohide-delay 5s keeps the Dock out of the way during normal use while
  # still revealing it after a deliberate pause with the cursor at the edge.
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 5
  defaults write com.apple.dock autohide-time-modifier -float 0
  killall Dock >/dev/null 2>&1 || warn "couldn't restart Dock — changes apply on next login"
  ok "Dock set to auto-hide"
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

bootstrap_playwright() {
  log "Bootstrapping Playwright (global @playwright/test + browsers)..."
  if ! command -v npm >/dev/null 2>&1; then
    warn "npm not found — skipping Playwright. Re-run after \`brew install node\`."
    return
  fi
  if ! npm list -g --depth=0 @playwright/test >/dev/null 2>&1; then
    npm install -g @playwright/test >/dev/null 2>&1 || warn "npm install -g @playwright/test failed"
  fi
  if command -v playwright >/dev/null 2>&1; then
    # Installs the browser binaries (chromium, firefox, webkit) Playwright drives.
    playwright install >/dev/null 2>&1 || warn "playwright install (browsers) had issues"
    ok "Playwright ready"
  else
    warn "playwright CLI still not on PATH after npm install"
  fi
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

verify_installation() {
  log "Verifying required tools are available..."
  # CLI binaries we expect on PATH after `brew bundle`.
  local cli_tools=(fish starship atuin gh jq lazygit lazydocker fzf zoxide borders aerospace aws node npm)
  local missing=()
  local tool
  for tool in "${cli_tools[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  # GUI casks live under /Applications and won't show on PATH.
  local apps=(
    "Warp:/Applications/Warp.app"
    "Maccy:/Applications/Maccy.app"
    "Google Chrome:/Applications/Google Chrome.app"
    "Visual Studio Code:/Applications/Visual Studio Code.app"
  )
  local entry name path
  for entry in "${apps[@]}"; do
    name="${entry%%:*}"
    path="${entry#*:}"
    [ -d "$path" ] || missing+=("$name")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    warn "Missing after brew bundle: ${missing[*]}"
    warn "Re-run \`brew bundle --file=$BREWFILE\` or install them manually."
    return 1
  fi
  ok "All required tools present"
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
  3. Log out and back in (or reboot) so fish becomes your active shell.
     A new terminal/tab is NOT enough: macOS keeps the old \$SHELL until you
     re-login, so Warp would keep launching zsh and tools like 'z' (zoxide)
     would be missing.
     Tip: in Warp, set Settings → Startup shell to /opt/homebrew/bin/fish;
     it syncs across your machines.

Backups (if any): $BACKUP_DIR
EOF
}

# --- Entry point ---

main() {
  ensure_xcode_clt
  ensure_brew
  install_brew_packages
  verify_installation || warn "Continuing despite missing tools — fix and re-run if needed."
  install_configs
  configure_dock
  bootstrap_fish_plugins
  bootstrap_playwright
  set_fish_default_shell
  start_services
  print_done
}

main "$@"
