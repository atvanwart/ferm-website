#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# SECTION INDEX
# RB.1  core utilities          -> FERM_RUNBOOK_SH/00_core.sh
# RB.2  admin helpers           -> FERM_RUNBOOK_SH/10_admin.sh
# RB.3  packing (share-safe)    -> FERM_RUNBOOK_SH/20_pack.sh
# RB.4  quality gates           -> FERM_RUNBOOK_SH/30_quality.sh
# RB.5  drive wrappers          -> FERM_RUNBOOK_SH/40_drive.sh
# RB.9  session bootstrap       -> FERM_RUNBOOK_SH/90_startup.sh

# Load modules (explicit allowlist: operational only)
for m in \
  FERM_RUNBOOK_SH/00_core.sh \
  FERM_RUNBOOK_SH/10_admin.sh \
  FERM_RUNBOOK_SH/20_pack.sh \
  FERM_RUNBOOK_SH/30_quality.sh \
  FERM_RUNBOOK_SH/40_drive.sh \
; do
  [ -f "$m" ] || continue
  # shellcheck disable=SC1090
  source "$m"
done

need node
need curl
need python3
need sha256sum
need xclip

case "${1:-}" in
  clip)      shift; clip_cmd "${1:-}" ;;
  clipout)   clipout_cmd ;;
  pack)      shift; pack_files "$@" ;;
  pack-core) pack_files $(pack_core_files) ;;
  drive-pull-seed)
    shift
    drive_pull_seed_cmd "${1:-}"
    ;;
  drive-push-seed)
    shift
    drive_push_seed_cmd "${1:-}" "${2:-}"
    ;;
  startup)
    shift
    FERM_RUNBOOK_SH/90_startup.sh "${1:-alden}"
    ;;
  startup-clip)
    shift
    FERM_RUNBOOK_SH/90_startup.sh "${1:-alden}" | clip_cmd -
    ;;
  start-hint)
    echo "Start server (in another terminal):"
    echo "  cd $ROOT && node server.js"
    ;;
  open)
    xdg-open http://localhost:3000/ >/dev/null 2>&1 || true
    xdg-open http://localhost:3000/admin/ui/ >/dev/null 2>&1 || true
    echo "Opened site + admin UI in browser (if available)."
    ;;
  health)
    load_admin_creds
    curl -s -o /dev/null -w "health=%{http_code}\n" -u "${ADMIN_USER}:${ADMIN_PASS}" http://localhost:3000/admin/health
    ;;
  ui-smoke)
    load_admin_creds
    curl -s -o /dev/null -w "ui_index=%{http_code}\n" -u "${ADMIN_USER}:${ADMIN_PASS}" http://localhost:3000/admin/ui/
    echo "--- ui.html ---"
    curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" http://localhost:3000/admin/ui/ui.html | head -n 15
    echo "--- ui.css ---"
    curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" http://localhost:3000/admin/ui/ui.css | head -n 10
    echo "--- ui.js ---"
    curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" http://localhost:3000/admin/ui/ui.js | head -n 10
    ;;
  courses)
    admin_curl http://localhost:3000/admin/api/courses | python3 -m json.tool
    ;;
  autopurge)
    slug="${2:-}"; [ -n "$slug" ] || die "Usage: ./FERM_RUNBOOK.sh autopurge <slug>"
    admin_curl "http://localhost:3000/admin/api/autopurge/${slug}" | python3 -m json.tool
    ;;
  check-js)    check_js ;;
  check-json)  check_json ;;
  shell-leak)  shift; shell_leak "${1:-}" ;;
  size-audit)
    had_fail=0
    warn_chars="${2:-10000}"
    fail_chars="${3:-15000}"
    size_audit "$warn_chars" "$fail_chars" || true
    if [ "${had_fail}" -ne 0 ]; then
      echo "ERROR: size-audit exceeded hard limit"
      exit 1
    fi
    ;;
  checksum)    checksum_cmd ;;
  verify)      verify_cmd ;;
  doc-diff)    doc_diff_cmd ;;
  git-audit)   git_audit_cmd ;;
  sumcheck)    sumcheck_cmd ;;
  appendix)    appendix_cmd ;;
  *)
    echo "Usage:"
    echo "  ./FERM_RUNBOOK.sh clip <file|-"
    echo "  ./FERM_RUNBOOK.sh clipout"
    echo "  ./FERM_RUNBOOK.sh pack <files...>"
    echo "  ./FERM_RUNBOOK.sh pack-core"
    echo "  ./FERM_RUNBOOK.sh startup [alden|spark]"
    echo "  ./FERM_RUNBOOK.sh startup-clip [alden|spark]"
    echo "  ./FERM_RUNBOOK.sh drive-pull-seed <PARKING_LOT.md|LESSONS_LEARNED.md|SESSION_SNAPSHOTS.md>"
    echo "  ./FERM_RUNBOOK.sh drive-push-seed <PARKING_LOT.md|LESSONS_LEARNED.md|SESSION_SNAPSHOTS.md> [--force]"
    echo "  ./FERM_RUNBOOK.sh sumcheck"
    echo "  ./FERM_RUNBOOK.sh appendix"
    echo "  ./FERM_RUNBOOK.sh size-audit [warn] [fail]"
    echo "  ./FERM_RUNBOOK.sh git-audit"
    echo "  ./FERM_RUNBOOK.sh checksum && ./FERM_RUNBOOK.sh verify"
    ;;
esac
