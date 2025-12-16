#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

die(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

need node
need curl
need python3
need sha256sum

is_secret_path() {
  case "$1" in
    .env|*/.env|*.env|*id_rsa*|*.pem|*.key) return 0 ;;
  esac
  return 1
}

clipboard_copy() {
  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
    return 0
  fi
  if command -v wl-copy >/dev/null 2>&1; then
    wl-copy
    return 0
  fi
  die "No clipboard tool found. Install xclip (X11) or wl-clipboard (Wayland)."
}

clipboard_paste() {
  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
    return 0
  fi
  if command -v wl-paste >/dev/null 2>&1; then
    wl-paste
    return 0
  fi
  die "No clipboard paste tool found. Install xclip (X11) or wl-clipboard (Wayland)."
}

load_admin_creds() {
  ADMIN_USER="$(node -e "require('dotenv').config({path:'.env'}); process.stdout.write(process.env.ADMIN_USER||'')" || true)"
  ADMIN_PASS="$(node -e "require('dotenv').config({path:'.env'}); process.stdout.write(process.env.ADMIN_PASS||'')" || true)"
  [ -n "${ADMIN_USER}" ] || die "ADMIN_USER missing in .env"
  [ -n "${ADMIN_PASS}" ] || die "ADMIN_PASS missing in .env"
}

admin_curl() {
  load_admin_creds
  curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" "$@"
}

pack_files() {
  local -a files=()
  for f in "$@"; do
    [ -f "$f" ] || die "No such file: $f"
    is_secret_path "$f" && die "Refusing to include secret-like file: $f"
    files+=("$f")
  done

  echo "BEGINPACK: $(date -Is)"
  echo "ROOT: $ROOT"
  echo "BEGINCHECKSUMS"
  sha256sum "${files[@]}"
  echo "ENDCHECKSUMS"
  echo

  for f in "${files[@]}"; do
    echo "BEGINFILE: $f"
    cat "$f"
    echo
    echo "ENDFILE: $f"
    echo
  done

  echo "ENDPACK"
}

pack_core_files() {
  shopt -s nullglob
  local -a files=(PROJECT_STATE.md RUNBOOK.md server.js courses.json autopurge.json src/*.js admin/index.html admin/ui.html admin/ui.css admin/ui.js scripts/FERM_RUNBOOK.sh)
  shopt -u nullglob
  echo "${files[@]}"
}

git_counts() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "NOT_A_GIT_REPO"
    return 0
  fi

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

  local porcelain
  porcelain="$(git status --porcelain=v1 2>/dev/null || true)"

  local modified added deleted untracked
  modified="$(printf "%s\n" "$porcelain" | awk '/^[ MARCUD][MD] /{c++} END{print c+0}')"
  added="$(printf "%s\n" "$porcelain" | awk '/^\?\? /{c++} END{print c+0}')"
  deleted="$(printf "%s\n" "$porcelain" | awk '/^[ MARCUD]D /{c++} END{print c+0}')"
  untracked="$added"

  echo "branch=${branch:-unknown} modified=${modified} deleted=${deleted} untracked=${untracked}"
}

case "${1:-}" in
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
    curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" http://localhost:3000/admin/ui/ui.css  | head -n 10
    echo "--- ui.js ---"
    curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" http://localhost:3000/admin/ui/ui.js   | head -n 10
    ;;

  courses)
    admin_curl http://localhost:3000/admin/api/courses | python3 -m json.tool
    ;;

  autopurge)
    slug="${2:-}"; [ -n "$slug" ] || die "Usage: $0 autopurge <slug>"
    admin_curl "http://localhost:3000/admin/api/autopurge/${slug}" | python3 -m json.tool
    ;;

  purge-dry)
    slug="${2:-}"; [ -n "$slug" ] || die "Usage: $0 purge-dry <slug>"
    admin_curl "http://localhost:3000/admin/jobs/purge/${slug}" | python3 -m json.tool
    ;;

  purge)
    slug="${2:-}"; [ -n "$slug" ] || die "Usage: $0 purge <slug>"
    load_admin_creds
    curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" \
      -H 'Content-Type: application/json' \
      -d '{"confirm":"PURGE"}' \
      "http://localhost:3000/admin/jobs/purge/${slug}" | python3 -m json.tool
    ;;

  reset-week)
    slug="${2:-}"; [ -n "$slug" ] || die "Usage: $0 reset-week <slug>"
    load_admin_creds
    curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" \
      -H 'Content-Type: application/json' \
      -d '{"confirm":"RESET"}' \
      "http://localhost:3000/admin/jobs/reset_week/${slug}" | python3 -m json.tool
    ;;

  check-js)
    node --check server.js && echo "OK: server.js"
    find admin src -type f -name '*.js' -print0 2>/dev/null | while IFS= read -r -d '' f; do
      node --check "$f" >/dev/null && echo "OK: $f"
    done
    ;;

  check-json)
    for f in courses.json autopurge.json; do
      [ -f "$f" ] || continue
      python3 -m json.tool < "$f" >/dev/null && echo "OK: $f"
    done
    ;;

  shell-leak)
    f="${2:-}"; [ -n "$f" ] || die "Usage: $0 shell-leak <file>"
    grep -nE "(^pendor@|^root@|\\$\\s*$|^\\s*cat\\s+>\\s+|^\\s*EOF\\s*$|^BEGINPACK|^BEGINFILE:|^ENDFILE:|^ENDPACK)" "$f" || true
    ;;

  checksum)
    sha256sum \
      PROJECT_STATE.md RUNBOOK.md \
      server.js courses.json autopurge.json \
      src/jsonStore.js src/courses.js src/canvas.js src/autopurge.js \
      admin/index.html admin/ui.html admin/ui.css admin/ui.js \
      scripts/FERM_RUNBOOK.sh \
      | tee CHECKSUMS.sha256
    ;;

  verify)
    sha256sum -c CHECKSUMS.sha256
    ;;

  doc-diff)
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git --no-pager diff --name-only -- PROJECT_STATE.md RUNBOOK.md | sed '/^$/d' || true
    else
      echo "NOT_A_GIT_REPO"
    fi
    ;;

  git-audit)
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
      echo "=== DOC DIFF (PROJECT_STATE.md, RUNBOOK.md) ==="
      git --no-pager diff -- PROJECT_STATE.md RUNBOOK.md || true
    else
      echo "NOT_A_GIT_REPO"
    fi
    ;;

  sumcheck)
    tmp="$(mktemp)"
    failed_at=""

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

      run_step "check-js" "$0" check-js
      run_step "check-json" "$0" check-json
      run_step "shell-leak server.js" "$0" shell-leak server.js
      run_step "shell-leak runbook" "$0" shell-leak scripts/FERM_RUNBOOK.sh
      run_step "checksum" "$0" checksum
      run_step "verify" "$0" verify

      echo "== STEP: git summary =="
      echo "$(git_counts)"
      echo

      echo "== STEP: docs changed? =="
      d="$("$0" doc-diff)"
      if [ "$d" = "NOT_A_GIT_REPO" ]; then
        echo "NOT_A_GIT_REPO"
      elif [ -z "$d" ]; then
        echo "docs_changed=no"
      else
        echo "docs_changed=yes"
        echo "$d"
      fi
      echo

      echo "=== END SUMCHECK ==="
    } > "$tmp" || true

    cat "$tmp" | clipboard_copy
    bytes="$(wc -c < "$tmp")"
    if [ -n "$failed_at" ]; then
      echo "ERROR: sumcheck failed at ${failed_at} (copied partial log to clipboard; ${bytes} bytes)"
      rm -f "$tmp"
      exit 1
    fi
    echo "OK: sumcheck copied to clipboard (${bytes} bytes)"
    rm -f "$tmp"
    ;;

  diag)
    "$0" check-js
    "$0" check-json
    "$0" verify
    echo "OK: diag complete"
    ;;

  clip)
    target="${2:-}"; [ -n "$target" ] || die "Usage: $0 clip <file|- (stdin)>"
    if [ "$target" = "-" ]; then
      cat | clipboard_copy
      echo "OK: clipboard updated from stdin"
      exit 0
    fi
    [ -f "$target" ] || die "No such file: $target"
    is_secret_path "$target" && die "Refusing to copy secret-like file: $target"
    cat "$target" | clipboard_copy
    echo "OK: clipboard updated from $target"
    ;;

  clipout)
    clipboard_paste
    ;;

  pack)
    shift || true
    [ "$#" -ge 1 ] || die "Usage: $0 pack <file1> [file2 ...]"
    pack_files "$@"
    ;;

  pack-core)
    read -r -a files <<<"$(pack_core_files)"
    pack_files "${files[@]}"
    ;;

  packclip)
    shift || true
    [ "$#" -ge 1 ] || die "Usage: $0 packclip <file1> [file2 ...]"
    pack_files "$@" | clipboard_copy
    echo "OK: pack copied to clipboard"
    ;;

  packclip-core)
    read -r -a files <<<"$(pack_core_files)"
    pack_files "${files[@]}" | clipboard_copy
    echo "OK: core pack copied to clipboard"
    ;;

  *)
    cat <<USAGE
Usage: $0 <command> [args]

Commands:
  start-hint
  open
  health
  ui-smoke
  courses
  autopurge <slug>
  purge-dry <slug>
  purge <slug>
  reset-week <slug>
  check-js
  check-json
  shell-leak <file>
  diag
  checksum
  verify
  doc-diff
  git-audit
  sumcheck
  clip <file|- (stdin)>
  clipout
  pack <file1> [file2 ...]
  pack-core
  packclip <file1> [file2 ...]
  packclip-core
USAGE
    exit 1
    ;;
esac
