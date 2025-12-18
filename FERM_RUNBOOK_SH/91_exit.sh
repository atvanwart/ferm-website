#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing $1"; exit 1; }; }
need_cmd rclone
need_cmd date
need_cmd sed
need_cmd tee

# Prefer runbook clip helper if present; fall back to xclip.
clip_file() {
  local f="$1"
  if [ -x "./FERM_RUNBOOK.sh" ]; then
    ./FERM_RUNBOOK.sh clip "$f" 2>/dev/null && return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard < "$f"
    return 0
  fi
  echo "WARN: no clip method available (FERM_RUNBOOK.sh clip or xclip)"
  return 0
}

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="/tmp/fermentors_exit_${STAMP}.txt"

echo "== Exit: pull shared artifacts ==" | tee "$OUT" >/dev/null
mkdir -p _drive_sync

for f in PARKING_LOT.md LESSONS_LEARNED.md SESSION_SNAPSHOTS.md; do
  if [ -x "./FERM_RUNBOOK.sh" ]; then
    ./FERM_RUNBOOK.sh drive-pull-seed "$f" >/dev/null 2>&1 || true
  else
    rclone copyto "fermdrive:${f}" "_drive_sync/${f}" >/dev/null 2>&1 || true
  fi
done

# Snapshot: facts only (primary)
{
  echo "=== Fermentors Exit Snapshot ==="
  echo "TIME: $(date -Is)"
  echo "ROOT: $ROOT"
  echo
  echo "== git =="
  if command -v git >/dev/null 2>&1 && [ -d .git ]; then
    git rev-parse --abbrev-ref HEAD 2>/dev/null || true
    git rev-parse HEAD 2>/dev/null || true
    echo "--- status ---"
    git status --porcelain 2>/dev/null || true
    echo "--- last 5 commits ---"
    git log -n 5 --oneline 2>/dev/null || true
  else
    echo "no git repo detected"
  fi
  echo
  echo "== server process hint (port 3000) =="
  if command -v ss >/dev/null 2>&1; then
    ss -ltnp 2>/dev/null | awk '/:3000/ {print}' || true
  else
    echo "ss not available"
  fi
  echo
  echo "== HTTP smoke =="
  if command -v curl >/dev/null 2>&1; then
    echo "--- /handshake/preview ---"
    curl -s -i http://localhost:3000/handshake/preview || true
    echo
    echo "--- /auth.html (HEAD) ---"
    curl -s -I http://localhost:3000/auth.html || true
  else
    echo "curl not available"
  fi
  echo
  echo "== Drive listing (root constrained) =="
  rclone lsf fermdrive: 2>/dev/null || true
} | tee "$OUT" >/dev/null

clip_file "$OUT"
echo "OK: exit snapshot captured -> $OUT"
echo "OK: snapshot copied to clipboard (if clip available)"
