#!/usr/bin/env bash
set -euo pipefail
# X11-only clipboard helper. Never calls wl-copy. Wayland is out-of-scope.

if [ -z "${DISPLAY:-}" ]; then
  echo "NO X11: DISPLAY is unset (cannot copy)" >&2
  exit 2
fi

if ! command -v xclip >/dev/null 2>&1; then
  echo "NO X11: xclip not installed (cannot copy)" >&2
  exit 2
fi

cat | xclip -selection clipboard 2>/dev/null
echo "OK: copied to X11 clipboard"
