from pathlib import Path
import re

p = Path("FERM_RUNBOOK_SH/90_startup.sh")
txt = p.read_text(encoding="utf-8")

# Remove any existing appended log block
txt = re.sub(
    r"\n# --- Append latest RUN_AND_CLIP log \(X11-only\) ---.*?# --- End latest RUN_AND_CLIP log ---\n\n*",
    "\n",
    txt,
    flags=re.S
)

inject = """\n\n# --- Append latest RUN_AND_CLIP log (X11-only) ---\nLAST_RUN_LOG=""\nif [ -d "_drive_stage/runlogs" ]; then\n  LAST_RUN_LOG="_drive_stage/runlogs/run.20251218T001717-0600.log"\nfi\n\nif [ -n "_drive_stage/runlogs/run.20251218T001034-0600.log" ] && [ -f "_drive_stage/runlogs/run.20251218T001034-0600.log" ]; then\n  echo\n  echo "=== LAST_RUN_AND_CLIP_LOG ==="\n  echo "FILE: _drive_stage/runlogs/run.20251218T001034-0600.log"\n  echo "--- BEGIN ---"\n  tail -n 220 "_drive_stage/runlogs/run.20251218T001034-0600.log" || true\n  echo "--- END ---"\nfi\n# --- End latest RUN_AND_CLIP log ---\n"""\n
m = re.search(r^echo
