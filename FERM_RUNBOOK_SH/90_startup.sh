#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

persona="${1:-alden}"

OUT="$HOME/Desktop/chatGPT_feedback"
mkdir -p "$OUT"

TS_ISO="$(date -Is)"
TS_FILE="$(date +%Y%m%d_%H%M%S)"

OUTFILE="$OUT/STARTUP_${persona}_${TS_FILE}.txt"
LOG="$OUT/STARTUP_LOG_${persona}_${TS_FILE}.log"

{
  echo "STARTUP_LOG"
  echo "TIME: $TS_ISO"
  echo "ROOT: $ROOT"
  echo "persona: $persona"
  echo "PWD: $(pwd)"
  echo "BASH: ${BASH_VERSION-}"
  echo
} > "$LOG"

emit_file_block() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    echo "=== BEGINFILE: $label ($path) ==="
    cat "$path"
    echo
    echo "=== ENDFILE: $label ==="
    echo
  else
    echo "=== MISSING: $label ($path) ==="
    echo
  fi
}

{
  echo "BEGINSTARTUP: $TS_ISO"
  echo "ROOT: $ROOT"
  echo "persona: $persona"
  echo

  echo "== HARD RULES (current) =="
  echo "- No clipboard workflows (no xclip, no clip_cmd/clipout_cmd usage)."
  echo "- Use file artifacts in: $OUT"
  echo "- Keep execution sets small (2 commands at a time)."
  echo

  echo "== REPO =="
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "branch: $(git rev-parse --abbrev-ref HEAD)"
    echo "commit: $(git rev-parse --short HEAD)"
    echo
    echo "-- status --"
    git status --porcelain=v1 || true
    echo
    echo "-- last 5 commits --"
    git --no-pager log -n 5 --oneline || true
  else
    echo "(no git repo detected)"
  fi
  echo

  emit_file_block "personas/base.md" "PERSONA BASE"
  emit_file_block "personas/${persona}.delta.md" "PERSONA DELTA"

  emit_file_block "PROJECT_STATE.md" "PROJECT_STATE"
  emit_file_block "RUNBOOK.md" "RUNBOOK"
  emit_file_block "APPENDIX_MAP.md" "APPENDIX_MAP"

  echo "== QUICK HEALTH =="
  echo "-- port 3000 --"
  ss -ltnp 2>/dev/null | awk "/:3000/ {print}" || true
  echo
  echo "-- node procs --"
  ps aux | grep -E "[n]ode.*server|[n]ode.*ferment" || true
  echo

  echo "ENDSTARTUP: $TS_ISO"
} > "$OUTFILE" 2>>"$LOG"

echo "WROTE: $OUTFILE"
echo "LOG:   $LOG"
