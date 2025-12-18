#!/usr/bin/env bash
set -euo pipefail

# Run one or more commands in a child bash, capture ALL output to a log,
# and copy the log to X11 clipboard via xclip (never wl-copy).
#
# Usage:
#   ./tools/run_and_clip.sh "cmd1" "cmd2" ...
#
# Output:
#   - writes log to _drive_stage/runlogs/run.<timestamp>.log
#   - copies the log to X11 clipboard (requires DISPLAY + xclip)
#   - prints the log path

if [ "$#" -lt 1 ]; then
  echo "USAGE: ./tools/run_and_clip.sh \"cmd1\" \"cmd2\" ..." >&2
  exit 2
fi

if [ -z "${DISPLAY:-}" ]; then
  echo "NO X11: DISPLAY is unset (cannot copy output). Run in X11 terminal." >&2
  exit 2
fi

if ! command -v xclip >/dev/null 2>&1; then
  echo "NO X11: xclip not installed (cannot copy output)." >&2
  exit 2
fi

root="$(pwd)"
outdir="$root/_drive_stage/runlogs"
mkdir -p "$outdir"
ts="$(date +%Y%m%dT%H%M%S%z)"
log="$outdir/run.${ts}.log"

{
  echo "=== RUN_AND_CLIP ==="
  echo "TIME: $(date -Iseconds)"
  echo "PWD:  $root"
  echo "USER: $(id -un)"
  echo "HOST: $(hostname)"
  echo "GIT:  $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo n/a) @ $(git rev-parse --short HEAD 2>/dev/null || echo n/a)"
  echo

  i=0
  for cmd in "$@"; do
    i=$((i+1))
    echo "--- CMD ${i} ---"
    echo "${cmd}"
    echo "--- OUT ${i} ---"
    bash -lc "cd \"$root\"; set -euo pipefail; ${cmd}"
    echo
  done
} 2>&1 | tee "$log" | xclip -selection clipboard 2>/dev/null

echo "OK: copied run log to X11 clipboard"
echo "LOG: $log"
