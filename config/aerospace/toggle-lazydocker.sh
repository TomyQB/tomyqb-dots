#!/usr/bin/env bash
# Toggle lazydocker in workspace D.
# - If lazydocker is already running, or workspace D already has any window,
#   just focus workspace D — never spawn a duplicate.
# - Otherwise, switch to D first (so the new window lands there) and launch
#   Warp with the lazydocker launch configuration.
set -u

is_open() {
  # Primary check: the actual lazydocker process is running anywhere.
  if pgrep -x lazydocker >/dev/null 2>&1; then
    return 0
  fi
  # Fallback: a window already exists in workspace D. Covers the edge case
  # where Warp has launched but lazydocker hasn't started yet, or pgrep
  # misses the process for whatever reason.
  if aerospace list-windows --workspace D 2>/dev/null | grep -q .; then
    return 0
  fi
  return 1
}

if is_open; then
  aerospace workspace D
else
  aerospace workspace D
  open "warp://launch/lazydocker"
fi
