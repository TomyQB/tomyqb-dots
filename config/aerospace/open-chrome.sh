#!/usr/bin/env bash
# Open Google Chrome without spawning duplicate windows.
# - If Chrome is already running, request a new window (so alt+b always gives
#   you a fresh window on top, even when Chrome was hidden/backgrounded).
# - If Chrome is NOT running, just launch it: the cold-start already opens a
#   default window, so asking for "make new window" on top would give us two.
set -u

if pgrep -x "Google Chrome" >/dev/null 2>&1; then
  osascript \
    -e 'tell application "Google Chrome" to make new window' \
    -e 'tell application "Google Chrome" to activate'
else
  open -a "Google Chrome"
fi
