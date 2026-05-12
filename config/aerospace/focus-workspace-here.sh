#!/usr/bin/env bash
# Switch to <workspace> (or move the focused window into it) and make sure
# that workspace ends up on the monitor you were already looking at.
#
# Usage:
#   focus-workspace-here.sh <workspace>           # just focus the workspace here
#   focus-workspace-here.sh <workspace> --move    # move focused window there, focus follows
set -euo pipefail

AEROSPACE="/opt/homebrew/bin/aerospace"
target_ws="${1:?usage: $0 <workspace> [--move]}"
mode="${2:-}"

# Capture the focused monitor BEFORE any workspace switch — once we switch,
# focus may jump to whichever monitor that workspace last lived on.
current_monitor=$("$AEROSPACE" list-monitors --focused | awk -F' \\| ' '{print $1}')

if [[ "$mode" == "--move" ]]; then
  "$AEROSPACE" move-node-to-workspace --focus-follows-window "$target_ws"
else
  "$AEROSPACE" workspace "$target_ws"
fi

"$AEROSPACE" move-workspace-to-monitor "$current_monitor"
