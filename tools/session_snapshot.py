#!/usr/bin/env python3
from future import annotations

import argparse
import datetime as _dt
import os
import subprocess
import sys
from pathlib import Path
import re

ROOT = Path(file).resolve().parent.parent

INCLUDES_LIST = ROOT / "FERM_RUNBOOK_SH" / "startup_includes.txt"

Runtime scripts that must obey rules

RUNTIME_SCRIPTS = [
ROOT / "FERM_RUNBOOK_SH" / "90_startup.sh",
ROOT / "FERM_RUNBOOK_SH" / "91_exit.sh",
ROOT / "FERM_RUNBOOK.sh",
]

Policy: runtime scripts must not use heredocs or Wayland clipboard tools or wrapper clip calls.

BANNED_PATTERNS: list[tuple[re.Pattern, str]] = [
(re.compile(r"<<\s*['"]?\w+"), "heredoc is forbidden in runtime scripts"),
(re.compile(r"\bwl-copy\b"), "wl-copy forbidden"),
(re.compile(r"\bwl-paste\b"), "wl-paste forbidden"),
(re.compile(r"./FERM_RUNBOOK.sh\s+clip\b"), "runbook clip wrapper forbidden in runtime scripts (use xclip directly)"),
]

DEFAULT_INCLUDES = [
"STRUCTURE.md",
"PROJECT_STATE.md",
"RUNBOOK.md",
"APPENDIX_MAP.md", # full
"FERM_RUNBOOK.sh",
"CHECKSUMS.sha256",
]

def run(cmd: list[str]) -> tuple[int, str]:
try:
p = subprocess.run(
cmd,
cwd=str(ROOT),
stdout=subprocess.PIPE,
stderr=subprocess.STDOUT,
text=True,
)
return p.returncode, p.stdout
except Exception as e:
return 1, f"ERROR running {cmd}: {e}\n"

def secret_like(p: Path) -> bool:
n = p.name
if n == ".env" or n.endswith(".env"):
return True
if any(x in n for x in ["id_rsa", ".pem", ".key"]):
return True
return False

def head_text(p: Path, nlines: int = 200) -> str:
try:
with p.open("r", encoding="utf-8", errors="replace") as f:
out: list[str] = []
for _ in range(nlines):
line = f.readline()
if not line:
break
out.append(line)
return "".join(out).rstrip("\n")
except FileNotFoundError:
return ""

def full_text(p: Path) -> str:
try:
return p.read_text(encoding="utf-8", errors="replace").rstrip("\n")
except FileNotFoundError:
return ""

def load_includes() -> list[str]:
if INCLUDES_LIST.exists():
out: list[str] = []
for ln in INCLUDES_LIST.read_text(encoding="utf-8", errors="replace").splitlines():
ln = ln.strip()
if not ln or ln.startswith("#"):
continue
out.append(ln)
return out
return DEFAULT_INCLUDES[:]

def audit_runtime_rules() -> tuple[bool, str]:
problems: list[str] = []
for p in RUNTIME_SCRIPTS:
if not p.exists():
problems.append(f"- {p.relative_to(ROOT)}: missing")
continue
txt = p.read_text(encoding="utf-8", errors="replace")
for rx, why in BANNED_PATTERNS:
if rx.search(txt):
problems.append(f"- {p.relative_to(ROOT)}: {why}")
ok = (len(problems) == 0)
if ok:
return True, "OK"
return False, "FAIL\n" + "\n".join(problems)

def snapshot(mode: str) -> str:
ts = _dt.datetime.now().astimezone().isoformat(timespec="seconds")
