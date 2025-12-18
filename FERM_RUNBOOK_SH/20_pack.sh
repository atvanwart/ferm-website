#!/usr/bin/env bash
set -euo pipefail

# RB.3 Packing (share-safe)

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
  local -a files=(
    PROJECT_STATE.md RUNBOOK.md STRUCTURE.md
    server.js courses.json autopurge.json
    src/*.js
    admin/index.html admin/ui.html admin/ui.css admin/ui.js admin/admin.js
    FERM_RUNBOOK.sh
    FERM_RUNBOOK_SH/*.sh
  )
  shopt -u nullglob
  echo "${files[@]}"
}
