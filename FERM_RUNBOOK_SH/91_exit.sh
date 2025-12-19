#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="$HOME/Desktop/chatGPT_feedback"
mkdir -p "$OUT"

TS_ISO="$(date -Is)"
TS_FILE="$(date +%Y%m%d_%H%M%S)"

TEMPLATE="$OUT/EXIT_INPUT_TEMPLATE_${TS_FILE}.txt"
SNAP="$OUT/EXIT_SNAPSHOT_${TS_FILE}.txt"
LOG="$OUT/EXIT_LOG_${TS_FILE}.log"
NEXT_STARTUP="$OUT/NEXT_STARTUP_NOTES_${TS_FILE}.txt"

{
  echo "EXIT_LOG"
  echo "TIME: $TS_ISO"
  echo "ROOT: $ROOT"
  echo "PWD: $(pwd)"
  echo "SHELL: ${SHELL-}"
  echo "BASH: ${BASH_VERSION-}"
  echo
} > "$LOG"

cat > "$TEMPLATE" <<EOT
# EXIT_INPUT (fill this in before starting next session)

[SUMMARY]
(one paragraph, max ~8 lines)

[LESSONS_LEARNED]
- (max 7 bullets; include concrete mistakes + prevention)

[PARKING_LOT]
- (max 10 bullets; “later” items, no action now)

[DECISIONS]
- (max 7 bullets)

[NEXT]
- (max 7 bullets; first 1–2 must be executable/decidable tomorrow)
EOT

# Write tomorrow’s startup notes NOW (so you don’t have to remember)
{
  echo "NEXT STARTUP NOTES"
  echo "TIME: $TS_ISO"
  echo
  echo "KNOWN PITFALLS"
  echo "- 90_startup.sh takes a persona NAME (e.g., alden), not a path like personas/alden.delta.md."
  echo "- Passing a path injects slashes into filenames and can break log creation."
  echo "- FERM_RUNBOOK.sh may currently be syntactically broken (\"unexpected EOF\") — run bash -n before using it."
  echo
  echo "TOMORROW FIRST MOVES (order)"
  echo "1) bash -n FERM_RUNBOOK.sh || true    # confirm it parses"
  echo "2) git status --porcelain=v1"
  echo "3) bash FERM_RUNBOOK_SH/90_startup.sh alden   # writes STARTUP_* file"
  echo
  echo "PARKING LOT"
  echo "- Build APPENDIX_MAP.md generator from APPENDIX_FILE_LIST.txt (no manual edits)."
  echo "- Fix FERM_RUNBOOK.sh usage block safely (avoid perl one-liners that can corrupt quotes)."
  echo "- Remove/retire clipboard modules (05_clip_cmd.sh, 10.clip_x11.sh, 20.run_and_clip.sh) after deprecation plan."
} > "$NEXT_STARTUP" 2>>"$LOG"

{
  echo "BEGINEXIT: $TS_ISO"
  echo "ROOT: $ROOT"
  echo

  echo "WROTE:"
  echo "  TEMPLATE: $TEMPLATE"
  echo "  SNAPSHOT: $SNAP"
  echo "  LOG:      $LOG"
  echo "  NEXT:     $NEXT_STARTUP"
  echo

  echo "== GIT =="
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "branch: $(git rev-parse --abbrev-ref HEAD)"
    echo "commit: $(git rev-parse --short HEAD)"
    echo
    echo "-- status --"
    git status --porcelain=v1 || true
    echo
    echo "-- diff (stat) --"
    git diff --stat || true
  else
    echo "(no git repo detected)"
  fi
  echo

  echo "== PARSE GATES =="
  echo "-- bash -n FERM_RUNBOOK.sh --"
  bash -n FERM_RUNBOOK.sh >/dev/null 2>&1 && echo "OK: FERM_RUNBOOK.sh parses" || echo "FAIL: FERM_RUNBOOK.sh parse error"
  echo "-- bash -n 90_startup.sh / 91_exit.sh --"
  bash -n FERM_RUNBOOK_SH/90_startup.sh >/dev/null 2>&1 && echo "OK: 90_startup.sh parses" || echo "FAIL: 90_startup.sh parse error"
  bash -n FERM_RUNBOOK_SH/91_exit.sh >/dev/null 2>&1 && echo "OK: 91_exit.sh parses" || echo "FAIL: 91_exit.sh parse error"
  echo

  echo "== PORT 3000 =="
  ss -ltnp 2>/dev/null | awk "/:3000/ {print}" || true
  echo

  echo "== NODE PROCS =="
  ps aux | grep -E "[n]ode.*server|[n]ode.*ferment" || true
  echo

  echo "== server.log tail =="
  tail -n 160 server.log 2>/dev/null || true
  echo

  echo "ENDEXIT: $TS_ISO"
} > "$SNAP" 2>>"$LOG"

echo "OK: exit artifacts written"
echo "TEMPLATE: $TEMPLATE"
echo "SNAPSHOT: $SNAP"
echo "LOG: $LOG"
echo "NEXT: $NEXT_STARTUP"
