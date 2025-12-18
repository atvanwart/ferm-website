#!/usr/bin/env bash
set -u
# Run strict multi-step work in a CHILD shell so failures cannot terminate the operator shell.
# Usage:
#   ./tools/safe_child.sh "<command string>"

cmd="${1:-}"
if [ -z "$cmd" ]; then
  echo "USAGE: ./tools/safe_child.sh \"<command string>\"" >&2
  exit 2
fi

bash -lc "set -euo pipefail; ${cmd}"
