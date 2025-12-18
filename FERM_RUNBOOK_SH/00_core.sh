#!/usr/bin/env bash
set -euo pipefail

# RB.1 Core utilities (sourced only)

die(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

is_secret_path() {
  case "$1" in
    .env|*/.env|*.env|*id_rsa*|*.pem|*.key) return 0 ;;
  esac
  return 1
}

clipboard_copy() { xclip -selection clipboard; }
clipboard_paste() { xclip -selection clipboard -o; }

clip_cmd() {
  local target="${1:-}"; [ -n "$target" ] || die "Usage: ./FERM_RUNBOOK.sh clip <file|- (stdin)>"
  if [ "$target" = "-" ]; then
    cat | clipboard_copy
    echo "OK: clipboard updated from stdin"
    return 0
  fi
  [ -f "$target" ] || die "No such file: $target"
  is_secret_path "$target" && die "Refusing to copy secret-like file: $target"
  cat "$target" | clipboard_copy
  echo "OK: clipboard updated from $target"
}

clipout_cmd() { clipboard_paste; }
