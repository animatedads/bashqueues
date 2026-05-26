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
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

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


def stable_name(user: str, command: str) -> str:
    """Stable generated class name, scoped by user to avoid cross-user collisions."""
    return "cron_" + hashlib.sha256(f"{user}\0{command}".encode("utf-8")).hexdigest()[:12]


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


def _parse_env_assignments(path: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if not path.exists():
        return out
    rx = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
    for line in path.read_text(errors="replace").splitlines():
        m = rx.match(line.strip())
        if not m:
            continue
        key, value = m.group(1), m.group(2).strip()
        if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
            value = value[1:-1]
        out[key] = value
    return out


def _queue_root_for_user(user: str) -> Path:
    return Path(os.environ.get("QUEUEBASH_ROOT", str(Path(user_home(user)) / ".queuebash")))


def _bundled_policy_root(qsrc: str) -> Optional[Path]:
    if not qsrc:
        return None
    base = Path(qsrc).resolve().parent
    return base / "policies.d"


def _class_statement(user: str, qsrc: str) -> Dict[str, str]:
    name = os.environ.get("QUEUEBASH_CLASS_POLICY_STATEMENT", "default")
    roots = [
        Path(os.environ.get("QUEUEBASH_SHARED_POLICY_ROOT", "/etc/bashqueues/policies.d")),
        _queue_root_for_user(user) / "policies.d",
    ]
    bundled = _bundled_policy_root(qsrc)
    if bundled is not None:
        roots.append(bundled)
    for root in roots:
        f = root / "class-statement" / f"{name}.env"
        if f.exists():
            return _parse_env_assignments(f)
    return {}


def _security_sandbox_rank(level: str) -> int:
    return {"off": 0, "none": 0, "restrict-egress": 1, "queue-default": 1, "network-none": 2, "strict": 3}.get(level.lower(), 0)


def _security_seccomp_rank(profile: str) -> int:
    return {"off": 0, "none": 0, "docker-default": 1, "queue-default": 1, "strict": 2}.get(profile.lower(), 0)


def _class_defaults_for_user(user: str, qsrc: str, class_name: str) -> Dict[str, str]:
    root = _queue_root_for_user(user)
    candidates = [root / "classes" / f"{class_name}.env"]
    if qsrc:
        candidates.append(Path(qsrc).resolve().parent / "classes" / f"{class_name}.env")
    for f in candidates:
        if f.exists():
            return _parse_env_assignments(f)
    return {}


def _command_hash(command: str) -> str:
    try:
        raw = subprocess.check_output(["bash", "-c", "printf '%q ' \"$@\"", "--", "bash", "-lc", command], text=True)
    except Exception:
        raw = "bash -lc " + shlex.quote(command) + " "
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _normalise_auth_code(code: Optional[str]) -> Optional[str]:
    if not code:
        return None
    code = code.upper()
    if not re.match(r"^[A-Z0-9]{1,5}$", code):
        return None
    return code


def _authorisation_file_command_hash(path: Path) -> Optional[str]:
    """Return the hash implied by AUTHORISATION_COMMAND in an auth file.

    This is deliberately separate from AUTHORISATION_COMMAND_SHA256.  If an
    operator forcibly edits the command array in the file, the file no longer
    sums and the authorisation must not be accepted.
    """
    if not path.exists():
        return None
    script = """
AUTHORISATION_COMMAND=()
source "$1" >/dev/null 2>&1 || exit 10
[[ "${#AUTHORISATION_COMMAND[@]}" -gt 0 ]] || exit 11
printf '%q ' "${AUTHORISATION_COMMAND[@]}"
"""
    try:
        raw = subprocess.check_output(["bash", "-c", script, "--", str(path)], text=True)
    except Exception:
        return None
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _authorisation_valid_for_command(user: str, command: str, code: Optional[str]) -> bool:
    code = _normalise_auth_code(code)
    if not code:
        return False
    f = _queue_root_for_user(user) / "authorisations" / f"{code}.env"
    data = _parse_env_assignments(f)
    if not data:
        return False
    if data.get("AUTHORISATION_STATUS", "active").lower() != "active":
        return False
    au = data.get("AUTHORISATION_USER", "")
    if au and au != "*" and au != user:
        return False
    stored = data.get("AUTHORISATION_COMMAND_SHA256", "")
    if not stored or _authorisation_file_command_hash(f) != stored:
        return False
    return stored == _command_hash(command)


def _cron_class_below_minimum(user: str, qsrc: str, class_name: str) -> bool:
    statement = _class_statement(user, qsrc)
    min_sb = statement.get("CLASS_POLICY_CRON_MIN_SANDBOX_LEVEL", "strict")
    min_sc = statement.get("CLASS_POLICY_CRON_MIN_SECCOMP_PROFILE", "off")
    defaults = _class_defaults_for_user(user, qsrc, class_name)
    sb = defaults.get("CLASS_DEFAULT_SANDBOX_LEVEL", "off")
    sc = defaults.get("CLASS_DEFAULT_SECCOMP_PROFILE", "off")
    return _security_sandbox_rank(sb) < _security_sandbox_rank(min_sb) or _security_seccomp_rank(sc) < _security_seccomp_rank(min_sc)


def _cron_selector_path() -> Optional[Path]:
    """Return the optional cron class selector path, if present and enabled."""
    if os.environ.get("QUEUEBASH_CRON_CLASS_SELECTOR", "1").lower() in {"0", "no", "false", "off"}:
        return None
    configured = os.environ.get("QUEUEBASH_CRON_CLASS_SELECTOR_PATH", "")
    candidates: List[Path] = []
    if configured:
        candidates.append(Path(configured))
    here = Path(__file__).resolve()
    candidates.extend([
        here.parent / "bashqueues-cron-class-selector.py",
        here.parent.parent / "bin" / "bashqueues-cron-class-selector.py",
        Path("/usr/local/share/bashqueues/bin/bashqueues-cron-class-selector.py"),
    ])
    for candidate in candidates:
        try:
            if candidate.exists() and os.access(candidate, os.X_OK):
                return candidate
            if candidate.exists():
                return candidate
        except OSError:
            continue
    return None


def _cron_select_class(user: str, command: str, qsrc: str) -> Tuple[Optional[str], int, str]:
    """Ask the optional selector for a class. Failure is non-fatal."""
    selector = _cron_selector_path()
    if selector is None:
        return None, 0, "selector disabled or not installed"
    try:
        min_conf = int(os.environ.get("QUEUEBASH_CRON_CLASS_SELECTOR_MIN_CONFIDENCE", "70"))
    except ValueError:
        min_conf = 70
    env = os.environ.copy()
    if qsrc:
        env.setdefault("QUEUEBASH_SOURCE", qsrc)
    try:
        out = subprocess.check_output(
            [
                sys.executable,
                str(selector),
                "--command",
                command,
                "--user",
                user,
                "--json",
                "--min-confidence",
                str(min_conf),
            ],
            text=True,
            timeout=float(os.environ.get("QUEUEBASH_CRON_CLASS_SELECTOR_TIMEOUT", "5")),
            env=env,
            stderr=subprocess.DEVNULL,
        )
        data = json.loads(out)
        cls = str(data.get("class") or "").strip()
        conf = int(data.get("confidence") or 0)
        reason = str(data.get("reason") or "")
        if cls and conf >= min_conf:
            return cls, conf, reason
        return None, conf, reason or "selector found no confident class"
    except Exception as e:
        return None, 0, f"selector_error={type(e).__name__}"


def _resolve_cron_class(user: str, command: str, cron_source: str, line_no: int, qsrc: str, explicit_class: Optional[str], auth_code: Optional[str]) -> Tuple[Optional[str], Optional[str]]:
    if explicit_class:
        if not _cron_class_below_minimum(user, qsrc, explicit_class):
            return explicit_class, None
        if _authorisation_valid_for_command(user, command, auth_code):
            return explicit_class, auth_code
        print(
            f"WARN {cron_source}:{line_no}: requested class {explicit_class!r} is below crontab minimum and no command-bound authorisation matched; using generated safe cron class",
            file=sys.stderr,
        )
        return None, None

    selected_class, confidence, reason = _cron_select_class(user, command, qsrc)
    if not selected_class:
        return None, None
    if not _cron_class_below_minimum(user, qsrc, selected_class):
        return selected_class, None
    print(
        f"WARN {cron_source}:{line_no}: selector chose class {selected_class!r} confidence={confidence} but it is below crontab minimum; using generated safe cron class",
        file=sys.stderr,
    )
    return None, None


def _shell_single_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def dispatch(user: str, command: str, cron_source: str, line_no: int, dryrun: bool = False, explicit_class: Optional[str] = None, auth_code: Optional[str] = None) -> int:
    cname = stable_name(user, command)
    qname = cname
    qsrc = source_for_user(user)
    explicit_class, auth_code = _resolve_cron_class(user, command, cron_source, line_no, qsrc, explicit_class, auth_code)
    target_class = explicit_class or cname
    home = user_home(user)
    class_body = f"""# bashqueues generated cron bridge class: {cname}
# Source: {cron_source}:{line_no}
# Purpose:
#   Prevent overlapping cron firings for this command.
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=1
CLASS_DEFAULT_RUNNER=auto
CLASS_DEFAULT_SANDBOX_LEVEL=strict
CLASS_DEFAULT_RUNTIME_CAPS=no-spawn-shell,no-network-tools,only-local-sockets
CLASS_DEFAULT_RUNTIME_CAP_INTERVAL=1
"""
    script_lines = [
        "set -e",
        "export QUEUEBASH_ALLOW_NONINTERACTIVE=1",
        f"export QUEUEBASH_ROOT={shlex.quote(str(Path(home) / '.queuebash'))}",
    ]
    if qsrc:
        script_lines.append(f"source {shlex.quote(qsrc)} >/dev/null 2>&1")

    if explicit_class:
        # Explicit classes are operator/user managed.  Do not overwrite them.
        submit = "queue submit " + shlex.quote(qname) + " --priority 10 --class " + shlex.quote(target_class)
        if auth_code:
            submit += " --authorisation " + shlex.quote(auth_code)
        submit += " -- bash -lc " + shlex.quote(command)
        script_lines.append(submit)
    else:
        quoted_body = _shell_single_quote(class_body)
        script_lines.extend([
            "mkdir -p \"$QUEUEBASH_ROOT/classes\"",
            f"class_file=\"$QUEUEBASH_ROOT/classes/{cname}.env\"",
            f"class_body={quoted_body}",
            "if [[ ! -f \"$class_file\" ]] || [[ \"$(cat \"$class_file\" 2>/dev/null)\" != \"$class_body\" ]]; then",
            "  printf '%s' \"$class_body\" > \"$class_file\"",
            "  chmod 0644 \"$class_file\" 2>/dev/null || true",
            "fi",
            "queue submit " + shlex.quote(qname) + " --priority 10 --class " + shlex.quote(target_class) + " -- bash -lc " + shlex.quote(command),
        ])
    shell_script = "\n".join(script_lines)
    if dryrun:
        print(f"DRYRUN user={user} class={target_class} command={command}")
        return 0
    if os.geteuid() == 0 and user != "root":
        return subprocess.call(["runuser", "-u", user, "--", "bash", "-lc", shell_script])
    return subprocess.call(["bash", "-lc", shell_script])



CRON_MACROS = {
    "@yearly": "0 0 1 1 *",
    "@annually": "0 0 1 1 *",
    "@monthly": "0 0 1 * *",
    "@weekly": "0 0 * * 0",
    "@daily": "0 0 * * *",
    "@midnight": "0 0 * * *",
    "@hourly": "0 * * * *",
}


def expand_cron_macro(stripped: str, path: Path, line_no: int, system: bool) -> Optional[str]:
    if not stripped.startswith("@"):
        return stripped
    parts = stripped.split(maxsplit=2 if system else 1)
    macro = parts[0].lower()
    if macro == "@reboot":
        print(f"WARN unsupported cron macro {path}:{line_no}: @reboot has no minute-ticker equivalent", file=sys.stderr)
        return None
    sched = CRON_MACROS.get(macro)
    if not sched:
        return stripped
    if system:
        if len(parts) < 3:
            print(f"WARN invalid system cron {path}:{line_no}: macro requires user and command", file=sys.stderr)
            return None
        return f"{sched} {parts[1]} {parts[2]}"
    if len(parts) < 2:
        print(f"WARN invalid user cron {path}:{line_no}: macro requires command", file=sys.stderr)
        return None
    return f"{sched} {parts[1]}"


def cleanup_state_markers(state_dir: Path, max_age_days: int) -> None:
    if max_age_days < 0 or not state_dir.exists():
        return
    cutoff = _dt.datetime.now().timestamp() - (max_age_days * 86400)
    for marker in state_dir.glob("*.json"):
        try:
            if marker.stat().st_mtime < cutoff:
                marker.unlink()
        except FileNotFoundError:
            continue
        except OSError as e:
            print(f"WARN unable to remove old cron marker {marker}: {e}", file=sys.stderr)

def _parse_cron_assignment(line: str) -> Optional[Tuple[str, str]]:
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
    if not m:
        return None
    return m.group(1), m.group(2).strip().strip('"').strip("'")


def _parse_comment_directive(line: str) -> Optional[Tuple[str, str]]:
    """Parse local bashqueues cron directives, for example: #class NIGHTLY."""
    stripped = line.strip()
    if not stripped.startswith("#"):
        return None
    body = stripped[1:].strip()
    m = re.match(r"(?i)^(?:bashqueues[-_])?(class|authorisation|authorization)\s+(.+?)\s*$", body)
    if not m:
        return None
    return m.group(1).lower(), m.group(2).strip().strip('"').strip("'")


def iter_user_crons(spool: Path) -> Iterable[Tuple[str, Path, int, str, List[str], str, Optional[str]]]:
    if not spool.exists():
        return
    for path in sorted(spool.iterdir()):
        if not path.is_file() or path.name.startswith("."):
            continue
        user = path.name
        active_class: Optional[str] = None
        active_authorisation: Optional[str] = None
        with path.open(errors="replace") as f:
            for n, line in enumerate(f, 1):
                stripped = line.strip()
                if not stripped:
                    continue
                directive = _parse_comment_directive(stripped)
                if directive:
                    key, value = directive
                    if key == "class":
                        active_class = value or None
                    elif key in ("authorisation", "authorization"):
                        active_authorisation = value or None
                    continue
                if stripped.startswith("#"):
                    continue
                assignment = _parse_cron_assignment(stripped)
                if assignment:
                    key, value = assignment
                    if key == "BASHQUEUES_CLASS":
                        active_class = value or None
                    elif key in ("BASHQUEUES_AUTHORISATION", "BASHQUEUES_AUTHORIZATION"):
                        active_authorisation = value or None
                    continue
                expanded = expand_cron_macro(stripped, path, n, system=False)
                if expanded is None:
                    continue
                parts = expanded.split(maxsplit=5)
                if len(parts) != 6:
                    print(f"WARN invalid user cron {path}:{n}: expected 6 fields", file=sys.stderr)
                    continue
                yield user, path, n, stripped, parts[:5], parts[5], active_class, active_authorisation


def iter_system_crons(system_dir: Path) -> Iterable[Tuple[str, Path, int, str, List[str], str, Optional[str]]]:
    if not system_dir.exists():
        return
    for path in sorted(system_dir.iterdir()):
        if not path.is_file() or path.name.startswith("."):
            continue
        active_class: Optional[str] = None
        active_authorisation: Optional[str] = None
        with path.open(errors="replace") as f:
            for n, line in enumerate(f, 1):
                stripped = line.strip()
                if not stripped:
                    continue
                directive = _parse_comment_directive(stripped)
                if directive:
                    key, value = directive
                    if key == "class":
                        active_class = value or None
                    elif key in ("authorisation", "authorization"):
                        active_authorisation = value or None
                    continue
                if stripped.startswith("#"):
                    continue
                assignment = _parse_cron_assignment(stripped)
                if assignment:
                    key, value = assignment
                    if key == "BASHQUEUES_CLASS":
                        active_class = value or None
                    elif key in ("BASHQUEUES_AUTHORISATION", "BASHQUEUES_AUTHORIZATION"):
                        active_authorisation = value or None
                    continue
                expanded = expand_cron_macro(stripped, path, n, system=True)
                if expanded is None:
                    continue
                parts = expanded.split(maxsplit=6)
                if len(parts) != 7:
                    print(f"WARN invalid system cron {path}:{n}: expected 7 fields", file=sys.stderr)
                    continue
                yield parts[5], path, n, stripped, parts[:5], parts[6], active_class, active_authorisation


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Submit due cron entries into bashqueues")
    ap.add_argument("--spool-dir", default=os.environ.get("QUEUEBASH_CRON_SPOOL_DIR", DEFAULT_USER_SPOOL))
    ap.add_argument("--system-dir", default=os.environ.get("QUEUEBASH_CRON_SYSTEM_DIR", DEFAULT_SYSTEM_DIR))
    ap.add_argument("--state-dir", default=os.environ.get("QUEUEBASH_CRON_STATE_DIR", DEFAULT_STATE_DIR))
    ap.add_argument("--dryrun", "--dry-run", action="store_true")
    ap.add_argument("--now", help="ISO timestamp for tests, local time if timezone omitted")
    ap.add_argument("--state-max-age-days", type=int, default=int(os.environ.get("QUEUEBASH_CRON_STATE_MAX_AGE_DAYS", "7")))
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
    for user, path, line_no, raw_line, parts, command, explicit_class, auth_code in entries:
        try:
            if not should_run(parts, dt):
                continue
            rid = run_id(str(path), user, line_no, raw_line, minute_key)
            if already_dispatched(state_dir, rid, ns.dryrun):
                continue
            drc = dispatch(user, command, f"{path}", line_no, dryrun=ns.dryrun, explicit_class=explicit_class, auth_code=auth_code)
            rc = rc or drc
        except Exception as e:
            print(f"ERROR {path}:{line_no}: {e}", file=sys.stderr)
            rc = rc or 1
    if not ns.dryrun:
        cleanup_state_markers(state_dir, ns.state_max_age_days)
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
