#!/usr/bin/env bash
# Usage: open-at-cwd.sh <finder|vscode>
# Opens the requested app at the CWD of the focused terminal window.
# Resolves CWD via lsof on a shell descendant of the terminal app.
# Falls back to $HOME if nothing can be resolved.
set -u

action="${1:-finder}"
fallback="$HOME"
target=""

app_pid=$(aerospace list-windows --focused --format '%{app-pid}' 2>/dev/null || true)
app_name=$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null || true)

is_terminal() {
  case "$1" in
    Ghostty|kitty|Kitty|Terminal|iTerm2|iTerm|Alacritty|WezTerm|Warp|Hyper) return 0 ;;
    *) return 1 ;;
  esac
}

collect_descendants() {
  local pid=$1
  local children
  children=$(pgrep -P "$pid" 2>/dev/null || true)
  for c in $children; do
    echo "$c"
    collect_descendants "$c"
  done
}

if [ -n "$app_pid" ] && is_terminal "$app_name"; then
  descendants=$(collect_descendants "$app_pid")

  # Find a shell descendant of the terminal app and read its working directory
  # via lsof. Warp's native panes keep each shell as a descendant of the app,
  # so walking the process tree reaches the focused shell directly.
  while read -r d; do
    [ -z "$d" ] && continue
    name=$(ps -o comm= -p "$d" 2>/dev/null | awk -F/ '{print $NF}')
    case "$name" in
      fish|zsh|bash|sh|nu|dash|ksh)
        cwd=$(lsof -a -p "$d" -d cwd -Fn 2>/dev/null \
              | awk '/^n/{print substr($0,2); exit}')
        if [ -n "$cwd" ] && [ -d "$cwd" ]; then
          target="$cwd"
          break
        fi
        ;;
    esac
  done <<< "$descendants"
fi

[ -z "$target" ] && target="$fallback"

case "$action" in
  finder) open "$target" ;;
  vscode) open -a "Visual Studio Code" "$target" ;;
  *) echo "open-at-cwd.sh: unknown action '$action'" >&2; exit 2 ;;
esac
