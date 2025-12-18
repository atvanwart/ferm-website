#!/usr/bin/env bash
# RB.9.0 startup – session bootstrap (persona-aware)
# Purpose: Emit a reproducible session bundle for LLM collaboration
# Policy: Never echo secrets. Emit layered persona + tiny memory artifacts.

set -euo pipefail

# Refuse to be sourced
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  echo "ERROR: Do not source this script. Run it as an entrypoint." >&2
  return 1 2>/dev/null || exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

persona="${1:-alden}"
case "$persona" in
  alden|spark) ;;
  *)
    echo "Usage: FERM_RUNBOOK_SH/90_startup.sh [alden|spark]" >&2
    exit 2
    ;;
esac

base_path="personas/base.md"
delta_path="personas/${persona}.delta.md"

die() { echo "ERROR: $*" >&2; exit 1; }

emit_file_block() {
  # Emit a file with a header; head-limited unless forced full
  # Args: <label> <path> <mode>  mode: full|head160
  local label="$1"
  local path="$2"
  local mode="$3"

  [ -f "$path" ] || return 0
  echo
  echo "-- ${label}: ${path} --"
  if [ "$mode" = "full" ]; then
    cat "$path"
  else
    head -n 160 "$path" || cat "$path"
  fi
}

check_char_limit() {
  # Args: <path> <limit_chars>
  local path="$1"
  local limit="$2"
  [ -f "$path" ] || return 0
  local chars
  chars="$(wc -c < "$path" | tr -d ' ')"
  if [ "$chars" -gt "$limit" ]; then
    die "Layer C size limit exceeded: ${path} chars=${chars} > ${limit}"
  fi
}

echo "BEGINSTARTUP: $(date +%Y-%m-%dT%H:%M:%S%z)"
echo "ROOT: $ROOT"
echo "PERSONA: $persona"
echo

echo "== ENV (keys only; values suppressed) =="
env | cut -d= -f1 | sort
echo

echo "== GIT =="
echo "branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
echo "commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
echo
echo "-- status --"
git status -s
echo
echo "-- recent commits --"
git log --oneline -8
echo

# Layer A + B: persona contract
[ -f "$base_path" ] || die "Missing required persona base: ${base_path}"
[ -f "$delta_path" ] || die "Missing required persona delta: ${delta_path}"

echo "== PERSONA (Layer A + B) =="
emit_file_block "BASE"  "$base_path"  full
emit_file_block "DELTA" "$delta_path" full
echo

# Layer C: memory artifacts (tiny, enforced)
check_char_limit "memory/session_current.md" 1000
check_char_limit "memory/session_last_summary.md" 1500

echo "== MEMORY (Layer C; tiny artifacts) =="
emit_file_block "MEMORY" "memory/session_current.md" full
emit_file_block "MEMORY" "memory/session_last_summary.md" full
emit_file_block "MEMORY" "memory/decisions.md" head160
echo

# Include key docs (existing behavior preserved)
for doc in PROJECT_STATE.md RUNBOOK.md STRUCTURE.md APPENDIX_MAP.md CHECKSUMS.sha256; do
  [ -f "$doc" ] || continue
  echo
  echo "-- $doc (head $(wc -l < "$doc" | xargs printf "%3d")) --"
  head -n 160 "$doc" || cat "$doc"
done

# Include runbook script itself (existing behavior preserved)
echo
echo "-- FERM_RUNBOOK.sh (head 160) --"
head -n 160 FERM_RUNBOOK.sh

echo
echo "ENDSTARTUP: $(date +%Y-%m-%dT%H:%M:%S%z)"
