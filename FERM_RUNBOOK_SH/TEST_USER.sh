#!/usr/bin/env bash
# TEST_USER.sh — generates a one-shot “sumcheck” JSON for handshake Phase 1b
# Writes /tmp/test_user_sumcheck.json (always), then tries clipboard copy.

set -euo pipefail

# Refuse to be sourced (prevents killing an interactive shell)
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  echo "ERROR: Do not source this script. Run it as: ./scripts/TEST_USER.sh" >&2
  return 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1" >&2; exit 1; }; }

need node
need python3
need curl

# Clipboard helper (non-fatal)
clip_maybe() {
  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard < "$1" || true
    xclip -selection primary  < "$1" || true
    return 0
  fi
  return 0
}
DEFAULT_EMAIL="atvanwart@gmail.com"
DEFAULT_PASS="testuser"

EMAIL="${1:-$DEFAULT_EMAIL}"
PASS="${2:-$DEFAULT_PASS}"

# Load env via node (no secrets printed)
SUPABASE_URL="$(node -e "require('dotenv').config({path:'.env'}); process.stdout.write((process.env.SUPABASE_URL||'').trim())")"
SUPABASE_ANON_KEY="$(node -e "require('dotenv').config({path:'.env'}); process.stdout.write((process.env.SUPABASE_ANON_KEY||'').trim())")"

[ -n "$SUPABASE_URL" ] || { echo "ERROR: SUPABASE_URL missing in .env" >&2; exit 1; }
[ -n "$SUPABASE_ANON_KEY" ] || { echo "ERROR: SUPABASE_ANON_KEY missing in .env" >&2; exit 1; }

# Pick a random join_code from courses.json
COURSE_SLUG="$(python3 - <<'PY'
import json, random
with open("courses.json","r",encoding="utf-8") as f:
    d=json.load(f)
codes=[]
if isinstance(d, dict):
    # common formats:
    # 1) dict of courses keyed by slug
    # 2) dict with "courses": [...]
    if "courses" in d and isinstance(d["courses"], list):
        for c in d["courses"]:
            if isinstance(c, dict) and c.get("join_code"):
                codes.append(str(c["join_code"]).strip())
    else:
        for _, c in d.items():
            if isinstance(c, dict) and c.get("join_code"):
                codes.append(str(c["join_code"]).strip())
elif isinstance(d, list):
    for c in d:
        if isinstance(c, dict) and c.get("join_code"):
            codes.append(str(c["join_code"]).strip())

codes=[c for c in codes if c]
if not codes:
    raise SystemExit("NO_JOIN_CODES")
print(random.choice(codes))
PY
)" || true

if [ "$COURSE_SLUG" = "NO_JOIN_CODES" ] || [ -z "${COURSE_SLUG:-}" ]; then
  OUT="/tmp/test_user_sumcheck.json"
  printf '%s\n' '{"ok":false,"error":"No join_code values found in courses.json."}' > "$OUT"
  cat "$OUT"
  clip_maybe "$OUT"
  echo "Wrote $OUT"
  exit 1
fi

# Supabase password login via GoTrue REST
LOGIN_JSON="$(curl -sS -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")"

ACCESS_TOKEN="$(python3 - <<'PY'
import json,sys
try:
    d=json.loads(sys.stdin.read())
except Exception:
    print("",end=""); sys.exit(0)
print(d.get("access_token",""),end="")
PY
<<<"$LOGIN_JSON")"

USER_ID="$(python3 - <<'PY'
import json,sys
try:
    d=json.loads(sys.stdin.read())
except Exception:
    print("",end=""); sys.exit(0)
u=d.get("user") or {}
print(u.get("id",""),end="")
PY
<<<"$LOGIN_JSON")"

LOGIN_OK="false"
if [ -n "${ACCESS_TOKEN:-}" ] && [ -n "${USER_ID:-}" ]; then
  LOGIN_OK="true"
fi

# If login failed, still write sumcheck and exit
OUT="/tmp/test_user_sumcheck.json"
if [ "$LOGIN_OK" != "true" ]; then
  python3 - <<'PY' > "$OUT"
import json,sys,datetime
raw=sys.stdin.read()
try:
    d=json.loads(raw)
except Exception:
    d={"raw":raw}
print(json.dumps({
  "ok": False,
  "stage": "login",
  "email": "atvanwart@gmail.com",
  "course_slug_selected": None,
  "error": d.get("error_description") or d.get("error") or "Login failed (no access_token).",
  "time": datetime.datetime.utcnow().isoformat()+"Z"
}, indent=2))
PY
  cat "$OUT"
  clip_maybe "$OUT"
  echo "Wrote $OUT"
  exit 1
fi

# Call local handshake init
INIT_JSON="$(curl -sS -X POST "http://localhost:3000/handshake/init" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"course_slug\":\"$COURSE_SLUG\"}")"

# Build sumcheck
python3 - <<'PY' > "$OUT"
import json,datetime,sys
init_raw=sys.argv[1]
login_raw=sys.argv[2]
course_slug=sys.argv[3]
user_id=sys.argv[4]
ok_login=True

try:
    init=json.loads(init_raw)
except Exception:
    init={"ok":False,"error":"handshake_init response not valid JSON","raw":init_raw}

try:
    login=json.loads(login_raw)
except Exception:
    login={"raw":login_raw}

alias=init.get("alias_code")
expires=init.get("expires_at")

out={
  "ok": True,
  "stage": "handshake_init",
  "course_slug_selected": course_slug,
  "user_id": user_id,
  "login": {
    "ok": ok_login,
    "has_access_token": True
  },
  "handshake_init": {
    "ok": init.get("ok", False),
    "alias_code_present": bool(alias),
    "expires_at_present": bool(expires),
    "response": init
  },
  "time": datetime.datetime.utcnow().isoformat()+"Z"
}
print(json.dumps(out, indent=2))
PY "$INIT_JSON" "$LOGIN_JSON" "$COURSE_SLUG" "$USER_ID"

cat "$OUT"
clip_maybe "$OUT"
echo "Wrote $OUT"
