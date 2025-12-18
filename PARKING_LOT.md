# Parking Lot


## Migration tracking (idea) — 20251217T220929-0600
- Add a dedicated migration checklist file (e.g., MIGRATIONS.md) with a stepwise “plan → execute → verify → commit” template.
- Add a runbook command to capture a migration snapshot (git status -s, git diff --stat, key file tree) into a timestamped log file.
- Enforce “migration = one commit series” discipline: label commits with a migration tag and include rollback notes.
