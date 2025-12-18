# Parking Lot


## Migration tracking (idea) — 20251217T220929-0600
- Add a dedicated migration checklist file (e.g., MIGRATIONS.md) with a stepwise “plan → execute → verify → commit” template.
- Add a runbook command to capture a migration snapshot (git status -s, git diff --stat, key file tree) into a timestamped log file.
- Enforce “migration = one commit series” discipline: label commits with a migration tag and include rollback notes.

## Hard rule: never kick the operator out of the bash console
- Never provide copy/paste commands that can terminate the operator’s shell session or disconnect them.
- Prohibited in paste blocks: `exit`, `logout`, `kill -KILL $$`, `exec $SHELL -c ...`, `reset`/terminal-control sequences, or anything that assumes it is safe to close the session.
- Avoid strict-mode preambles (`set -euo pipefail`) in copy/paste meant for interactive shells; if strict mode is needed, wrap in a subshell: `( set -euo pipefail; ... )`.
- Scripts must refuse to be sourced (so `exit` cannot kill the parent shell).

## Hard rule: all copy/paste blocks are bash-console runnable
- All assistant-provided copy blocks must be tagged as bash and runnable verbatim in a bash console.
- No placeholders, no “example” blocks that look runnable, and no mixed-language fences for terminal workflows.

## Hard Rule — Shell Safety (Non-Negotiable)

- Never exit, replace, or terminate the operator’s active bash console.
- No command, script, or copy-paste block may implicitly or explicitly kick the operator out of their shell.
- Prohibited in paste blocks: `exit`, `logout`, `exec $SHELL`, `kill -KILL $$`, terminal reset/control sequences.
- All fenced copy blocks must be runnable verbatim in a bash console.
- No placeholders, pseudo-code, or mixed-language snippets inside bash fences.
- Scripts must fail internally without terminating the parent shell.

## RB-GOV-01 — State Capture & Reviewability

**Rule:** Every state-changing or state-defining action must produce an X11 clipboard artifact (via `xclip`) so the resulting state can always be re-presented verbatim for later review.

**Invariants:**
- Clipboard capture is mandatory; pasting is optional.
- If no clipboard artifact exists, the state is not governed.
- Ungoverned state must not be trusted, committed, or tagged.

**Rationale:** ChatGPT has no durable memory of local execution. Clipboard artifacts preserve optional replay, auditability, and resistance to truncation or narrative drift.

**Enforcement:**
- Use `FERM_RUNBOOK_SH/20.run_and_clip.sh` (preferred) or `./tools/run_and_clip.sh`.
- Checksums/verify are acceptable only if their output is capturable.

