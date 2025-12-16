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
