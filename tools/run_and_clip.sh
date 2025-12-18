#!/usr/bin/env bash
set -euo pipefail

guard_cmd_safety() {
  # Reject fragile / likely-corrupted command strings before execution.
  local cmd="$1"

  # Refuse literal newlines inside a single command argument
  case "$cmd" in
    *$'\n'*)
      echo "REFUSE: command contains literal newline(s). Author a script file first; then run it under run_and_clip." >&2
      return 2
      ;;
  esac

  # Refuse a common paste-corruption symptom: stray leading ")"
  if printf "%s" "$cmd" | grep -qE "^[[:space:]]*\)"; then
    echo "REFUSE: command begins with a stray \")\" (paste corruption). Clear prompt and re-run." >&2
    return 2
  fi

  # Refuse heredocs and destructive redirects inside governed args
  if printf "%s" "$cmd" | grep -Eq '<<|cat[[:space:]]+>[[:space:]]+|tee[[:space:]]+>[[:space:]]+'; then
    echo "REFUSE: heredoc/redirect detected inside governed command arg. Write a patch script file first; then run it." >&2
    return 2
  fi

  # Heuristic: unmatched quotes (common paste-corruption symptom)
  s_count="$(printf "%s" "$cmd" | awk -F"'" '{print NF-1}')"
  d_count="$(printf "%s" "$cmd" | awk -F"\"" '{print NF-1}')"
  if [ $((s_count % 2)) -ne 0 ] || [ $((d_count % 2)) -ne 0 ]; then
    echo "REFUSE: likely unmatched quote in governed command arg. Use simpler one-liners or a script file." >&2
    return 2
  fi

  return 0
}

# Run one or more commands in a child bash, capture ALL output to a log,
# and copy the log to X11 clipboard via xclip (never wl-copy).
#
# Usage:
#   ./tools/run_and_clip.sh "cmd1" "cmd2" ...
#
# Output:
#   - writes log to _drive_stage/runlogs/run.<timestamp>.log
#   - best-effort copies the log to X11 clipboard (requires DISPLAY + xclip)
#   - prints the log path
if [ "$#" -lt 1 ]; then
  echo "USAGE: ./tools/run_and_clip.sh \"cmd1\" \"cmd2\" ..." >&2
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
    guard_cmd_safety "$cmd" || exit $?
    i=$((i+1))
    echo "--- CMD ${i} ---"
    echo "${cmd}"
    echo "--- OUT ${i} ---"
    bash -lc 'cd "$1"; set -euo pipefail; eval "$2"' _ "$root" "$cmd"
    echo
  done
} 2>&1 | tee "$log" >/dev/null

# Clipboard is best-effort and MUST NOT hang execution
if [ -n "${DISPLAY:-}" ] && command -v xclip >/dev/null 2>&1; then
  if command -v timeout >/dev/null 2>&1; then
    timeout 2s xclip -selection clipboard <"$log" 2>/dev/null || true
  else
    xclip -selection clipboard <"$log" 2>/dev/null || true
  fi
fi

echo "OK: copied run log to X11 clipboard (best-effort)"
echo "LOG: $log"
