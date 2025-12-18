#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./FERM_RUNBOOK_SH/05_clip_cmd.sh <any command...>
# Example:
#   ./FERM_RUNBOOK_SH/05_clip_cmd.sh nl -ba FERM_RUNBOOK_SH/90_startup.sh

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <command...>" >&2
  exit 2
fi

if [ -x ./FERM_RUNBOOK.sh ]; then
  "$@" | ./FERM_RUNBOOK.sh clip -
  exit 0
fi

if command -v xclip >/dev/null 2>&1; then
  "$@" | xclip -selection clipboard
  exit 0
fi

echo "ERROR: no clipboard tool available (FERM_RUNBOOK.sh clip or xclip)" >&2
exit 1
