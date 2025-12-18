#!/usr/bin/env bash
set -euo pipefail

cd ~/Adam_Van_Wart/fermentors/ferm-website || exit 1
mkdir -p _old FERM_RUNBOOK_SH

python3 - <<\PYfrom pathlib import Path

root = Path(".")
shdir = root / "FERM_RUNBOOK_SH"
shdir.mkdir(parents=True, exist_ok=True)

startup = shdir / "90_startup.sh"
exitsh  = shdir / "91_exit.sh"
newp    = shdir / "_startup_payload.new.txt"
oldp    = shdir / "_startup_payload.old.txt"

startup.write_text(r"""#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

tmp="$(mktemp)"
tmp2="$(mktemp)"
ts="$(date -Is)"

REDACT_PATH_RE="(^|/)(\\.git(/|$)|node_modules(/|$)|\\.next(/|$)|dist(/|$)|build(/|$)|\\.cache(/|$)|\\.turbo(/|$)|coverage(/|$)|_old(/|$)|\\.env($|\\.)|\\.env\\..*|secrets?\\b|secret\\b|tokens?\\b|api[_-]?keys?\\b|keys?\\b|credentials?\\b|passwords?\\b|passwd\\b|private\\b|id_rsa\\b|pem\\b|p12\\b|keystore\\b)"

redact_payload() {
  if command -v perl >/dev/null 2>&1; then
    perl -pe q{
      s/^((?:OPENAI|SUPABASE|STRIPE|JWT|OAUTH|GOOGLE|AWS|AZURE|GCP|SENTRY|SENDGRID|MAILGUN|TWILIO|GITHUB|NPM|CLOUDFLARE|DATABASE|DB|POSTGRES|PG|REDIS|SMTP)[A-Z0-9_\\-]*\\s*=)\\s*.+$/$1 [REDACTED]/i;
      s/\\b(eyJ[a-zA-Z0-9_\\-]{10,}\\.[a-zA-Z0-9_\\-]{10,}\\.[a-zA-Z0-9_\\-]{10,})\\b/[REDACTED_JWT]/g;
      s/\\b(sk_(?:live|test)_[A-Za-z0-9]{10,})\\b/[REDACTED_STRIPE]/g;
      s/\\b(ghp_[A-Za-z0-9]{20,})\\b/[REDACTED_GITHUB]/g;
      s/\\b([A-Za-z0-9_\\-]{40,})\\b/[REDACTED_TOKEN]/g;
    }
  else
    cat
  fi
}

clip_payload() {
  if [ -x ./FERM_RUNBOOK.sh ]; then
    ./FERM_RUNBOOK.sh clip -
    return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
    return 0
  fi
  return 1
}

emit_tree() {
  echo "== DIRECTORY TREE (depth 3; exclusions) =="
  if command -v tree >/dev/null 2>&1; then
    tree -a -L 3 -I ".git|node_modules|.next|dist|build|.cache|.turbo|coverage|_old|*.log|.env|.env.*|*secret*|*token*|*key*|*credential*|*password*|*pem|*p12|*keystore*" 2>/dev/null || true
    return 0
  fi

  find . -maxdepth 3 \( -type d -o -type f \) 2>/dev/null \
    | grep -Eav "${REDACT_PATH_RE}" \
    | sed "s#^\\./##" \
    | sort \
    | head -n 350 || true
}

{
  echo "BEGINSTARTUP: ${ts}"
  echo "ROOT: ${ROOT}"
  echo

  echo "== ETHOS / HARD RULES =="
  cat <<\EOF- No nano.
- Always cat full file before changes.
- Back up to _old/ with timestamp before edits.
- No partial edits: whole-file overwrite via heredoc.
- Add SECTION INDEX + SECTION/ENDSECTION markers for large files.
- Run sanity checks (node --check / python -m json.tool as applicable).
- Run shell-leak grep to ensure no terminal junk pasted into files.
- Update CHECKSUMS.sha256 for every touched file and verify with sha256sum -c.
- Do not include placeholders inside runnable code blocks.
EOF
  echo

  echo "== STARTUP_PAYLOAD_OLD (previous session) =="
  if [ -f ./FERM_RUNBOOK_SH/_startup_payload.old.txt ]; then
    sed -n "1,220p" ./FERM_RUNBOOK_SH/_startup_payload.old.txt || true
  else
    echo "(none)"
  fi
  echo

  echo "== STARTUP_PAYLOAD_NEW (most recent exit) =="
  if [ -f ./FERM_RUNBOOK_SH/_startup_payload.new.txt ]; then
    sed -n "1,260p" ./FERM_RUNBOOK_SH/_startup_payload.new.txt || true
  else
    echo "(none)"
  fi
  echo

  echo "== GIT SNAPSHOT =="
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    echo "commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo
    echo "-- status (filtered) --"
    git status --porcelain=v1 2>/dev/null | grep -Eav "${REDACT_PATH_RE}" || true
    echo
    echo "-- recent commits --"
    git --no-pager log -n 8 --oneline 2>/dev/null || true
  else
    echo "NOT_A_GIT_REPO"
  fi
  echo

  emit_tree
  echo

  echo "== PROJECT_STATE.md (head 80) =="
  if [ -f PROJECT_STATE.md ]; then
    head -n 80 PROJECT_STATE.md || true
  else
    echo "PROJECT_STATE.md not found"
  fi
  echo

  echo "== RUNBOOK.md (head 60) =="
  if [ -f RUNBOOK.md ]; then
    head -n 60 RUNBOOK.md || true
  else
    echo "RUNBOOK.md not found"
  fi
  echo

  echo "ENDSTARTUP: ${ts}"
} > "$tmp"

cat "$tmp" | redact_payload > "$tmp2"

if cat "$tmp2" | clip_payload; then
  echo "OK: startup packet copied to clipboard ($(wc -c < "$tmp2" | tr -d " ") bytes)"
else
  echo "WARN: clipboard tool not found; printing packet to stdout"
  cat "$tmp2"
fi

rm -f "$tmp" "$tmp2"
""", encoding="utf-8")

exitsh.write_text(r"""#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

tmp="$(mktemp)"
tmp2="$(mktemp)"
ts="$(date -Is)"

newp="./FERM_RUNBOOK_SH/_startup_payload.new.txt"
oldp="./FERM_RUNBOOK_SH/_startup_payload.old.txt"

REDACT_PATH_RE="(^|/)(\\.git(/|$)|node_modules(/|$)|\\.next(/|$)|dist(/|$)|build(/|$)|\\.cache(/|$)|\\.turbo(/|$)|coverage(/|$)|_old(/|$)|\\.env($|\\.)|\\.env\\..*|secrets?\\b|secret\\b|tokens?\\b|api[_-]?keys?\\b|keys?\\b|credentials?\\b|passwords?\\b|passwd\\b|private\\b|id_rsa\\b|pem\\b|p12\\b|keystore\\b)"

redact_payload() {
  if command -v perl >/dev/null 2>&1; then
    perl -pe q{
      s/^((?:OPENAI|SUPABASE|STRIPE|JWT|OAUTH|GOOGLE|AWS|AZURE|GCP|SENTRY|SENDGRID|MAILGUN|TWILIO|GITHUB|NPM|CLOUDFLARE|DATABASE|DB|POSTGRES|PG|REDIS|SMTP)[A-Z0-9_\\-]*\\s*=)\\s*.+$/$1 [REDACTED]/i;
      s/\\b(eyJ[a-zA-Z0-9_\\-]{10,}\\.[a-zA-Z0-9_\\-]{10,}\\.[a-zA-Z0-9_\\-]{10,})\\b/[REDACTED_JWT]/g;
      s/\\b(sk_(?:live|test)_[A-Za-z0-9]{10,})\\b/[REDACTED_STRIPE]/g;
      s/\\b(ghp_[A-Za-z0-9]{20,})\\b/[REDACTED_GITHUB]/g;
      s/\\b([A-Za-z0-9_\\-]{40,})\\b/[REDACTED_TOKEN]/g;
    }
  else
    cat
  fi
}

clip_payload() {
  if [ -x ./FERM_RUNBOOK.sh ]; then
    ./FERM_RUNBOOK.sh clip -
    return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
    return 0
  fi
  return 1
}

rotate_payloads() {
  mkdir -p ./FERM_RUNBOOK_SH
  if [ -f "$newp" ]; then
    mv -f "$newp" "$oldp"
  fi
}

make_new_payload() {
  {
    echo "SESSION_PAYLOAD_NEW: ${ts}"
    echo "ROOT: ${ROOT}"
    echo

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "GIT:"
      echo "  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
      echo "  commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
      echo

      echo "CHANGES (filtered status):"
      git status --porcelain=v1 2>/dev/null | grep -Eav "${REDACT_PATH_RE}" || true
      echo

      echo "DIFFSTAT (working tree vs HEAD):"
      git --no-pager diff --stat 2>/dev/null | head -n 80 || true
      echo

      echo "RECENT COMMITS:"
      git --no-pager log -n 10 --oneline 2>/dev/null || true
      echo
    else
      echo "GIT: NOT_A_GIT_REPO"
      echo
    fi

    echo "KEY FILE HEADS:"
    if [ -f PROJECT_STATE.md ]; then
      echo "--- PROJECT_STATE.md (head 60) ---"
      head -n 60 PROJECT_STATE.md || true
      echo
    else
      echo "--- PROJECT_STATE.md not found ---"
      echo
    fi

    if [ -f RUNBOOK.md ]; then
      echo "--- RUNBOOK.md (head 40) ---"
      head -n 40 RUNBOOK.md || true
      echo
    else
      echo "--- RUNBOOK.md not found ---"
      echo
    fi

    if [ -f CHECKSUMS.sha256 ]; then
      echo "--- CHECKSUMS.sha256 (head 40) ---"
      head -n 40 CHECKSUMS.sha256 || true
      echo
    else
      echo "--- CHECKSUMS.sha256 not found ---"
      echo
    fi

    echo "AUTO_NEXT_STEPS (heuristic):"
    echo "- Review git status items above and decide what must be committed."
    echo "- If CHECKSUMS.sha256 exists, run sumcheck/sha256 verification."
    echo "- Update PROJECT_STATE.md next steps if scope changed."
    echo "- Run server/tests if relevant to changes in diffstat."
    echo
  } | redact_payload
}

{
  echo "BEGINEXIT: ${ts}"
  echo "ROOT: ${ROOT}"
  echo

  echo "== ROTATE STARTUP PAYLOADS (NEW->OLD) =="
  rotate_payloads
  echo "ok"
  echo

  echo "== WRITE NEW STARTUP PAYLOAD (auto) =="
  make_new_payload > "$newp"
  echo "wrote: $newp ($(wc -c < "$newp" | tr -d " ") bytes)"
  echo

  echo "== OPTIONAL HYGIENE =="
  if [ -x ./FERM_RUNBOOK.sh ]; then
    ./FERM_RUNBOOK.sh sumcheck >/dev/null 2>&1 || true
    echo "sumcheck: ran (details suppressed)"
  else
    echo "FERM_RUNBOOK.sh missing/not executable (skipping sumcheck)"
  fi
  echo

  echo "ENDEXIT: ${ts}"
} > "$tmp"

cat "$tmp" | redact_payload > "$tmp2"

if cat "$tmp2" | clip_payload; then
  echo "OK: exit packet copied to clipboard ($(wc -c < "$tmp2" | tr -d " ") bytes)"
else
  echo "WARN: clipboard tool not found; printing packet to stdout"
  cat "$tmp2"
fi

rm -f "$tmp" "$tmp2"
""", encoding="utf-8")

if not newp.exists():
  newp.write_text("SESSION_PAYLOAD_NEW: (none yet)\nRun ./FERM_RUNBOOK_SH/91_exit.sh to generate.\n", encoding="utf-8")
if not oldp.exists():
  oldp.write_text("SESSION_PAYLOAD_OLD: (none yet)\n", encoding="utf-8")
PY
