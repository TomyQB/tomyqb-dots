#!/usr/bin/env bash
# Toggle lazydocker in workspace D.
# - If lazydocker is already running: just focus workspace D.
# - Otherwise: switch to workspace D first (so the new window lands there)
#   and launch Ghostty with lazydocker as its command.
set -u

if pgrep -x lazydocker >/dev/null 2>&1; then
  aerospace workspace D
else
  aerospace workspace D
  open -na Ghostty --args --command=lazydocker
fi
