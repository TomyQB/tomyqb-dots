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
  # 0) Warp: no expone la tab activa por proceso (todos los shells son
  # hermanos), ni por AppleScript, ni por Accessibility. Pero su estado vive en
  # una SQLite: windows.active_tab_index apunta a la tab activa; cruzándola con
  # las tabs (ordenadas por id) y el terminal_pane de cada una se obtiene el
  # cwd. Se actualiza en vivo al cambiar de tab.
  if [ "$app_name" = "Warp" ] && command -v sqlite3 >/dev/null 2>&1; then
    db=$(ls "$HOME"/Library/Group\ Containers/*.dev.warp/Library/Application\ Support/dev.warp.Warp*/warp.sqlite 2>/dev/null | head -1)
    if [ -n "$db" ] && [ -f "$db" ]; then
      # ponytail: asume 1 ventana de Warp (la de menor id). Multi-ventana no es
      # resoluble: la BD no marca qué ventana tiene el foco. Si abres varias
      # ventanas de Warp, mapear foco→ventana necesitaría cruzar geometría.
      path=$(sqlite3 -readonly "$db" "
        SELECT tp.cwd FROM windows w
        JOIN tabs t ON t.window_id = w.id
        JOIN pane_nodes pn ON pn.tab_id = t.id
        JOIN terminal_panes tp ON tp.id = pn.id
        WHERE w.id = (SELECT id FROM windows ORDER BY id LIMIT 1)
        ORDER BY t.id
        LIMIT 1 OFFSET (SELECT active_tab_index FROM windows ORDER BY id LIMIT 1);
      " 2>/dev/null)
      [ -n "$path" ] && [ -d "$path" ] && target="$path"
    fi
  fi

  descendants=$(collect_descendants "$app_pid")

  # 1) Prefer tmux: shells live under the tmux server (daemon), not under the
  # terminal app, so walking descendants would miss them. Match the tmux
  # client process (descendant of the terminal) and ask tmux — from THAT
  # client's perspective — for the focused pane's CWD. Using `-c <client>`
  # (instead of `-t <session>:`) is what makes #{pane_current_path} resolve
  # to the pane the user is actually looking at: with multiple panes/splits,
  # each tmux client has its own active pane.
  if [ -z "$target" ] && command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
    while read -r d; do
      [ -z "$d" ] && continue
      name=$(ps -o comm= -p "$d" 2>/dev/null | awk -F/ '{print $NF}')
      if [ "$name" = "tmux" ]; then
        client=$(tmux list-clients -F '#{client_pid} #{client_name}' 2>/dev/null \
                 | awk -v p="$d" '$1==p{print $2; exit}')
        if [ -n "$client" ]; then
          path=$(tmux display-message -c "$client" -p '#{pane_current_path}' 2>/dev/null)
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
