#!/usr/bin/env bash
set -euo pipefail

# RB.4 Quality gates

git_counts() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "NOT_A_GIT_REPO"
    return 0
  fi

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

  local porcelain
  porcelain="$(git status --porcelain=v1 2>/dev/null || true)"

  local modified deleted untracked
  modified="$(printf "%s\n" "$porcelain" | awk '/^[ MARCUD][MD] /{c++} END{print c+0}')"
  deleted="$(printf "%s\n" "$porcelain" | awk '/^[ MARCUD]D /{c++} END{print c+0}')"
  untracked="$(printf "%s\n" "$porcelain" | awk '/^\?\? /{c++} END{print c+0}')"

  echo "branch=${branch:-unknown} modified=${modified} deleted=${deleted} untracked=${untracked}"
}

check_js() {
  local ok=1
  for f in server.js admin/ui.js admin/admin.js src/courses.js src/jsonStore.js src/services/canvas.js src/canvas.js src/autopurge.js; do
    [ -f "$f" ] || continue
    if node --check "$f" >/dev/null 2>&1; then
      echo "OK: $f"
    else
      echo "FAIL: $f"
      ok=0
    fi
  done
  [ "$ok" -eq 1 ]
}

check_json() {
  local ok=1
  for f in courses.json autopurge.json; do
    [ -f "$f" ] || continue
    if python3 -m json.tool < "$f" >/dev/null 2>&1; then
      echo "OK: $f"
    else
      echo "FAIL: $f"
      ok=0
    fi
  done
  [ "$ok" -eq 1 ]
}

shell_leak() {
  local f="${1:-}"; [ -n "$f" ] || die "Usage: ./FERM_RUNBOOK.sh shell-leak <file>"
  grep -nE "(^pendor@|^root@|\$\s*$|^\s*cat\s+>\s+|^\s*EOF\s*$|^BEGINPACK|^BEGINFILE:|^ENDFILE:|^ENDPACK)" "$f" || true
}

size_audit() {
  local warn_chars="${1:-10000}"
  local fail_chars="${2:-15000}"

  echo "== STEP: size-audit (warn >${warn_chars}, fail >${fail_chars}) =="

  local warned=0
  local failed=0
  local c

  check_one() {
    local path="$1"
    [ -f "$path" ] || return 0
    c="$(wc -c < "$path" | tr -d " ")"
    if [ "$c" -gt "$fail_chars" ]; then
      echo "FAIL: $path chars=$c (>${fail_chars}). Must reorganize into modules/docs."
      had_fail=1
      failed=1
      return 0
    fi
    if [ "$c" -gt "$warn_chars" ]; then
      echo "WARN: $path chars=$c (>${warn_chars}). Should reorganize into modules/docs."
      warned=1
      return 0
    fi
    return 0
  }

  check_one PROJECT_STATE.md
  check_one RUNBOOK.md
  check_one STRUCTURE.md
  check_one FERM_RUNBOOK.sh
  check_one FERM_RUNBOOK_SH/TEST_USER.sh
  check_one server.js
  check_one admin/ui.js

  for f in src/*.js admin/* FERM_RUNBOOK_SH/*.sh; do
    [ -f "$f" ] || continue
    check_one "$f"
  done

  if [ "$failed" -eq 1 ]; then
    echo
    return 1
  fi

  if [ "$warned" -eq 0 ]; then
    echo "OK: no tracked files exceed warn threshold"
  fi

  echo
  return 0
}

checksum_cmd() {
  sha256sum \
    PROJECT_STATE.md RUNBOOK.md STRUCTURE.md \
    server.js courses.json autopurge.json \
    src/jsonStore.js src/courses.js src/canvas.js src/autopurge.js \
    admin/index.html admin/ui.html admin/ui.css admin/ui.js admin/admin.js \
    FERM_RUNBOOK.sh \
    FERM_RUNBOOK_SH/*.sh \
    | tee CHECKSUMS.sha256
}

verify_cmd() { sha256sum -c CHECKSUMS.sha256; }

doc_diff_cmd() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git --no-pager diff --name-only -- PROJECT_STATE.md RUNBOOK.md STRUCTURE.md | awk 'NF' || true
  else
    echo "NOT_A_GIT_REPO"
  fi
}

git_audit_cmd() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "=== GIT BRANCH ==="
    git rev-parse --abbrev-ref HEAD 2>/dev/null || true
    echo
    echo "=== GIT LAST COMMIT ==="
    git --no-pager log -1 --oneline 2>/dev/null || true
    echo
    echo "=== GIT STATUS (porcelain) ==="
    git status --porcelain=v1 || true
    echo
    echo "=== GIT DIFF --stat ==="
    git --no-pager diff --stat || true
    echo
    echo "=== DOC DIFF (PROJECT_STATE.md, RUNBOOK.md, STRUCTURE.md) ==="
    git --no-pager diff -- PROJECT_STATE.md RUNBOOK.md STRUCTURE.md || true
  else
    echo "NOT_A_GIT_REPO"
  fi
}

sumcheck_cmd() {
  local tmp
  tmp="$(mktemp)"
  local failed_at=""
  run_step() {
    local name="$1"; shift
    echo "== STEP: $name =="
    if ! "$@"; then
      failed_at="$name"
      return 1
    fi
    echo
    return 0
  }

  {
    echo "=== SUMCHECK $(date -Is) ==="
    echo

    run_step "check-js" check_js
    run_step "check-json" check_json
    run_step "shell-leak server.js" shell_leak server.js
    run_step "shell-leak runbook" shell_leak FERM_RUNBOOK.sh
    run_step "size-audit warn>10k fail>15k" size_audit 10000 15000
    run_step "checksum" checksum_cmd
    run_step "verify" verify_cmd

    echo "== STEP: git summary =="
    echo "$(git_counts)"
    echo

    echo "== STEP: docs changed? =="
    docs_changed="$(doc_diff_cmd || true)"
    if [ -n "$docs_changed" ]; then
      echo "docs_changed=yes"
      echo "$docs_changed"
    else
      echo "docs_changed=no"
    fi

    echo
    echo "=== END SUMCHECK ==="
  } | tee "$tmp"

  clip_cmd "$tmp" >/dev/null 2>&1 || true
}

appendix_cmd() {
  # APPENDIX_MAP.md is allowed to be huge; it is for search/navigation only.
  {
    echo "# Appendix Map"
    echo
    echo "Generated: $(date -Is)"
    echo "Root: $ROOT"
    echo
    echo "## Tree (files)"
    echo
    find . -maxdepth 4 -type f \
      -not -path "./node_modules/*" \
      -not -path "./.git/*" \
      -not -path "./_old/*" \
      | sort
    echo
    echo "## Shell functions (runbook + modules)"
    echo
    grep -nRE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)\s*\{' FERM_RUNBOOK.sh FERM_RUNBOOK_SH/*.sh 2>/dev/null | sort || true
    echo
    echo "## JS classes/functions (rough index)"
    echo
    grep -nRE '^(export\s+)?class\s+|^(export\s+)?function\s+|^\s*function\s+' server.js src admin 2>/dev/null | head -n 2000 || true
  } > APPENDIX_MAP.md
  echo "OK: wrote APPENDIX_MAP.md"
}
