#!/usr/bin/env python3
"""bashqueues cron bridge ticker.

Reads traditional cron-format files and submits matching entries as bashqueues jobs.
The ticker is intentionally queue-first: a due cron entry creates a queue job with
max-concurrent=1 class gating rather than running the command directly.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
import pwd
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple

DEFAULT_USER_SPOOL = "/var/spool/bashqueues_cron"
DEFAULT_SYSTEM_DIR = "/etc/bashqueues_cron.d"
DEFAULT_STATE_DIR = "/var/lib/bashqueues/cron"
DEFAULT_QUEUEBASH_SOURCE = "/usr/local/share/bashqueues/queuebash.sh"

MONTHS = {"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12}
DAYS = {"sun": 0, "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6}


def _expand_name(token: str, names: dict[str, int]) -> str:
    def repl(m: re.Match[str]) -> str:
        return str(names[m.group(0).lower()])
    return re.sub(r"[A-Za-z]{3}", repl, token)


def _match_field(expr: str, cur: int, lo: int, hi: int, names: Optional[dict[str, int]] = None) -> bool:
    expr = expr.strip().lower()
    if names:
        expr = _expand_name(expr, names)
    if expr == "*":
        return True
    for raw in expr.split(","):
        p = raw.strip()
        if not p:
            continue
        step = 1
        if "/" in p:
            p, step_s = p.split("/", 1)
            step = int(step_s)
            if step <= 0:
                return False
        if p == "*":
            start, end = lo, hi
        elif "-" in p:
            start_s, end_s = p.split("-", 1)
            start, end = int(start_s), int(end_s)
        else:
            start = end = int(p)
        if start <= cur <= end and (cur - start) % step == 0:
            return True
    return False


def should_run(parts: Sequence[str], dt: _dt.datetime) -> bool:
    minute, hour, dom, month, dow = parts[:5]
    if not _match_field(minute, dt.minute, 0, 59):
        return False
    if not _match_field(hour, dt.hour, 0, 23):
        return False
    if not _match_field(month, dt.month, 1, 12, MONTHS):
        return False

    dom_any = dom.strip() == "*"
    dow_any = dow.strip() == "*"
    dom_match = _match_field(dom, dt.day, 1, 31)
    # Python Monday=0. Cron Sunday=0 or 7.
    cron_dow = (dt.weekday() + 1) % 7
    dow_match = _match_field(dow.replace("7", "0"), cron_dow, 0, 6, DAYS)

    # Vixie cron-compatible behaviour: when both DOM and DOW are restricted,
    # either may match. If one is *, the restricted one must match.
    if not dom_any and not dow_any:
        return dom_match or dow_match
    return dom_match and dow_match


def stable_name(command: str) -> str:
    return "cron_" + hashlib.sha256(command.encode("utf-8")).hexdigest()[:12]


def run_id(source: str, user: str, line_no: int, line: str, minute_key: str) -> str:
    raw = f"{source}\0{user}\0{line_no}\0{line}\0{minute_key}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def already_dispatched(state_dir: Path, rid: str, dryrun: bool) -> bool:
    state_dir.mkdir(parents=True, exist_ok=True)
    marker = state_dir / f"{rid}.json"
    if marker.exists():
        return True
    if dryrun:
        return False
    flags = os.O_CREAT | os.O_EXCL | os.O_WRONLY
    fd = os.open(str(marker), flags, 0o644)
    with os.fdopen(fd, "w") as f:
        json.dump({"run_id": rid, "created_at": _dt.datetime.now().astimezone().isoformat()}, f)
        f.write("\n")
    return False


def user_home(user: str) -> str:
    return pwd.getpwnam(user).pw_dir


def source_for_user(user: str) -> str:
    env_source = os.environ.get("QUEUEBASH_SOURCE", "")
    if env_source and Path(env_source).exists():
        return env_source
    candidates = [
        DEFAULT_QUEUEBASH_SOURCE,
        "/usr/local/bin/queuebash.sh",
        str(Path(user_home(user)) / ".local/share/bashqueues/queuebash.sh"),
    ]
    for c in candidates:
        if Path(c).exists():
            return c
    # Last resort: let the user's shell startup/path provide queue.
    return ""


def dispatch(user: str, command: str, cron_source: str, line_no: int, dryrun: bool = False) -> int:
    cname = stable_name(command)
    qname = cname
    qsrc = source_for_user(user)
    home = user_home(user)
    class_body = f"""# bashqueues generated cron bridge class: {cname}
# Source: {cron_source}:{line_no}
# Purpose:
#   Prevent overlapping cron firings for this command.
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=1
CLASS_DEFAULT_RUNNER=auto
"""
    script_lines = [
        "set -e",
        "export QUEUEBASH_ALLOW_NONINTERACTIVE=1",
        f"export QUEUEBASH_ROOT={shlex.quote(str(Path(home) / '.queuebash'))}",
    ]
    if qsrc:
        script_lines.append(f"source {shlex.quote(qsrc)} >/dev/null 2>&1")
    script_lines.extend([
        "mkdir -p \"$QUEUEBASH_ROOT/classes\"",
        f"cat > \"$QUEUEBASH_ROOT/classes/{cname}.env\" <<'EOF_CLASS'\n{class_body}EOF_CLASS",
        "chmod 0644 \"$QUEUEBASH_ROOT/classes/" + cname + ".env\" 2>/dev/null || true",
        "queue submit " + shlex.quote(qname) + " --priority 10 --class " + shlex.quote(cname) + " -- bash -lc " + shlex.quote(command),
    ])
    shell_script = "\n".join(script_lines)
    if dryrun:
        print(f"DRYRUN user={user} class={cname} command={command}")
        return 0
    if os.geteuid() == 0 and user != "root":
        return subprocess.call(["runuser", "-u", user, "--", "bash", "-lc", shell_script])
    return subprocess.call(["bash", "-lc", shell_script])


def iter_user_crons(spool: Path) -> Iterable[Tuple[str, Path, int, str, List[str], str]]:
    if not spool.exists():
        return
    for path in sorted(spool.iterdir()):
        if not path.is_file() or path.name.startswith("."):
            continue
        user = path.name
        with path.open(errors="replace") as f:
            for n, line in enumerate(f, 1):
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    continue
                parts = stripped.split(maxsplit=5)
                if len(parts) != 6:
                    print(f"WARN invalid user cron {path}:{n}: expected 6 fields", file=sys.stderr)
                    continue
                yield user, path, n, stripped, parts[:5], parts[5]


def iter_system_crons(system_dir: Path) -> Iterable[Tuple[str, Path, int, str, List[str], str]]:
    if not system_dir.exists():
        return
    for path in sorted(system_dir.iterdir()):
        if not path.is_file() or path.name.startswith("."):
            continue
        with path.open(errors="replace") as f:
            for n, line in enumerate(f, 1):
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    continue
                parts = stripped.split(maxsplit=6)
                if len(parts) != 7:
                    print(f"WARN invalid system cron {path}:{n}: expected 7 fields", file=sys.stderr)
                    continue
                yield parts[5], path, n, stripped, parts[:5], parts[6]


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Submit due cron entries into bashqueues")
    ap.add_argument("--spool-dir", default=os.environ.get("QUEUEBASH_CRON_SPOOL_DIR", DEFAULT_USER_SPOOL))
    ap.add_argument("--system-dir", default=os.environ.get("QUEUEBASH_CRON_SYSTEM_DIR", DEFAULT_SYSTEM_DIR))
    ap.add_argument("--state-dir", default=os.environ.get("QUEUEBASH_CRON_STATE_DIR", DEFAULT_STATE_DIR))
    ap.add_argument("--dryrun", "--dry-run", action="store_true")
    ap.add_argument("--now", help="ISO timestamp for tests, local time if timezone omitted")
    ns = ap.parse_args(argv)

    if ns.now:
        dt = _dt.datetime.fromisoformat(ns.now)
        if dt.tzinfo is None:
            dt = dt.astimezone()
    else:
        dt = _dt.datetime.now().astimezone()
    minute_key = dt.strftime("%Y%m%d%H%M")
    state_dir = Path(ns.state_dir)
    rc = 0
    entries = list(iter_user_crons(Path(ns.spool_dir))) + list(iter_system_crons(Path(ns.system_dir)))
    for user, path, line_no, raw_line, parts, command in entries:
        try:
            if not should_run(parts, dt):
                continue
            rid = run_id(str(path), user, line_no, raw_line, minute_key)
            if already_dispatched(state_dir, rid, ns.dryrun):
                continue
            drc = dispatch(user, command, f"{path}", line_no, dryrun=ns.dryrun)
            rc = rc or drc
        except Exception as e:
            print(f"ERROR {path}:{line_no}: {e}", file=sys.stderr)
            rc = rc or 1
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
