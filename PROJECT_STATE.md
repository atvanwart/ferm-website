# Fermentors Project State

This file is the single source of truth for:
- where we are
- how we safely change things
- how we share code between your terminal and ChatGPT without corruption

---

## SOP: How we edit files (do this every time)

Add-on: before/after any change, run `./scripts/FERM_RUNBOOK.sh sumcheck` (clipboard-first signal).

### Non-negotiables
1) Never use nano.
2) Never edit in fragments. Always overwrite the whole file via heredoc.
3) Always back up the old file first into `_old/` with a timestamp.
4) Never paste secrets into chat (.env, tokens, passwords). If you must show `.env`, redact values.
5) **Never paste angle-bracket placeholders** (e.g., `<TOKEN>`, `<your entire file>`). Those are instructions, not literal content.

### Standard edit workflow (every change)
1) Decide which file(s) change (keep scope small).
2) Read the *current* file(s) first:
   - Prefer `./scripts/FERM_RUNBOOK.sh pack <files> | ./scripts/FERM_RUNBOOK.sh clip -` (clipboard-first)
   - Or `cat path/to/file` (fallback)
3) Backup:
   - `cp -a file "_old/file.$TS"`
4) Overwrite whole file:
   - `cat > file <<'EOF' ... EOF`
5) Run sanity checks:
   - JS: `node --check file.js`
   - JSON: `python3 -m json.tool < file.json >/dev/null`
   - “shell leak” scan (should print nothing):
     `./scripts/FERM_RUNBOOK.sh shell-leak file || true`
6) Update + verify checksums:
   - `./scripts/FERM_RUNBOOK.sh checksum`
   - `./scripts/FERM_RUNBOOK.sh verify`

---

## Collaboration contract (how ChatGPT must respond)

When you ask ChatGPT to change code, ChatGPT should:
- Provide a **single copy/paste block** of terminal commands that:
  1) `cd` into the repo
  2) backs up files to `_old/`
  3) overwrites whole files via heredoc
  4) runs sanity checks
  5) runs `./scripts/FERM_RUNBOOK.sh checksum` and `verify`

**Hard rule:** before any heredoc/overwrite commands, ChatGPT must first request (and receive) the **exact current file contents or exact variables** needed. ChatGPT must never include angle-bracket placeholders inside terminal commands.

When ChatGPT needs code context, ChatGPT should ask you to run one of:
- Canonical bundle:
  - `./scripts/FERM_RUNBOOK.sh pack-core | ./scripts/FERM_RUNBOOK.sh clip -`
- Specific files:
  - `./scripts/FERM_RUNBOOK.sh pack server.js src/autopurge.js | ./scripts/FERM_RUNBOOK.sh clip -`

Then you paste the clipboard contents into chat.

---

## Clipboard-first sharing (preferred)

### X11 (your current setup)
- Use xclip via:
  - `./scripts/FERM_RUNBOOK.sh clip <file>`
  - `./scripts/FERM_RUNBOOK.sh clip -` (stdin)
  - `./scripts/FERM_RUNBOOK.sh clipout` (paste clipboard to terminal)

### Wayland (fallback if you switch later)
- Script will use wl-copy / wl-paste if installed.

### Clipboard quick-test
- `echo "CLIP_TEST $(date)" | ./scripts/FERM_RUNBOOK.sh clip -`
- `./scripts/FERM_RUNBOOK.sh clipout`
- `./scripts/FERM_RUNBOOK.sh clipout | wc -c`  (should be > 0 and match expectation)

### IMPORTANT
- The script refuses `.env` and other secret-like filenames.

---

## Code organization rules

### SECTION INDEX + markers
- Large code files must have a SECTION INDEX at the top and markers around logical blocks:

// SECTION INDEX
// 1) ...
// === SECTION: NAME ===
// ...
// === ENDSECTION: NAME ===

- Submodules in `src/` can have their own subsection index.

### Prefer small files over giant files
- UI: keep split into HTML/CSS/JS.
- Backend: keep logic in `src/*`, keep `server.js` as orchestrator.

---

## Current endpoints (backend)

### Admin auth
- Basic Auth protects:
  - `/admin/*`

### Admin UI (static)
- `/admin/ui/` -> serves `admin/` folder

### Courses
- `GET /admin/api/courses`

### Sync / Purge / Reset
- `POST /admin/jobs/sync/:slug`
- `GET  /admin/jobs/purge/:slug` (dry run)
- `POST /admin/jobs/purge/:slug` body: {"confirm":"PURGE"}
- `POST /admin/jobs/reset_week/:slug` body: {"confirm":"RESET"}

### Autopurge (one-shot scheduler)
- `GET  /admin/api/autopurge/:slug` (includes server_now)
- `POST /admin/api/autopurge/:slug` body: {"enabled": true/false, "run_at": "ISO datetime"}

---

## Handshake identity model (Fermentors ↔ Canvas) (planned)

### Goal
- Fermentors.org will maintain the **real student account** (email + personal info) and all analytics/progress.
- Canvas will be used as a **pseudonymous classroom shell** (no real student identity stored in Canvas).
- We link Canvas activity to the Fermentors account using a **Fermentors-generated identifier**, submitted by the student inside Canvas.

### Student-facing privacy rule (explicit warning)
- **Do not use your real name in Canvas** for Fermentors courses.
- Use the **Fermentors-provided alias** (and, if desired, a separate email address that is not your primary identity).
- Your “real” identity and dashboard live on Fermentors.org, not in Canvas.

### Handshake steps (exact flow)
0) Student creates/has a Fermentors.org account (Supabase Auth).
1) Fermentors generates a **one-time verification code** for:
   - (fermentors_user_id, course_slug)
2) Student self-enrolls in Canvas via:
   - `/enroll/:slug` (redirects to Canvas enroll URL)
3) Student submits the verification code into the Canvas **verification assignment** for that course.
4) Fermentors admin “sync” job pulls Canvas:
   - enrollments
   - verification assignment submissions
   Then links:
   - (course_slug, canvas_user_id) → fermentors_user_id
5) Fermentors stores progress/metrics **only on Fermentors** and presents it in the student dashboard.

### Non-negotiables
- Store verification codes **hashed at rest** (do not store raw codes long-term).
- Codes must be **one-time use** and **expire** (e.g., 24h).
- Canvas identifiers (canvas_user_id, enrollment_id) are treated as **pseudonymous** data.
- Fermentors must never push student PII into Canvas.

### Handshake data model (logical tables)
Fermentors DB (Supabase/Postgres) should support these entities:

1) `profiles`
- `user_id` (uuid, PK, references auth.users)
- `display_name` (text, optional)
- other Fermentors-side fields as needed (this is where PII lives)

2) `course_memberships`
- `id` (uuid, PK)
- `user_id` (uuid, FK → profiles.user_id)
- `course_slug` (text)
- `alias` (text, pseudonymous “Fermentors alias” shown to student)
- unique: (`user_id`, `course_slug`)
- unique: (`course_slug`, `alias`)  [optional but recommended]

3) `verification_tokens`
- `id` (uuid, PK)
- `user_id` (uuid)
- `course_slug` (text)
- `token_hash` (text/bytea)
- `created_at`, `expires_at`, `used_at`
- `used_canvas_user_id` (bigint, nullable)
- `used_canvas_submission_id` (bigint, nullable)
- Purpose: student submits raw token in Canvas; Fermentors matches by hash and then marks used.

4) `canvas_links`
- `id` (uuid, PK)
- `course_slug` (text)
- `canvas_user_id` (bigint)
- `fermentors_user_id` (uuid)
- `linked_at` (timestamptz)
- unique: (`course_slug`, `canvas_user_id`)
- unique: (`course_slug`, `fermentors_user_id`)  [optional; depends on whether one Canvas account can span multiple Fermentors users (should not)]

5) `progress_snapshots` (optional v1)
- `id` (uuid, PK)
- `course_slug` (text)
- `user_id` (uuid)
- `as_of` (timestamptz)
- `metrics` (jsonb)

### Note on “Fermentor bot” accounts
- We can maintain internal/test Fermentors accounts that enroll in Canvas as pseudo-students for QA.
- These are treated as protected users and excluded from purge.

---

## Files we expect to exist

### Backend (orchestrator + modules)
- `server.js` (thin orchestrator; routes + wiring)
- `src/jsonStore.js`
- `src/courses.js`
- `src/canvas.js`
- `src/autopurge.js`
- `courses.json`
- `autopurge.json`

### Admin UI (split)
- `admin/index.html`  (shell)
- `admin/ui.html`     (layout/markup)
- `admin/ui.css`      (styles)
- `admin/ui.js`       (logic)

### Runbook tooling
- `RUNBOOK.md`
- `scripts/FERM_RUNBOOK.sh`

### Integrity
- `CHECKSUMS.sha256`

---

## Known risks / failure modes
- Heredoc delimiter mistakes (`EOF`) or quote mismatches.
- Accidental terminal output pasted into a heredoc (mitigated by “shell leak” grep + bundling).
- Secrets leaking via `.env` (highest-risk item).
- Canvas permissions: certain enrollments may block delete/conclude.
  - Mitigations: protected user IDs + conclude fallback + treat partial failures as expected/visible.

---

## Phase 1A — Canvas ↔ Fermentors Handshake Binding (SPEC)

### Goal
Bind Canvas activity to a Fermentors user **without ever sending real identity to Canvas**.

Canvas only sees:
- a Canvas user_id (pseudonymous)
- a Canvas submission
- an alias_code entered by the student

Fermentors stores:
- real user identity (Supabase auth)
- alias_code → user_id mapping
- progress events derived from Canvas activity

---

### Invariants (must never break)

1. Canvas must never receive:
   - real names
   - real emails
   - Fermentors user_id
2. alias_code is:
   - generated by Fermentors
   - course-scoped
   - single-use for binding
3. All Canvas → Fermentors writes occur **server-side only**
   using Supabase **service role**.
4. RLS is enforced for user reads; service role bypasses for writes.
5. No polling from Canvas; binding is pull-based by Fermentors admin job.

---

### Entities (authoritative)

**course_handshakes**
- user_id (uuid, Supabase)
- course_slug (text)
- alias_code (text)
- created_at
- bound_at (null until matched)

**canvas_bindings**
- handshake_id
- course_slug
- canvas_course_id
- canvas_user_id
- canvas_submission_id
- submitted_at

**progress_events**
- user_id
- course_slug
- event_type
- event_payload
- occurred_at

---

### Binding Flow (happy path)

1. User signs up / logs in to Fermentors.
2. Fermentors generates alias_code for (user, course).
3. User pastes alias_code into Canvas verification assignment.
4. Admin runs sync job.
5. Server:
   - fetches Canvas submissions
   - extracts text body
   - matches alias_code
6. On match:
   - insert canvas_bindings
   - set course_handshakes.bound_at
7. From this point forward:
   - Canvas user_id ↔ Fermentors user_id is linked
   - progress_events may be recorded

---

### Failure Modes (explicit)

- **Alias not found**
  → no write, no partial state
- **Alias reused**
  → rejected by unique(handshake_id)
- **Multiple submissions**
  → first valid submission wins
- **Canvas API failure**
  → no DB writes
- **User deletes submission**
  → binding remains (audit trail)

---

### Non-Goals (Phase 1A)

- No real-time webhooks
- No Canvas LTI
- No grade writes back to Canvas
- No instructor-side manual binding
- No alias regeneration after binding

---

### Forward Compatibility

Phase 1B+
- progress rollups
- per-module completion
- optional Canvas rubric reads
- external LMS support

All future phases must preserve Phase 1A invariants.

---

