#!/usr/bin/env bash
# Usage: open-at-cwd.sh <finder|vscode>
# Opens the requested app at the CWD of the focused terminal window.
# Resolves CWD via tmux (if the terminal runs tmux) or via lsof on a shell
# descendant. Falls back to $HOME if nothing can be resolved.
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

  # 1) Prefer tmux: shells live under the tmux server (daemon), not under the
  # terminal app, so walking descendants would miss them. Match the tmux
  # client process (descendant of the terminal) to its session and ask tmux
  # for the focused pane's CWD.
  if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
    while read -r d; do
      [ -z "$d" ] && continue
      name=$(ps -o comm= -p "$d" 2>/dev/null | awk -F/ '{print $NF}')
      if [ "$name" = "tmux" ]; then
        sess=$(tmux list-clients -F '#{client_pid} #{client_session}' 2>/dev/null \
               | awk -v p="$d" '$1==p{print $2; exit}')
        if [ -n "$sess" ]; then
          path=$(tmux display-message -t "$sess:" -p '#{pane_current_path}' 2>/dev/null)
          if [ -n "$path" ] && [ -d "$path" ]; then
            target="$path"
            break
          fi
        fi
      fi
    done <<< "$descendants"
  fi

  # 2) Fallback: any shell descendant of the terminal app.
  if [ -z "$target" ]; then
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
fi

[ -z "$target" ] && target="$fallback"

case "$action" in
  finder) open "$target" ;;
  vscode) open -a "Visual Studio Code" "$target" ;;
  *) echo "open-at-cwd.sh: unknown action '$action'" >&2; exit 2 ;;
esac
