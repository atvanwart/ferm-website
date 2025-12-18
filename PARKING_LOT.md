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
