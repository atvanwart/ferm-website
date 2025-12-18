# Fermentors Runbook (local dev)

This is the “do the obvious thing” command list. Keep it short and reliable.

---

## Integrity / sanity (recommended workflow)

### One-shot sum check (clipboard-first, signal-only)
Runs core checks, regenerates checksums, verifies integrity, and writes a **minimal git summary**.
Full output is copied to your clipboard.

./scripts/FERM_RUNBOOK.sh sumcheck

### Git audit (noisy, terminal-first)
Shows full git status + diff stats + docs diff.

./scripts/FERM_RUNBOOK.sh git-audit

---

## Session startup (persona-aware, clipboard-first)

### Generate startup context (recommended default)
Emits the full, **persona-aware startup bundle** (base → persona delta → memory artifacts)
and copies it directly to your clipboard for pasting into chat.

./scripts/FERM_RUNBOOK.sh startup-clip [alden|spark]

If no persona is specified, `alden` is used by default.

### Generate startup context (terminal output)
Same as above, but prints to the terminal instead of copying to clipboard.

./scripts/FERM_RUNBOOK.sh startup [alden|spark]

---

## Start / Stop

### Start server
cd ~/Adam_Van_Wart/fermentors/ferm-website
node server.js

### View site
./scripts/FERM_RUNBOOK.sh open

---

## Admin operations (uses .env credentials internally)

### Health
./scripts/FERM_RUNBOOK.sh health

### UI smoke test
./scripts/FERM_RUNBOOK.sh ui-smoke

### List courses
./scripts/FERM_RUNBOOK.sh courses

---

## Integrity primitives

### JS syntax
./scripts/FERM_RUNBOOK.sh check-js

### JSON validation
./scripts/FERM_RUNBOOK.sh check-json

### Shell-leak scan
./scripts/FERM_RUNBOOK.sh shell-leak server.js

### Checksums
./scripts/FERM_RUNBOOK.sh checksum
./scripts/FERM_RUNBOOK.sh verify

---

## Sharing with ChatGPT (clipboard-first)

### Copy canonical debug bundle to clipboard
./scripts/FERM_RUNBOOK.sh packclip-core

### Pack specific files
./scripts/FERM_RUNBOOK.sh packclip server.js src/autopurge.js src/canvas.js

### Clipboard quick-test
echo "CLIP_TEST $(date)" | ./scripts/FERM_RUNBOOK.sh clip -
./scripts/FERM_RUNBOOK.sh clipout
./scripts/FERM_RUNBOOK.sh clipout | wc -c

---

## Phase 1: Handshake binding (Canvas UI → Fermentors Core)

### Source of truth
The Phase 1A handshake binding spec is maintained in:
PROJECT_STATE.md (Phase 1A: Handshake Binding Spec)

RUNBOOK.md stays operational (commands + safe sharing patterns), not the full spec.

### Pack the handshake context (clipboard-first)
Use this when we are about to implement or review handshake endpoints and DB mapping.

./scripts/FERM_RUNBOOK.sh packclip \
  supabase/migrations/20251216013449_handshake_model.sql \
  server.js \
  src/canvas.js \
  src/services/canvas.js \
  src/courses.js \
  src/jsonStore.js \
  admin/ui.js

Then paste from clipboard into chat:
./scripts/FERM_RUNBOOK.sh clipout

### Minimal Supabase Auth sanity (no secrets echoed)
Confirms your SUPABASE_URL + SUPABASE_ANON_KEY can reach GoTrue.

node -e "require('dotenv').config(); const u=process.env.SUPABASE_URL; const k=process.env.SUPABASE_ANON_KEY; fetch(u+'/auth/v1/health',{headers:{apikey:k}}).then(async r=>console.log('auth health',r.status,(await r.text()).slice(0,200))).catch(e=>console.error('fetch_err',e.message));"

### Local server smoke (signup/login)
Note: signup will send a confirmation email unless Supabase email confirmations are disabled.

curl -sS -X POST "http://localhost:3000/signup" \
  -H "Content-Type: application/json" \
  -d '{"email":"test+handshake@yourdomain.com","password":"Use-A-Strong-Test-Password-Here"}' | python3 -m json.tool

curl -sS -X POST "http://localhost:3000/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test+handshake@yourdomain.com","password":"Use-A-Strong-Test-Password-Here"}' | python3 -m json.tool

---

## Handshake debug (no scrolling)

### Quick “is the endpoint alive?”
curl -sS -i http://localhost:3000/handshake/preview | head -n 40

### If /handshake/preview is 404, you’re probably hitting an old server PID
Use this to kill the node process that is actually listening on :3000, then restart:

cd ~/Adam_Van_Wart/fermentors/ferm-website
PID_LISTEN="$(ss -ltnp 2>/dev/null | awk '/:3000/ && /users:\(\("node"/ { if (match($0,/pid=([0-9]+)/,m)) { print m[1]; exit } }')"
echo "pid_listen=${PID_LISTEN:-none}"
if [ -n "${PID_LISTEN:-}" ]; then kill "$PID_LISTEN" 2>/dev/null || true; sleep 1; kill -9 "$PID_LISTEN" 2>/dev/null || true; fi
nohup node server.js > server.log 2>&1 & echo $! > .fermentors-server.pid
sleep 1
ss -ltnp | grep ':3000' || true

### Clipboard-first: capture debug output (recommended)
# Use the debug block in chat to write output to /tmp/... then:
./scripts/FERM_RUNBOOK.sh clip /tmp/ferm_handshake_debug.txt

---

## Safety Rules for Shell Usage

### Hard rule: state capture & reviewability

- All state-changing or state-defining actions must end with an X11 clipboard artifact (via xclip), so the resulting state can always be re-presented verbatim for later review.
- Clipboard capture is mandatory; pasting is optional.
- If no clipboard artifact exists, the state is not governed and must not be trusted, committed, or tagged.


### Output capture and verification

- For any multi-step commands, capture output and copy to X11 clipboard for review.
- Use `FERM_RUNBOOK_SH/20.run_and_clip.sh` to run commands and auto-copy logs.
- If a built-in gate exists (e.g., `./FERM_RUNBOOK.sh verify`, checksum verification), still capture and share the verify output.


### Never kick the operator out of their shell

- Do not paste or advise set -euo pipefail to be run directly in an interactive shell.
- Wrap strict multi-step work in a child shell: bash -lc "...".
- Do not use exit in operator-facing paste blocks.
- Prefer repo scripts (in FERM_RUNBOOK_SH/) that run in their own process.


### Hard rule: stay in the bash console

- Never instruct the operator to exit/close/leave their current bash session.
- If you need a clean context, ask for a separate terminal tab/window.


### Interactive Shell Rules
- Never run `set -e`, `set -u`, or `set -o pipefail` in an interactive shell.
- Never combine environment mutation and execution in a single command.
- If strict mode is required, use a subshell:
  `( set -euo pipefail; ./script.sh )`

### Script Rules
- All scripts must:
  - include a shebang
  - refuse to be sourced
  - write outputs to disk before optional side effects
- Clipboard operations are always best-effort and non-fatal.

### Prohibited Patterns
- One-liner pipelines that:
  - write files
  - modify `.env`
  - start or stop servers
  - mutate database state
- Silent failures hidden behind `|| true` unless explicitly justified.
