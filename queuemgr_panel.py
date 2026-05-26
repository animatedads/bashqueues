#!/usr/bin/env python3
from __future__ import annotations

import curses
import getpass
import os
import pwd
import re
import shlex
import subprocess
import textwrap
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, List, Optional, Sequence, Tuple

QUEUE_ROOT = os.environ.get("QUEUEBASH_ROOT", os.path.expanduser("~/.queuebash"))


def selected_queue_root_display(queue_user: str) -> str:
    """Return the queue root shown in the panel header.

    The Python process may have QUEUEBASH_ROOT from the operator shell
    while qrun() is operating on --queue-user.  The header should describe
    the selected queue owner, not the operator process root.
    """
    user = (queue_user or "").strip()
    if not user:
        return QUEUE_ROOT
    try:
        return str(Path(pwd.getpwnam(user).pw_dir) / ".queuebash")
    except Exception:
        return f"~{user}/.queuebash"


def _candidate_queue_sources() -> list[str]:
    candidates: list[str] = []
    env = os.environ.get("QUEUEBASH_SOURCE", "")
    if env:
        candidates.append(env)

    here = Path(__file__).resolve().parent
    cwd = Path.cwd()
    home = Path.home()
    candidates.extend([
        str(here / "queuebash.sh"),
        str(cwd / "queuebash.sh"),
        str(home / "bashqueues" / "queuebash.sh"),
        str(home / "queuebash.sh"),
    ])

    out: list[str] = []
    seen: set[str] = set()
    for c in candidates:
        if c and c not in seen:
            out.append(c)
            seen.add(c)
    return out


def _source_defines_queue(path: str) -> bool:
    try:
        if not path or not Path(path).is_file():
            return False
    except OSError:
        return False

    cmd = (
        "export QUEUEBASH_ALLOW_NONINTERACTIVE=1; "
        f"source {shlex.quote(path)} >/dev/null 2>&1; "
        "declare -F queue >/dev/null || type queue >/dev/null 2>&1"
    )
    try:
        return subprocess.run(["bash", "-lc", cmd], text=True, capture_output=True, timeout=5).returncode == 0
    except OSError:
        return False


def _discover_queue_source() -> str:
    for cand in _candidate_queue_sources():
        if _source_defines_queue(cand):
            return cand
    return ""


QUEUE_SOURCE = _discover_queue_source()
PANEL_QUEUE_USER = ""


def _effective_user_name() -> str:
    try:
        return getpass.getuser()
    except Exception:
        return os.environ.get("USER") or os.environ.get("LOGNAME") or ""


def _is_root_process() -> bool:
    try:
        return os.geteuid() == 0
    except AttributeError:
        return False


def _normalise_optional_user(user: str) -> str:
    text = (user or "").strip()
    if text.casefold() in {"", "-", "none", "current", "default", "clear", "unset", "no", "off"}:
        return ""
    if text in {"<current>", "<current/default>", "<none>", "<default>"}:
        return ""
    return text


def _delegation_user(as_user: str) -> tuple[str, str]:
    """Return (effective_delegate_user, diagnostic).

    runuser is only appropriate for root/operator delegation.  A normal user
    selecting their own queue must not get a generated runuser command.
    """
    wanted = _normalise_optional_user(as_user)
    if not wanted:
        return "", ""
    current = _effective_user_name()
    if current and wanted == current:
        return "", ""
    if _is_root_process():
        return wanted, ""
    return "", f"Cannot submit as user {wanted!r}: runuser delegation is only available to root/operator sessions"


def _wrap_with_delegation(command: str, as_user: str) -> tuple[str, str]:
    delegate, diagnostic = _delegation_user(as_user)
    if diagnostic:
        return command, diagnostic
    if delegate:
        return "runuser -u " + shlex.quote(delegate) + " -- bash -lc " + shlex.quote(command), ""
    return command, ""


def _queue_shell_command(args: Sequence[str]) -> str:
    quoted = " ".join(shlex.quote(a) for a in args)
    if QUEUE_SOURCE:
        return (
            "export QUEUEBASH_ALLOW_NONINTERACTIVE=1; "
            f"source {shlex.quote(QUEUE_SOURCE)} >/dev/null 2>&1; "
            f"queue {quoted}"
        )
    return f"queue {quoted}"


def _coerce_subprocess_text(value: object) -> str:
    """Return subprocess captured output as text.

    Python normally honours text=True, but TimeoutExpired.stdout/stderr may
    still be bytes on some versions/paths.  qrun() is used by the curses panel,
    so timeout handling must never raise while building a diagnostic.
    """
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode(errors="replace")
    return str(value)


def qrun(args: Sequence[str], timeout: int = 20, dry_run: bool = False, cwd: str = "", as_user: str = "") -> Tuple[int, str]:
    # If root/operator selected another queue owner, every panel qrun must use
    # that queue root explicitly.  This is queue ownership, not payload-user
    # delegation.
    if PANEL_QUEUE_USER:
        args = ["--queue-user", PANEL_QUEUE_USER, *args]

    delegate_user, delegation_error = _delegation_user(as_user)
    delegated_default_home = bool(delegate_user and not cwd)

    if cwd:
        cwd_prefix = f"cd {shlex.quote(cwd)} && "
    elif delegated_default_home:
        cwd_prefix = 'cd "$HOME" && '
    else:
        cwd_prefix = ""

    base_preview = cwd_prefix + "queue " + " ".join(shlex.quote(a) for a in args)
    base_preview, preview_error = _wrap_with_delegation(base_preview, as_user)

    if delegation_error:
        return 1, delegation_error

    if dry_run and args and args[0] not in {
        "list", "show", "explain", "history", "assets", "asset-hint", "classes",
        "exception", "exceptions", "caps", "version", "tail",
    }:
        return 0, "DRY-RUN: would run: " + base_preview

    cmd = _queue_shell_command(args)
    if cwd:
        cmd = "cd " + shlex.quote(cwd) + " && " + cmd
    elif delegated_default_home:
        cmd = 'cd "$HOME" && ' + cmd
    cmd, cmd_error = _wrap_with_delegation(cmd, as_user)
    if cmd_error:
        return 1, cmd_error

    try:
        p = subprocess.run(
            ["bash", "-lc", cmd],
            text=True,
            capture_output=True,
            timeout=timeout,
            env={**os.environ.copy(), "QUEUEBASH_ALLOW_NONINTERACTIVE": "1"},
        )
        out = (p.stdout or "") + (p.stderr or "")
        if p.returncode != 0 and not out.strip():
            out = f"queue command failed rc={p.returncode}: {cmd}"
        return p.returncode, out.rstrip("\n")
    except subprocess.TimeoutExpired as exc:
        out = _coerce_subprocess_text(exc.stdout) + _coerce_subprocess_text(exc.stderr)
        return 124, (out + f"\n[timeout running queue command: {cmd}]").strip()


def split_lines(s: str) -> List[str]:
    return s.splitlines() if s else []


@dataclass
class Item:
    key: str
    label: str
    meta: str = ""
    fields: dict[str, str] = field(default_factory=dict)






def normalize_panel_token(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (value or "").casefold())


def resolve_unique_choice(raw: str, choices: Sequence[str], aliases: Optional[dict[str, str]] = None) -> Tuple[str, str]:
    """Resolve exact, unique-prefix, or unique-substring panel choices.

    Returns (value, diagnostic).  value is empty when there is no unique match.
    The resolver deliberately accepts the first unique letters of commands, so
    "e" may select "explain" if no other command starts with e, while an
    ambiguous prefix produces a useful status message instead of guessing.
    """
    text = (raw or "").strip()
    if not text:
        return "", ""

    aliases = aliases or {}
    lowered_aliases = {k.casefold(): v for k, v in aliases.items()}
    if text.casefold() in lowered_aliases:
        return lowered_aliases[text.casefold()], ""

    if text.isdigit():
        idx = int(text) - 1
        if 0 <= idx < len(choices):
            return choices[idx], ""

    norm = normalize_panel_token(text)
    if not norm:
        return "", ""

    by_norm = {normalize_panel_token(c): c for c in choices}
    if norm in by_norm:
        return by_norm[norm], ""

    prefix_matches = [c for c in choices if normalize_panel_token(c).startswith(norm)]
    if len(prefix_matches) == 1:
        return prefix_matches[0], ""
    if len(prefix_matches) > 1:
        return "", "Ambiguous choice: " + ", ".join(prefix_matches)

    substring_matches = [c for c in choices if norm in normalize_panel_token(c)]
    if len(substring_matches) == 1:
        return substring_matches[0], ""
    if len(substring_matches) > 1:
        return "", "Ambiguous choice: " + ", ".join(substring_matches)

    return "", "No matching choice"


@dataclass
class ClassDraft:
    name: str = ""
    purpose: str = ""
    allow_parallel: str = "1"
    max_concurrent: str = "0"
    default_runner: str = "auto"
    default_timeout: str = ""
    default_kill_after: str = ""
    default_cpu_limit: str = ""
    default_mem_limit: str = ""
    default_log_cap: str = ""
    default_run_user: str = ""
    default_submit_user: str = ""
    default_sandbox_level: str = ""
    default_seccomp_profile: str = ""
    default_seccomp_allow: str = ""
    records: List[str] = field(default_factory=list)

    def render(self) -> str:
        cls = (self.name or "NEW_CLASS").strip().upper().replace("-", "_").replace(" ", "_")
        lines: List[str] = [
            f"# bashqueues class: {cls}",
            "#",
        ]
        if self.purpose:
            lines.extend(["# Purpose:", f"#   {self.purpose}", "#"])
        lines.extend([
            "CLASS_ALLOW_PARALLEL=" + (self.allow_parallel or "1"),
            "CLASS_MAX_CONCURRENT=" + (self.max_concurrent or "0"),
        ])
        if self.default_runner:
            lines.append("CLASS_DEFAULT_RUNNER=" + self.default_runner)
        if self.default_timeout:
            lines.append("CLASS_DEFAULT_TIMEOUT=" + self.default_timeout)
        if self.default_kill_after:
            lines.append("CLASS_DEFAULT_KILL_AFTER=" + self.default_kill_after)
        if self.default_cpu_limit:
            lines.append("CLASS_DEFAULT_CPU_LIMIT=" + self.default_cpu_limit)
        if self.default_mem_limit:
            lines.append("CLASS_DEFAULT_MEM_LIMIT=" + self.default_mem_limit)
        if self.default_log_cap:
            lines.append("CLASS_DEFAULT_MAX_LOG_SIZE_BYTES=" + self.default_log_cap)
        if self.default_run_user:
            lines.append("CLASS_DEFAULT_RUN_USER=" + self.default_run_user)
        if self.default_submit_user:
            lines.append("CLASS_DEFAULT_SUBMIT_USER=" + self.default_submit_user)
        if self.default_sandbox_level:
            lines.append("CLASS_DEFAULT_SANDBOX_LEVEL=" + self.default_sandbox_level)
        if self.default_seccomp_profile:
            lines.append("CLASS_DEFAULT_SECCOMP_PROFILE=" + self.default_seccomp_profile)
        if self.default_seccomp_allow:
            lines.append("CLASS_DEFAULT_SECCOMP_ALLOW=" + self.default_seccomp_allow)
        lines.append("")
        lines.extend(self.records or ["# Add asset restriction/claim records here, or use class commands to populate them."])
        lines.append("")
        return "\n".join(lines)

    def class_name(self) -> str:
        return (self.name or "NEW_CLASS").strip().upper().replace("-", "_").replace(" ", "_")


def split_list_field(text: str) -> List[str]:
    """Split comma/space separated job references entered in a panel field."""
    text = (text or "").strip()
    if not text:
        return []
    # Commas are natural for dependency lists; shlex still preserves quoted names.
    text = text.replace(",", " ")
    try:
        return [x for x in shlex.split(text) if x]
    except ValueError:
        return [x for x in text.split() if x]


def split_hook_command(text: str) -> List[str]:
    """Split a hook command field using shell-like quoting."""
    text = (text or "").strip()
    if not text:
        return []
    try:
        return shlex.split(text)
    except ValueError:
        # Keep the panel usable if the operator is mid-editing quotes.
        return [text]


@dataclass
class TaskDraft:
    name: str = ""
    command: str = ""
    job_class: str = ""
    priority: str = "10"
    submit_user: str = ""
    execution_dir: str = ""
    not_before: str = ""
    retries: str = "0"
    retry_backoff: str = ""
    runner: str = ""
    sandbox_level: str = ""
    security_reason: str = ""
    authorisation_code: str = ""
    no_security_exemption_required: bool = False
    cpu_limit: str = ""
    mem_limit: str = ""
    max_log_size: str = ""
    dependencies: str = ""
    inherit_env_from: str = ""
    on_success: str = ""
    on_failure: str = ""
    on_retry_failure: str = ""

    def normalized_name(self) -> str:
        # UI-friendly: "publish git" becomes "publish_git".
        name = (self.name or "task").strip()
        name = re.sub(r"\s+", "_", name)
        name = re.sub(r"[^A-Za-z0-9_.:-]", "_", name)
        return name or "task"

    def submit_args(self) -> List[str]:
        # queue submit syntax is:
        #   queue submit <name> [options] -- <command...>
        # Do not put options before the name.
        args: List[str] = ["submit", self.normalized_name()]
        if self.priority:
            args.extend(["--priority", self.priority])
        if self.job_class:
            args.extend(["--class", self.job_class])
        # Execution directory is not a queue submit option.  queuebash captures
        # PWD_AT_SUBMIT, so the panel manager runs queue submit with cwd set to
        # execution_dir instead.
        if self.not_before:
            args.extend(["--not-before", self.not_before])
        if self.retries and self.retries != "0":
            args.extend(["--retries", self.retries])
        if self.retry_backoff:
            args.extend(["--backoff", self.retry_backoff])
        if self.runner:
            args.extend(["--runner", self.runner])
        if self.sandbox_level:
            args.extend(["--sandbox", self.sandbox_level])
        if self.security_reason:
            args.extend(["--reason", self.security_reason])
        if self.authorisation_code:
            args.extend(["--authorisation", self.authorisation_code])
        if self.cpu_limit:
            args.extend(["--cpu", self.cpu_limit])
        if self.mem_limit:
            args.extend(["--mem", self.mem_limit])
        if self.max_log_size:
            args.extend(["--max-log-size", self.max_log_size])
        for dep in split_list_field(self.dependencies):
            args.extend(["--after-success", dep])
        for dep in split_list_field(self.inherit_env_from):
            args.extend(["--inherit-env-from", dep])
        # Keep on-retry before on-success: the queue submit parser stops
        # on-success when it sees on-failure, but not on-retry.
        retry_hook = split_hook_command(self.on_retry_failure)
        success_hook = split_hook_command(self.on_success)
        failure_hook = split_hook_command(self.on_failure)
        if retry_hook:
            args.append("--on-retry-failure")
            args.extend(retry_hook)
        if success_hook:
            args.append("--on-success")
            args.extend(success_hook)
        if failure_hook:
            args.append("--on-failure")
            args.extend(failure_hook)
        args.append("--")
        args.extend(shlex.split(self.command or "true"))
        return args

    def draft_create_args(self) -> List[str]:
        args: List[str] = ["draft", "create", self.normalized_name()]
        if self.priority:
            args.extend(["--priority", self.priority])
        if self.job_class:
            args.extend(["--class", self.job_class])
        submit_user = _normalise_optional_user(self.submit_user)
        if submit_user:
            args.extend(["--submit-user", submit_user])
        if self.execution_dir:
            args.extend(["--cwd", self.execution_dir])
        if self.not_before:
            args.extend(["--not-before", self.not_before])
        if self.retries and self.retries != "0":
            args.extend(["--retries", self.retries])
        if self.retry_backoff:
            args.extend(["--backoff", self.retry_backoff])
        if self.runner:
            args.extend(["--runner", self.runner])
        if self.sandbox_level:
            args.extend(["--sandbox", self.sandbox_level])
        if self.security_reason:
            args.extend(["--reason", self.security_reason])
        if self.authorisation_code:
            args.extend(["--authorisation", self.authorisation_code])
        if self.cpu_limit:
            args.extend(["--cpu", self.cpu_limit])
        if self.mem_limit:
            args.extend(["--mem", self.mem_limit])
        if self.max_log_size:
            args.extend(["--max-log-size", self.max_log_size])
        for dep in split_list_field(self.dependencies):
            args.extend(["--after-success", dep])
        for dep in split_list_field(self.inherit_env_from):
            args.extend(["--inherit-env-from", dep])
        # Keep on-retry before on-success: the queue submit parser stops
        # on-success when it sees on-failure, but not on-retry.
        retry_hook = split_hook_command(self.on_retry_failure)
        success_hook = split_hook_command(self.on_success)
        failure_hook = split_hook_command(self.on_failure)
        if retry_hook:
            args.append("--on-retry-failure")
            args.extend(retry_hook)
        if success_hook:
            args.append("--on-success")
            args.extend(success_hook)
        if failure_hook:
            args.append("--on-failure")
            args.extend(failure_hook)
        args.append("--")
        args.extend(shlex.split(self.command or "true"))
        return args

    def render_draft_save_command(self) -> str:
        return "queue " + " ".join(shlex.quote(x) for x in self.draft_create_args())

    def render_command(self) -> str:
        base = "queue " + " ".join(shlex.quote(x) for x in self.submit_args())
        delegate_user, delegation_error = _delegation_user(self.submit_user)
        if self.execution_dir:
            base = "cd " + shlex.quote(self.execution_dir) + " && " + base
        elif delegate_user:
            # Delegated submit without an explicit directory should not capture
            # the operator's cwd. Submit from the target user's HOME.
            base = 'cd "$HOME" && ' + base
        wrapped, _ = _wrap_with_delegation(base, self.submit_user)
        if delegation_error:
            return base + "\n\nWARNING: " + delegation_error
        return wrapped


@dataclass(frozen=True)
class MaintenanceRecipe:
    key: str
    label: str
    queue_args: Tuple[str, ...]
    description: str
    risk: str = "normal"
    default_not_before: str = "+10m"
    default_priority: str = "5"
    default_class: str = "QUEUE_MAINTENANCE"
    default_runner: str = "auto"
    default_max_log_size: str = "10485760"

    def job_name(self) -> str:
        return "maint_" + re.sub(r"[^A-Za-z0-9_.:-]+", "_", self.key).strip("_")


MAINTENANCE_RECIPES: List[MaintenanceRecipe] = [
    MaintenanceRecipe(
        "health-fix",
        "health --fix",
        ("health", "--fix"),
        "Repair missing directories, dead worker records, and stale running jobs.",
        risk="repair",
    ),
    MaintenanceRecipe(
        "compress-logs",
        "compress completed logs",
        ("compress-logs",),
        "Bulk-compress completed done/failed logs. Workers already compress targeted logs; this is the tidy-up sweep.",
        risk="log-roll",
    ),
    MaintenanceRecipe(
        "clean-logs-preview",
        "preview clean old logs",
        ("clean-logs", "--dryrun", "--older-than", "30d", "--state", "done"),
        "Preview old completed logs that would be removed. This is intentionally non-destructive.",
        risk="preview",
        default_not_before="+5m",
    ),
    MaintenanceRecipe(
        "clean-logs-delete",
        "delete old done logs",
        ("clean-logs", "--force", "--older-than", "30d", "--state", "done"),
        "Remove done-job logs older than 30 days and mark matching job records with LOG_CLEANED metadata.",
        risk="delete",
        default_not_before="+30m",
    ),
    MaintenanceRecipe(
        "clear-deleted",
        "clear deleted job records",
        ("clear", "deleted"),
        "Remove records already in the deleted bucket.",
        risk="delete",
        default_not_before="+30m",
    ),
    MaintenanceRecipe(
        "clear-done",
        "clear done job records",
        ("clear", "done"),
        "Remove done job records. Prefer log compression/cleaning first if audit history still matters.",
        risk="delete",
        default_not_before="+1h",
    ),
    MaintenanceRecipe(
        "clear-interrupted",
        "clear interrupted job records",
        ("clear", "interrupted"),
        "Remove interrupted job records after reviewing the failures.",
        risk="delete",
        default_not_before="+1h",
    ),
    MaintenanceRecipe(
        "clear-cancelled",
        "clear cancelled job records",
        ("clear", "cancelled"),
        "Remove cancelled job records after reviewing the operator actions.",
        risk="delete",
        default_not_before="+1h",
    ),
]


def maintenance_recipe_by_key(key: str) -> Optional[MaintenanceRecipe]:
    for recipe in MAINTENANCE_RECIPES:
        if recipe.key == key:
            return recipe
    return None


def queue_payload_command(args: Sequence[str]) -> str:
    payload_args: List[str] = []
    if PANEL_QUEUE_USER:
        payload_args.extend(["--queue-user", PANEL_QUEUE_USER])
    payload_args.extend(args)
    quoted = " ".join(shlex.quote(a) for a in payload_args)
    if QUEUE_SOURCE:
        return (
            "export QUEUEBASH_ALLOW_NONINTERACTIVE=1; "
            f"source {shlex.quote(QUEUE_SOURCE)} >/dev/null 2>&1; "
            f"queue {quoted}"
        )
    return f"queue {quoted}"


@dataclass
class ViewState:
    name: str
    title: str
    loader: Callable[["PanelManager"], List[Item]]
    detailer: Callable[["PanelManager", Optional[Item]], str]
    items: List[Item] = field(default_factory=list)
    selected: int = 0
    scroll: int = 0
    detail_scroll: int = 0

    def refresh(self, app: "PanelManager") -> None:
        old = self.items[self.selected].key if self.items and 0 <= self.selected < len(self.items) else ""
        self.items = self.loader(app)
        keys = [i.key for i in self.items]
        self.selected = keys.index(old) if old in keys else min(self.selected, max(0, len(self.items) - 1))
        self.scroll = max(0, min(self.scroll, self.selected))
        self.detail_scroll = 0

    def current(self) -> Optional[Item]:
        if not self.items:
            return None
        self.selected = max(0, min(self.selected, len(self.items) - 1))
        return self.items[self.selected]


def error_items(label: str, rc: int, out: str) -> List[Item]:
    msg = out.strip() or f"queue command failed rc={rc}"
    if not QUEUE_SOURCE:
        msg += "\n\nNo usable queuebash.sh was found. Tried:\n"
        msg += "\n".join(f"  {x}" for x in _candidate_queue_sources())
    return [Item("__error__", f"ERROR loading {label}: rc={rc}", msg)]


def parse_job_line(line: str) -> Optional[Item]:
    if not line or line.startswith("JOB_ID"):
        return None
    parts = line.split()
    if len(parts) < 4:
        return None
    qid = parts[0]
    if "_" not in qid or len(qid) < 20:
        return None
    state, pri, name = parts[1], parts[2], parts[3]
    cmd = " ".join(parts[4:])
    return Item(qid, f"{state:<10} {pri:>3} {name:<20} {qid}", cmd, {
        "state": state, "priority": pri, "name": name, "command": cmd,
    })


def load_jobs(app: "PanelManager") -> List[Item]:
    rc, out = qrun(["list"], dry_run=False)
    if rc != 0:
        return error_items("jobs", rc, out)
    items = [it for it in (parse_job_line(line) for line in split_lines(out)) if it]
    return app.apply_job_filters(items)


def queue_job_reference_choices(app: "PanelManager") -> List[str]:
    """Return queue job names/QIDs suitable for dependency-style fields.

    The Task Creator dependency fields are queue references, not shell globs.
    A typed/star chooser must therefore offer existing queue names and QIDs,
    plus an explicit clear option, instead of allowing `*` to become a literal
    `--inherit-env-from '*'` submit argument.
    """
    choices: List[str] = ["<clear>"]
    seen = {"<clear>"}
    for item in load_jobs(app):
        if item.key == "__error__":
            continue
        name = (item.fields.get("name") or "").strip()
        if name and name not in seen:
            choices.append(name)
            seen.add(name)
        if item.key and item.key not in seen:
            choices.append(item.key)
            seen.add(item.key)
    return choices


def detail_job(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No jobs."
    if item.key == "__error__":
        return item.meta

    tab = app.detail_tab
    if tab == "Explain":
        _, out = qrun(["explain", item.key])
        return out
    if tab == "Class":
        class_name = job_class(item.key)
        if not class_name:
            return "No class recorded for this job."
        _, out = qrun(["classes", "explain", class_name])
        return out
    if tab == "Exceptions":
        _, out = qrun(["exception", "list", item.key])
        return out
    if tab == "History":
        _, out = qrun(["history", item.key])
        return out
    if tab == "Log":
        _, out = qrun(["show", item.key])
        return out
    if tab == "Tail":
        _, out = qrun(["tail", item.key, "--no-follow"])
        return out
    return "Unknown tab."


def job_class(qid: str) -> str:
    for state in ["pending", "running", "done", "failed", "cancelled", "deleted", "interrupted"]:
        f = Path(QUEUE_ROOT) / state / f"{qid}.job"
        if f.exists():
            try:
                for line in f.read_text(errors="ignore").splitlines():
                    if line.startswith("JOB_CLASS="):
                        return line.split("=", 1)[1].strip().strip("'\"")
            except OSError:
                return ""
    rc, out = qrun(["explain", qid])
    m = re.search(r"^\s*class:\s*(\S+)", out, re.M)
    return m.group(1) if m else ""


def re_like_class(s: str) -> bool:
    return bool(s) and all(c.isalnum() or c in "_-" for c in s) and not s.lower().startswith("class")


def load_classes(app: "PanelManager") -> List[Item]:
    rc, out = qrun(["classes", "list"])
    if rc != 0:
        return error_items("classes", rc, out)
    items = [Item(ln.strip(), ln.strip()) for ln in split_lines(out) if re_like_class(ln.strip())]
    if app.class_filter:
        f = app.class_filter.lower()
        items = [it for it in items if f in it.key.lower()]
    return items


def detail_class(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No classes."
    if item.key == "__error__":
        return item.meta
    mode = getattr(app, "class_detail_mode", "explain")
    if mode == "show":
        _, out = qrun(["classes", "show", item.key])
        return out
    if mode == "validate":
        _, out = qrun(["classes", "validate", item.key])
        return out
    if mode in {"history", "backups"}:
        # class command dispatcher deliberately sets the right pane mode; the
        # actual history content is loaded here so moving Up/Down refreshes it.
        _, out = qrun(["classes", "backups", item.key])
        return out or "No class backup history found."
    _, out = qrun(["classes", "explain", item.key])
    return out


def load_assets(app: "PanelManager") -> List[Item]:
    rc, out = qrun(["assets"])
    if rc != 0:
        return error_items("assets", rc, out)
    items: List[Item] = []
    for line in split_lines(out):
        if not line or line.startswith("===") or line.startswith("INVALID"):
            continue
        parts = line.split(None, 1)
        if parts and ":" in parts[0]:
            items.append(Item(parts[0], parts[0], parts[1] if len(parts) > 1 else ""))
    if app.asset_filter:
        f = app.asset_filter.lower()
        items = [it for it in items if f in it.key.lower() or f in it.meta.lower()]
    return items


def detail_asset(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No assets."
    if item.key == "__error__":
        return item.meta
    _, hint = qrun(["asset-hint", item.key])
    _, explain = qrun(["assets", "explain", item.key])
    return "\n".join(["=== HINT ===", hint, "", "=== EXPLAIN ===", explain])


def load_modules(app: "PanelManager") -> List[Item]:
    rc, out = qrun(["modules", "list"])
    if rc != 0:
        return error_items("modules", rc, out)
    items: List[Item] = []
    for line in split_lines(out):
        parts = line.split("\t")
        if len(parts) >= 4:
            kind, name, status, path = parts[0], parts[1], parts[2], parts[3]
            # asset-side net_usage was removed; runtime net usage now lives in caps.d.
            # Hide stale queue-root copies defensively even before a refresh/prune runs.
            if kind == "asset" and name == "net_usage":
                continue
            key = f"{kind}:{name}"
            label = f"{kind:<5} {name:<24} {status}"
            items.append(Item(key, label, path, {"kind": kind, "name": name, "status": status, "path": path}))
    if app.module_filter:
        f = app.module_filter.lower()
        items = [it for it in items if f in it.key.lower() or f in it.label.lower() or f in it.meta.lower()]
    return items


def detail_module(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No modules."
    if item.key == "__error__":
        return item.meta
    _, out = qrun(["modules", "explain", item.key])
    return out or f"No detail for {item.key}"


def load_global_resources(app: "PanelManager") -> List[Item]:
    rc, out = qrun(["global", "claims"])
    if rc != 0:
        return error_items("global", rc, out)
    items: List[Item] = []
    current: Optional[Item] = None
    for line in split_lines(out):
        if not line or line.startswith("CLAIM") or line.startswith("No global"):
            continue
        if not line.startswith(" "):
            parts = line.split()
            if len(parts) >= 3:
                claim, mode, used = parts[0], parts[1], parts[2]
                current = Item(claim, f"{claim:<32} {mode:<10} {used:<8}", "", {"claim": claim, "mode": mode, "used": used})
                items.append(current)
        elif current is not None:
            current.meta = (current.meta + "\n" + line.strip()).strip()
    return items


def detail_global_resource(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No active global claims."
    if item.key == "__error__":
        return item.meta
    _, out = qrun(["global", "claim", item.key])
    return out or f"No detail for global claim {item.key}"


def parse_policy_line(line: str, kind: str) -> Optional[Item]:
    line = (line or "").strip()
    if not line or line.startswith("==="):
        return None
    parts = line.split(None, 2)
    if len(parts) < 2:
        return None
    name = parts[0]
    origin = parts[1]
    path = parts[2] if len(parts) > 2 else ""
    key = f"{kind}:{name}"
    label = f"{kind:<16} {name:<20} {origin:<8}"
    return Item(key, label, path, {"kind": kind, "name": name, "origin": origin, "path": path})


def load_policies(app: "PanelManager") -> List[Item]:
    items: List[Item] = []
    for kind in ("class-statement", "sandbox", "seccomp"):
        rc, out = qrun(["policies", "list", kind], timeout=5)
        if rc != 0:
            items.extend(error_items("policies", rc, out))
            continue
        for line in split_lines(out):
            it = parse_policy_line(line, kind)
            if it:
                items.append(it)
    return items


def detail_policy(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No policies."
    if item.key == "__error__":
        return item.meta
    kind = item.fields.get("kind", item.key.split(":", 1)[0])
    name = item.fields.get("name", item.key.split(":", 1)[1] if ":" in item.key else item.key)
    _, out = qrun(["policies", "show", kind, name], timeout=10)
    return out or f"No detail for policy {kind}:{name}"


def load_exceptions(app: "PanelManager") -> List[Item]:
    """Load exception overlays through the queue command, not by local path.

    In root/operator sessions the panel may be showing another user's queue via
    --queue-user.  Reading Path(QUEUE_ROOT)/exceptions directly can therefore
    look in /root/.queuebash while the Jobs pane and qrun() are correctly using
    the selected user's queue root.  Use `queue exception list-all` so the
    selected queue owner is honoured consistently.
    """
    rc, out = qrun(["exception", "list-all"])
    if rc != 0:
        return error_items("exceptions", rc, out)
    items: List[Item] = []
    for line in split_lines(out):
        if not line.strip():
            continue
        parts = line.split("	", 2)
        qid = parts[0].strip()
        count = parts[1].strip() if len(parts) > 1 else "?"
        summary = parts[2].strip() if len(parts) > 2 else ""
        if not qid:
            continue
        label = f"{qid:<42} {count:>3} overlay(s)"
        items.append(Item(qid, label, summary, {"count": count, "summary": summary}))
    return items


def detail_exception(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No exception overlays."
    _, exc = qrun(["exception", "list", item.key])
    _, explain = qrun(["explain", item.key])
    return "\n".join(["=== EXCEPTIONS ===", exc, "", "=== JOB ===", explain])


def load_restriction_builder(app: "PanelManager") -> List[Item]:
    prefixes = ("time:", "net_usage:", "billing:", "sys:", "path:", "net:", "runnable:", "git:", "db:")
    return [i for i in load_assets(app) if i.key.startswith(prefixes)]


def detail_restriction_builder(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No facilities."
    if item.key == "__error__":
        return item.meta
    family, _, check = item.key.partition(":")
    _, hint = qrun(["asset-hint", item.key])
    variables = [
        "${QUEUEBASH_COMMAND_0}",
        "${QUEUEBASH_COMMAND_ARG_1}",
        "${QUEUEBASH_COMMAND_ARG_1_ABSPATH}",
        "${QUEUEBASH_JOB_WORKDIR}",
        "${JOB_NAME}",
        "${JOB_ID}",
        "${QUEUEBASH_ROOT}",
    ]
    return "\n".join([
        "=== FACILITY HINT ===", hint, "",
        "=== RECORD TEMPLATE ===",
        f'queue_class_shared_asset {family} {check} "TARGET" key=value',
        "",
        "=== SELECTABLE VARIABLES ===",
        *variables,
        "",
        "Enter: generate a restriction line.",
    ])



def load_class_draft(app: "PanelManager") -> List[Item]:
    d = app.class_draft
    items = [
        Item("name", f"name              {d.name or '<unset>'}"),
        Item("purpose", f"purpose           {d.purpose or '<unset>'}"),
        Item("allow_parallel", f"allow parallel    {d.allow_parallel}"),
        Item("max_concurrent", f"max concurrent    {d.max_concurrent}"),
        Item("default_runner", f"default runner    {d.default_runner}"),
        Item("default_timeout", f"default timeout   {d.default_timeout or '-'}"),
        Item("default_kill_after", f"default kill      {d.default_kill_after or '-'}"),
        Item("default_cpu_limit", f"default CPU       {d.default_cpu_limit or '-'}"),
        Item("default_mem_limit", f"default memory    {d.default_mem_limit or '-'}"),
        Item("default_log_cap", f"default log cap   {d.default_log_cap or '-'}"),
        Item("default_run_user", f"default run user  {d.default_run_user or '<current>'}"),
        Item("default_submit_user", f"default submit user {d.default_submit_user or '<current>'}"),
        Item("default_sandbox_level", f"default sandbox   {d.default_sandbox_level or '-'}"),
        Item("default_seccomp_profile", f"default seccomp   {d.default_seccomp_profile or '-'}"),
        Item("default_seccomp_allow", f"seccomp allow     {d.default_seccomp_allow or '-'}"),
        Item("add_restriction", "add restriction   build from asset/cap hint"),
        Item("records", f"records           {len(d.records)}"),
        Item("preview", "preview generated class"),
        Item("validate", "validate draft"),
        Item("save", "save class"),
        Item("clear", "clear draft"),
    ]
    return items


def detail_class_draft(app: "PanelManager", item: Optional[Item]) -> str:
    body = app.class_draft.render()
    selected = item.key if item else ""
    help_text = [
        "=== CLASS CREATOR ===",
        "Enter/x edits selected field or performs selected action.",
        "Use Add restriction to build class records from asset/cap hints.",
        "In restriction prompts, * opens relevant lists: facilities, variables, and modes.",
        "Generated output is record-format only.",
        "",
        "=== SELECTED ===",
        selected or "-",
        "",
        "=== GENERATED CLASS PREVIEW ===",
        body,
    ]
    return "\n".join(help_text)


def load_task_draft(app: "PanelManager") -> List[Item]:
    d = app.task_draft
    return [
        Item("name", f"name                 {d.name or '<unset>'}{(' -> ' + d.normalized_name()) if d.name and d.name != d.normalized_name() else ''}"),
        Item("command", f"command              {d.command or '<unset>'}"),
        Item("job_class", f"class                {d.job_class or '<none>'}"),
        Item("priority", f"priority             {d.priority}"),
        Item("submit_user", f"submit user          {d.submit_user or '<current>'}"),
        Item("execution_dir", f"execution directory  {d.execution_dir or ('<submit user HOME>' if d.submit_user else '<panel cwd>')}"),
        Item("not_before", f"schedule/not-before  {d.not_before or '<now>'}"),
        Item("retries", f"retries              {d.retries}"),
        Item("retry_backoff", f"retry backoff        {d.retry_backoff or '-'}"),
        Item("runner", f"runner override      {d.runner or '-'}"),
        Item("sandbox_level", f"sandbox override     {d.sandbox_level or '-'}"),
        Item("security_reason", f"security reason      {d.security_reason or '-'}"),
        Item("authorisation", f"authorisation code   {d.authorisation_code or '<auto/on-file>'}"),
        Item("no_security_exemption", f"security exemption   {'not required' if d.no_security_exemption_required else 'auto/required by policy'}"),
        Item("cpu_limit", f"CPU override         {d.cpu_limit or '-'}"),
        Item("mem_limit", f"memory override      {d.mem_limit or '-'}"),
        Item("max_log_size", f"log cap override     {d.max_log_size or '-'}"),
        Item("dependencies", f"after success deps    {d.dependencies or '-'}"),
        Item("inherit_env_from", f"inherit env from     {d.inherit_env_from or '-'}"),
        Item("on_success", f"on success hook      {d.on_success or '-'}"),
        Item("on_failure", f"on failure hook      {d.on_failure or '-'}"),
        Item("on_retry_failure", f"on retry hook        {d.on_retry_failure or '-'}"),
        Item("preview", "preview queue submit command"),
        Item("dryrun", "dry-run submit"),
        Item("save", "save as persistent draft"),
        Item("submit", "submit task"),
        Item("clear", "clear task creator draft"),
    ]


def detail_task_draft(app: "PanelManager", item: Optional[Item]) -> str:
    d = app.task_draft
    class_detail = ""
    if d.job_class:
        _, class_detail = qrun(["classes", "explain", d.job_class])
        class_detail = "\n\n=== SELECTED CLASS ===\n" + class_detail
    return "\n".join([
        "=== TASK CREATOR ===",
        "Enter/x edits selected field or performs selected action.",
        "",
        "Submit user uses runuser only for root/operator delegation; current user never uses runuser.",
        "Execution directory is used as PWD_AT_SUBMIT.",
        "If submit user is set and execution directory is blank, submit from that user's HOME.",
        "Scheduling uses queue submit --not-before syntax.",
        "Dependencies use queue submit --after-success / --inherit-env-from.",
        "Hooks use queue submit --on-success / --on-failure / --on-retry-failure.",
        "Examples: 2026-05-23T22:00:00+01:00, +2h, tomorrow 18:00",
        "",
        "=== SUBMIT PREVIEW ===",
        d.render_command(),
        class_detail,
    ])


def load_maintenance(app: "PanelManager") -> List[Item]:
    items: List[Item] = []
    for recipe in MAINTENANCE_RECIPES:
        args = app.maintenance_command_overrides.get(recipe.key, list(recipe.queue_args))
        scheduled = app.maintenance_schedule_overrides.get(recipe.key, recipe.default_not_before)
        pri = app.maintenance_priority_overrides.get(recipe.key, recipe.default_priority)
        label = f"{recipe.label:<28} when={scheduled:<8} pri={pri:<3} risk={recipe.risk}"
        items.append(Item(recipe.key, label, "queue " + " ".join(shlex.quote(a) for a in args), {
            "risk": recipe.risk,
            "not_before": scheduled,
            "priority": pri,
            "command": " ".join(args),
        }))
    return items


def detail_maintenance(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No maintenance recipes."
    recipe = maintenance_recipe_by_key(item.key)
    if recipe is None:
        return "Unknown maintenance recipe."
    args = app.maintenance_command_overrides.get(recipe.key, list(recipe.queue_args))
    scheduled = app.maintenance_schedule_overrides.get(recipe.key, recipe.default_not_before)
    pri = app.maintenance_priority_overrides.get(recipe.key, recipe.default_priority)
    payload = queue_payload_command(args)
    submit_args = app.maintenance_submit_args(recipe, args)
    submit_preview = "queue " + " ".join(shlex.quote(a) for a in submit_args)
    return "\n".join([
        "=== MAINTENANCE / TIDY-UP ACTION ===",
        "",
        f"Recipe:        {recipe.label}",
        f"Risk:          {recipe.risk}",
        f"Class:         {recipe.default_class}",
        f"Default time:  {scheduled}",
        f"Priority:      {pri}",
        "",
        "Purpose:",
        textwrap.fill(recipe.description, width=76),
        "",
        "Default behaviour:",
        "  Queue this as a normal bashqueues job using the QUEUE_MAINTENANCE class.",
        "  Use a not-before delay so tidy-up actions are visible and reversible before they run.",
        "",
        "Queued submit preview:",
        "  " + submit_preview,
        "",
        "Payload command:",
        "  " + payload,
        "",
        "Actions:",
        "  queue     submit this maintenance action as a queue job",
        "  direct    run now in the operator/panel process for urgent recovery",
        "  preview   show queued and direct command previews",
        "  schedule  edit not-before, for example +10m, +1h, tomorrow 02:00",
        "  command   edit the queue command arguments for this recipe",
    ])


def load_queue_users(app: "PanelManager") -> List[Item]:
    rc, out = qrun(["queue-users"], dry_run=False)
    if rc != 0:
        return error_items("queue users", rc, out)
    items: List[Item] = [Item("", "<clear selection: current/default queue>", "")]
    for line in split_lines(out):
        if not line.strip():
            continue
        parts = line.split(None, 1)
        items.append(Item(parts[0], parts[0], parts[1] if len(parts) > 1 else ""))
    return items


def detail_queue_user(app: "PanelManager", item: Optional[Item]) -> str:
    active = app.queue_user or "<current/default>"
    highlighted = item.key if item else ""
    return "\n".join([
        "=== QUEUE OWNER SELECTOR ===",
        "",
        f"Active queue owner: {active}",
        f"Highlighted owner: {highlighted or '<current/default>'}",
        "",
        "Enter/x selects the highlighted queue owner for all panels; choose the clear/current item to return to no selection.",
        "",
        "Command line equivalents:",
        "  queue --queue-user USER list",
        "  queue user USER exception list QID",
        "",
        "Root/admin model:",
        "  safe record operations act directly on the selected queue root",
        "  code-evaluating operations are delegated to the queue owner",
    ])


def queue_job_file_text(qid: str) -> str:
    rc, out = qrun(["show", qid])
    if rc == 0 and out:
        # queue show includes headers and log.  The job env block is enough for
        # simple KEY=value parsing, and extra lines are ignored.
        return out

    rc, out = qrun(["explain", qid])
    return out if rc == 0 else ""


def _parse_shell_scalar(value: str) -> str:
    value = value.strip()
    if value.startswith("'") and value.endswith("'") and len(value) >= 2:
        return value[1:-1]
    if value.startswith('"') and value.endswith('"') and len(value) >= 2:
        return value[1:-1]
    return value


def parse_job_env_from_text(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("==="):
            continue
        key, val = line.split("=", 1)
        if not re.match(r"^[A-Z0-9_]+$", key):
            continue
        out[key] = _parse_shell_scalar(val)
    return out


def parse_job_command_from_text(text: str) -> str:
    # Preferred source is the COMMAND=( ... ) line in queue show.
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("COMMAND=("):
            body = line[len("COMMAND=("):].strip()
            if body.endswith(")"):
                body = body[:-1].strip()
            try:
                return " ".join(shlex.quote(x) for x in shlex.split(body))
            except ValueError:
                return body

    # Fallback: queue explain renders "command: ..."
    for line in text.splitlines():
        if line.strip().startswith("command:"):
            return line.split(":", 1)[1].strip()
    return ""


def parse_job_explain_fields(qid: str) -> dict[str, str]:
    rc, out = qrun(["explain", qid])
    fields: dict[str, str] = {}
    if rc != 0:
        return fields
    for line in out.splitlines():
        m = re.match(r"^\s*([A-Za-z][A-Za-z ]+):\s*(.*?)\s*$", line)
        if not m:
            continue
        key = m.group(1).strip().lower().replace(" ", "_")
        fields[key] = m.group(2).strip()
    return fields


def parse_draft_line(line: str) -> Optional[Item]:
    if not line or line.startswith("DRAFT_ID"):
        return None
    parts = line.split(None, 4)
    if len(parts) < 1 or not parts[0].startswith("DRAFT-"):
        return None
    draft_id = parts[0]
    state = parts[1] if len(parts) > 1 else ""
    updated = parts[2] if len(parts) > 2 else ""
    job_name = parts[3] if len(parts) > 3 else ""
    cmd = parts[4] if len(parts) > 4 else ""
    return Item(draft_id, f"{state:<10} {job_name:<20} {draft_id}", cmd, {
        "state": state, "updated": updated, "job_name": job_name, "command": cmd,
    })


def load_drafts(app: "PanelManager") -> List[Item]:
    rc, out = qrun(["draft", "list"], dry_run=False)
    if rc != 0:
        return error_items("drafts", rc, out)
    return [it for it in (parse_draft_line(line) for line in split_lines(out)) if it]


def detail_draft(app: "PanelManager", item: Optional[Item]) -> str:
    if item is None:
        return "No drafts."
    if item.key == "__error__":
        return item.meta
    _, out = qrun(["draft", "show", item.key])
    return out

class PanelManager:
    DETAIL_TABS = ["Explain", "Class", "Exceptions", "History", "Log", "Tail"]
    CLASS_DETAIL_MODES = ["explain", "show", "validate", "history"]

    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.dry_run = False
        self.queue_user = os.environ.get("QUEUEBASH_SELECTED_USER", "")
        self.class_draft = ClassDraft()
        self.task_draft = TaskDraft()
        self.maintenance_schedule_overrides: dict[str, str] = {}
        self.maintenance_priority_overrides: dict[str, str] = {}
        self.maintenance_command_overrides: dict[str, List[str]] = {}
        self.job_state_filter = "all"
        self.job_text_filter = ""
        self.class_filter = ""
        self.asset_filter = ""
        self.module_filter = ""
        self.detail_tab_index = 0
        self.class_detail_mode = "explain"
        self.menu_line = "Type command/hotkey or * list | F1 Help F2 Cmd F3 Users F4 Jobs F5 Refresh F6 Dry F7 Filter F8 Detail F10 Action F12 Quit"
        self.status = "Ready"
        # Ordered by day-to-day operational use.  Creation/editing panels stay
        # reachable by hotkey/typed command, but the most common live views are
        # early in the tab order.
        self.views = [
            ViewState("jobs", "Jobs", load_jobs, detail_job),
            ViewState("taskdraft", "Task Creator", load_task_draft, detail_task_draft),
            ViewState("drafts", "Drafts", load_drafts, detail_draft),
            ViewState("classes", "Classes", load_classes, detail_class),
            ViewState("assets", "Assets", load_assets, detail_asset),
            ViewState("policies", "Policies", load_policies, detail_policy),
            ViewState("global", "Global Resources", load_global_resources, detail_global_resource),
            ViewState("exceptions", "Exceptions", load_exceptions, detail_exception),
            ViewState("queueusers", "Queue Users", load_queue_users, detail_queue_user),
            ViewState("modules", "Modules", load_modules, detail_module),
            ViewState("maintenance", "Maintenance", load_maintenance, detail_maintenance),
            ViewState("classdraft", "Class Creator", load_class_draft, detail_class_draft),
        ]
        self.view_hotkeys = {
            "jobs": "J",
            "taskdraft": "T",
            "drafts": "D",
            "classes": "C",
            "assets": "A",
            "policies": "P",
            "global": "G",
            "exceptions": "E",
            "queueusers": "U",
            "modules": "O",
            "maintenance": "M",
            "classdraft": "K",
        }
        self.active = 0


    def sandbox_policy_choices(self) -> List[str]:
        rc, out = qrun(["policies", "list", "sandbox"], timeout=5)
        choices = [""]
        if rc == 0:
            for line in out.splitlines():
                line = line.strip()
                if not line or line.startswith("==="):
                    continue
                # queue policies list prints: NAME ORIGIN PATH.  The chooser
                # should offer the policy name, not the whole diagnostic row.
                choices.append(line.split()[0])
        for fallback in ["off", "queue-default", "network-none", "restrict-egress", "strict"]:
            if fallback not in choices:
                choices.append(fallback)
        return choices

    def seccomp_policy_choices(self) -> List[str]:
        rc, out = qrun(["policies", "list", "seccomp"], timeout=5)
        choices = [""]
        if rc == 0:
            for line in out.splitlines():
                line = line.strip()
                if not line or line.startswith("==="):
                    continue
                # queue policies list prints: NAME ORIGIN PATH.  The chooser
                # should offer the policy name, not the whole diagnostic row.
                choices.append(line.split()[0])
        for fallback in ["off", "queue-default", "docker-default", "strict"]:
            if fallback not in choices:
                choices.append(fallback)
        return choices

    @property
    def detail_tab(self) -> str:
        return self.DETAIL_TABS[self.detail_tab_index]

    @property
    def view(self) -> ViewState:
        return self.views[self.active]

    def apply_job_filters(self, items: List[Item]) -> List[Item]:
        out = items
        if self.job_state_filter != "all":
            out = [it for it in out if it.fields.get("state") == self.job_state_filter]
        if self.job_text_filter:
            f = self.job_text_filter.lower()
            out = [it for it in out if f in it.key.lower() or f in it.label.lower() or f in it.meta.lower()]
        return out

    def setup(self) -> None:
        global PANEL_QUEUE_USER
        PANEL_QUEUE_USER = self.queue_user
        curses.curs_set(0)
        self.stdscr.keypad(True)
        curses.use_default_colors()
        for v in self.views:
            v.refresh(self)

    def safe_addstr(self, y: int, x: int, text: str, attr: int = 0) -> None:
        maxy, maxx = self.stdscr.getmaxyx()
        if 0 <= y < maxy and 0 <= x < maxx:
            self.stdscr.addstr(y, x, text[: maxx - x - 1], attr)

    def draw_box(self, y: int, x: int, h: int, w: int, title: str = "") -> None:
        if h < 2 or w < 2:
            return
        self.stdscr.addch(y, x, curses.ACS_ULCORNER)
        self.stdscr.addch(y, x + w - 1, curses.ACS_URCORNER)
        self.stdscr.addch(y + h - 1, x, curses.ACS_LLCORNER)
        self.stdscr.addch(y + h - 1, x + w - 1, curses.ACS_LRCORNER)
        for xx in range(x + 1, x + w - 1):
            self.stdscr.addch(y, xx, curses.ACS_HLINE)
            self.stdscr.addch(y + h - 1, xx, curses.ACS_HLINE)
        for yy in range(y + 1, y + h - 1):
            self.stdscr.addch(yy, x, curses.ACS_VLINE)
            self.stdscr.addch(yy, x + w - 1, curses.ACS_VLINE)
        if title:
            self.safe_addstr(y, x + 2, f" {title} ", curses.A_BOLD)

    def draw_tabs(self, y: int) -> int:
        """Draw top-level view tabs over up to two rows.

        The panel now has enough operational views that a single line becomes
        cramped on normal terminals.  We keep hotkey-labelled tabs, wrap once,
        and return the number of rows consumed so the body layout can move down
        without guessing.
        """
        _, w = self.stdscr.getmaxyx()
        max_rows = 2
        row = 0
        x = 2
        used_rows = 1
        # Clear both possible tab rows first, so stale text is not left behind
        # when the terminal is resized or tabs fit on one row again.
        for yy in range(y, y + max_rows):
            self.safe_addstr(yy, 0, " " * max(0, w - 1))
        for i, v in enumerate(self.views):
            hotkey = self.view_hotkeys.get(v.name, "?")
            label = f" [{hotkey}] {v.title} "
            if x + len(label) >= w - 1 and row < max_rows - 1:
                row += 1
                used_rows = max(used_rows, row + 1)
                x = 2
            remaining = w - x - 1
            if remaining <= 1:
                break
            shown = label[:remaining]
            attr = curses.A_REVERSE | curses.A_BOLD if i == self.active else curses.A_NORMAL
            self.safe_addstr(y + row, x, shown, attr)
            x += len(label) + 1
        return used_rows

    def draw_detail_tabs(self, y: int, x: int, w: int) -> None:
        xx = x
        if self.view.name == "jobs":
            for i, tab in enumerate(self.DETAIL_TABS):
                label = f" {tab} "
                attr = curses.A_REVERSE | curses.A_BOLD if i == self.detail_tab_index else curses.A_NORMAL
                self.safe_addstr(y, xx, label[: max(0, w - (xx - x))], attr)
                xx += len(label) + 1
            return
        if self.view.name == "classes":
            for mode in self.CLASS_DETAIL_MODES:
                label = f" {mode.title()} "
                attr = curses.A_REVERSE | curses.A_BOLD if mode == self.class_detail_mode else curses.A_NORMAL
                self.safe_addstr(y, xx, label[: max(0, w - (xx - x))], attr)
                xx += len(label) + 1
            return

    def draw(self) -> None:
        global PANEL_QUEUE_USER
        PANEL_QUEUE_USER = self.queue_user
        self.stdscr.erase()
        h, w = self.stdscr.getmaxyx()
        src_label = Path(QUEUE_SOURCE).name if QUEUE_SOURCE else "NO QUEUE SOURCE"
        mode = "DRY-RUN" if self.dry_run else "LIVE"
        owner = self.queue_user or "default"
        header = f"QUEUEBASH PANEL MANAGER   src: {src_label}  mode: {mode}  owner: {owner}  root: {selected_queue_root_display(self.queue_user)}"
        self.safe_addstr(0, 2, header[: max(0, w - 4)], curses.A_BOLD if self.dry_run else curses.A_NORMAL)
        tab_rows = self.draw_tabs(1)

        filter_y = 1 + tab_rows
        filter_line = f"state={self.job_state_filter} text={self.job_text_filter or '-'} class={self.class_filter or '-'} asset={self.asset_filter or '-'} module={self.module_filter or '-'}"
        self.safe_addstr(filter_y, 2, filter_line[: w - 4])

        left_w = max(38, w // 2)
        right_w = w - left_w - 1
        top = filter_y + 1
        # Reserve three bottom rows:
        #   separator
        #   menu/help keys
        #   status/message
        body_h = max(6, h - 7)

        self.draw_box(top, 0, body_h, left_w, self.view.title)
        self.draw_box(top, left_w, body_h, right_w, "Detail / Hint / Output")
        self.draw_detail_tabs(top, left_w + 2, right_w - 4)

        self.draw_left(top + 1, 1, body_h - 2, left_w - 2)
        self.draw_right(top + 1, left_w + 1, body_h - 2, right_w - 2)

        self.safe_addstr(h - 3, 0, "─" * (w - 1))
        self.safe_addstr(h - 2, 1, self.menu_line[: w - 2], curses.A_REVERSE)
        self.safe_addstr(h - 1, 1, self.status[: w - 2])
        self.stdscr.refresh()

    def draw_left(self, y: int, x: int, h: int, w: int) -> None:
        v = self.view
        if not v.items:
            self.safe_addstr(y, x, "No entries.")
            return
        if v.selected < v.scroll:
            v.scroll = v.selected
        if v.selected >= v.scroll + h:
            v.scroll = v.selected - h + 1
        for row in range(h):
            idx = v.scroll + row
            if idx >= len(v.items):
                break
            it = v.items[idx]
            label = it.label + (f"  {it.meta}" if it.meta else "")
            self.safe_addstr(y + row, x, label[:w], curses.A_REVERSE if idx == v.selected else curses.A_NORMAL)

    def draw_right(self, y: int, x: int, h: int, w: int) -> None:
        v = self.view
        lines: List[str] = []
        for line in split_lines(v.detailer(self, v.current())):
            if len(line) > w:
                lines.extend(textwrap.wrap(line, width=max(20, w), replace_whitespace=False))
            else:
                lines.append(line)
        v.detail_scroll = max(0, min(v.detail_scroll, max(0, len(lines) - h)))
        for row in range(h):
            idx = v.detail_scroll + row
            if idx >= len(lines):
                break
            self.safe_addstr(y + row, x, lines[idx][:w])

    def cycle_right_pane_mode(self, delta: int = 1) -> None:
        """Cycle the persistent right-hand pane mode for the current view."""
        if self.view.name == "classes":
            modes = self.CLASS_DETAIL_MODES
            try:
                idx = modes.index(self.class_detail_mode)
            except ValueError:
                idx = 0
            self.class_detail_mode = modes[(idx + delta) % len(modes)]
            self.view.detail_scroll = 0
            self.status = f"Class right panel mode: {self.class_detail_mode}"
            return
        if self.view.name == "jobs":
            self.detail_tab_index = (self.detail_tab_index + delta) % len(self.DETAIL_TABS)
            self.view.detail_scroll = 0
            self.status = f"Job right panel mode: {self.detail_tab}"
            return
        self.status = "Right panel mode cycling applies on Jobs and Classes"

    def prompt(self, prompt: str, default: str = "") -> str:
        h, w = self.stdscr.getmaxyx()
        curses.echo()
        curses.curs_set(1)
        self.safe_addstr(h - 1, 1, " " * (w - 2), curses.A_REVERSE)
        label = f"{prompt}{f' [{default}]' if default else ''}: "
        self.safe_addstr(h - 1, 1, label, curses.A_REVERSE)
        try:
            raw = self.stdscr.getstr(h - 1, min(len(label) + 1, w - 2), max(1, w - len(label) - 4))
            val = raw.decode(errors="ignore").strip()
            return val or default
        finally:
            curses.noecho()
            curses.curs_set(0)

    def prompt_choice(
        self,
        prompt: str,
        choices: Sequence[str],
        default: str = "",
        allow_free: bool = False,
        aliases: Optional[dict[str, str]] = None,
    ) -> str:
        """Prompt for a value with common panel choice behaviour.

        Field convention:
          - blank keeps the default
          - * opens the scrollable/searchable chooser
          - a number selects from the available list
          - first unique letters select a command/value
          - any unique substring selects a command/value
          - free-text fields may still accept raw text when no choice matches
        """
        choices = [c for c in choices if c]
        label = prompt
        if choices:
            label += " (* list; unique letters/part accepted)"
        raw = self.prompt(label, default)
        if raw == "*":
            list_choices = list(choices)
            if default or allow_free:
                list_choices = ["<current/default>"] + list_choices
            picked = self.select_from_list(prompt, list_choices, default or "<current/default>")
            if picked in {"<current/default>", "<current>", "<none>", "<default>"}:
                return ""
            return picked or default
        if not raw:
            return default
        if _normalise_optional_user(raw) == "" and raw.strip().casefold() in {"-", "none", "current", "default", "clear", "unset", "no", "off"}:
            return ""
        if choices:
            resolved, diagnostic = resolve_unique_choice(raw, choices, aliases)
            if resolved:
                return resolved
            if not allow_free:
                self.status = diagnostic or "No matching choice"
                return default
        return raw

    def edit_job_reference_field(self, prompt: str, current: str = "", supplied: str = "") -> str:
        """Edit a dependency/inherited-env job-reference field.

        These fields refer to queue jobs by job name or QID.  They should use
        the same chooser behaviour as other fields, but with queue jobs as the
        choice list and an explicit clear option.  A bare `*` opens the list; it
        must not be stored as a literal wildcard.
        """
        choices = queue_job_reference_choices(self)
        clear_tokens = {"", "<clear>", "<current/default>", "<current>", "<none>", "<default>", "-", "none", "current", "default", "clear", "unset", "no", "off"}
        raw = supplied.strip() if supplied is not None else ""
        if raw == "*":
            picked = self.select_from_list(prompt + " queue reference", choices, current or "<clear>")
            return "" if picked.strip().casefold() in clear_tokens else picked
        if raw:
            if raw.casefold() in clear_tokens:
                return ""
            resolved, diagnostic = resolve_unique_choice(raw, choices)
            if resolved:
                return "" if resolved.strip().casefold() in clear_tokens else resolved
            # Preserve manually-entered comma/space separated dependency lists.
            return raw
        picked = self.prompt_choice(prompt + " queue reference", choices, current, allow_free=True)
        return "" if picked.strip().casefold() in clear_tokens else picked

    def select_from_list(self, title: str, choices: Sequence[str], default: str = "") -> str:
        """Scrollable/searchable chooser used by '*' field entry.

        Up/down moves selection, typing filters by substring, Backspace edits
        the filter, Enter selects, and q/Esc cancels.
        """
        choices = [c for c in choices if c]
        if not choices:
            self.status = "No selectable values"
            return ""

        h, w = self.stdscr.getmaxyx()
        ph = min(h - 4, max(12, min(h - 4, len(choices) + 6)))
        pw = min(w - 4, max(64, min(w - 4, max(len(c) for c in choices) + 10)))
        y, x = max(1, (h - ph) // 2), max(1, (w - pw) // 2)
        content_h = max(1, ph - 5)
        filter_text = ""
        selected = 0

        if default:
            try:
                selected = choices.index(default)
            except ValueError:
                selected = 0

        while True:
            norm_filter = normalize_panel_token(filter_text)
            visible = [c for c in choices if not norm_filter or norm_filter in normalize_panel_token(c)]
            if not visible:
                visible = []
                selected = 0
            else:
                selected = max(0, min(selected, len(visible) - 1))

            top_index = 0
            if visible and selected >= content_h:
                top_index = selected - content_h + 1

            for yy in range(y, min(y + ph, h)):
                self.safe_addstr(yy, x, " " * max(0, min(pw, w - x - 1)))
            self.draw_box(y, x, ph, pw, title)
            self.safe_addstr(y + 1, x + 2, f"Filter: {filter_text or '*'}"[: pw - 4], curses.A_BOLD)
            self.safe_addstr(y + 2, x + 2, "Type part, ↑/↓ move, Enter select, Esc/q cancel"[: pw - 4])

            if not visible:
                self.safe_addstr(y + 4, x + 2, "No matches."[: pw - 4], curses.A_REVERSE)
            else:
                for row in range(content_h):
                    idx = top_index + row
                    if idx >= len(visible):
                        break
                    label = f"{idx + 1:>2}: {visible[idx]}"
                    attr = curses.A_REVERSE if idx == selected else curses.A_NORMAL
                    self.safe_addstr(y + 4 + row, x + 2, label[: pw - 4], attr)

            self.stdscr.refresh()
            k = self.stdscr.getch()
            if k in (27, ord("q"), ord("Q")):
                self.draw()
                return ""
            if k in (10, 13):
                self.draw()
                return visible[selected] if visible else ""
            if k == curses.KEY_DOWN:
                selected += 1
            elif k == curses.KEY_UP:
                selected -= 1
            elif k == curses.KEY_NPAGE:
                selected += content_h
            elif k == curses.KEY_PPAGE:
                selected -= content_h
            elif k in (curses.KEY_BACKSPACE, 127, 8):
                filter_text = filter_text[:-1]
                selected = 0
            elif 32 <= k <= 126:
                filter_text += chr(k)
                selected = 0


    def switch_view(self, target: str) -> bool:
        aliases = {
            "queueusers": ["queueusers", "queue users", "users", "user", "owner", "owners", "qu"],
            "jobs": ["jobs", "job", "list", "queue", "work", "j"],
            "drafts": ["drafts", "draft", "dr"],
            "classes": ["classes", "class", "cls", "cl"],
            "assets": ["assets", "asset", "as"],
            "policies": ["policies", "policy", "pol", "site policy", "shared policy", "p"],
            "modules": ["modules", "module", "mods", "mod", "caps", "cap", "plugins", "plugin", "mo"],
            "global": ["global", "globals", "global resources", "resources", "claims", "claim", "gr", "g"],
            "maintenance": ["maintenance", "maint", "fixes", "fix", "tidy", "tidyup", "cleanup", "clean", "logs", "m"],
            "exceptions": ["exceptions", "exception", "exc", "ex"],
            "classdraft": ["classcreator", "class creator", "classdraft", "newclass", "cc"],
            "taskdraft": ["taskcreator", "task creator", "taskdraft", "task", "newtask", "tc", "submitter"],
        }
        choices: list[str] = []
        canonical: dict[str, str] = {}
        for name, vals in aliases.items():
            for val in vals:
                choices.append(val)
                canonical[val] = name
        resolved, diagnostic = resolve_unique_choice(target, choices)
        if not resolved:
            self.status = diagnostic or f"Unknown panel: {target}"
            return False
        view_name = canonical.get(resolved, resolved)
        for i, v in enumerate(self.views):
            if v.name == view_name:
                self.active = i
                self.status = f"Panel: {v.title}"
                return True
        self.status = f"Panel not available: {view_name}"
        return False

    def select_item_by_text(self, view: ViewState, text: str) -> bool:
        if not text:
            return False
        lookup: dict[str, int] = {}
        choices: list[str] = []
        for idx, it in enumerate(view.items):
            if it.key and it.key != "__error__":
                lookup[it.key] = idx
                lookup[it.label] = idx
                choices.append(it.key)
                choices.append(it.label)
        resolved, _ = resolve_unique_choice(text, choices)
        if resolved and resolved in lookup:
            view.selected = lookup[resolved]
            view.detail_scroll = 0
            return True
        norm = normalize_panel_token(text)
        matches = [idx for idx, it in enumerate(view.items) if norm and (norm in normalize_panel_token(it.key) or norm in normalize_panel_token(it.label))]
        if len(matches) == 1:
            view.selected = matches[0]
            view.detail_scroll = 0
            return True
        return False

    def command_completion_choices(self, current: str) -> List[str]:
        """Return contextual command-line expansions for the AS/400-style command line.

        Ordering is intentional.  Object/action commands for the current context
        are listed first.  Cross-panel destinations are always listed last so a
        Jobs completion list starts with job commands, a Classes list starts with
        class commands, and panel jumps remain discoverable without pushing the
        useful local work off the top of the popup.
        """
        raw = (current or "").strip()
        try:
            parts = shlex.split(raw) if raw and raw != "*" else []
        except ValueError:
            parts = raw.split()

        choices: list[str] = []

        def add(value: str) -> None:
            if value and value not in choices:
                choices.append(value)

        def add_user_choices() -> None:
            add("user clear")
            for it in load_queue_users(self):
                if it.key != "__error__" and it.key:
                    add(f"user {it.key}")

        def add_panel_choices() -> None:
            # Panels are deliberately appended last.  This keeps the popup useful
            # in AS/400-style command entry: objects/actions first, navigation at
            # the bottom.
            for v in self.views:
                add(f"panel:{v.name}")
                title_name = v.title.lower().replace(" ", "-")
                if title_name and title_name != v.name:
                    add(f"panel:{title_name}")

        def finish(include_users: bool = True, include_panels: bool = True) -> list[str]:
            if include_users:
                add_user_choices()
            if include_panels:
                add_panel_choices()
            return choices

        head = parts[0].casefold() if parts else ""
        norm_head = normalize_panel_token(head)

        def class_action_choices(prefix: str) -> None:
            for action in ["explain", "show", "validate", "enable", "disable", "edit", "history", "backups", "rollback", "delete", "use"]:
                add(f"{prefix} {action}")

        # No command yet: show useful current-object commands first, then user
        # selectors, then panel jumps at the bottom.
        if not parts:
            if self.view.name == "queueusers":
                # Queue Users panel: user choices first, panels last.
                return finish(include_users=True, include_panels=True)
            if self.view.name == "classes":
                for it in self.view.items:
                    if it.key != "__error__":
                        add(f"class {it.key}")
                cur = self.view.current()
                if cur and cur.key != "__error__":
                    class_action_choices(f"class {cur.key}")
                    for action in ["explain", "show", "validate", "enable", "disable", "edit", "history", "rollback", "delete", "refresh", "use"]:
                        add(action)
                return finish(include_users=True, include_panels=True)
            if self.view.name == "assets":
                for it in self.view.items:
                    if it.key != "__error__":
                        add(f"asset {it.key}")
                cur = self.view.current()
                if cur and cur.key != "__error__":
                    for action in ["explain", "hint", "validate", "enable", "disable", "delete", "refresh", "rollback"]:
                        add(f"asset {cur.key} {action}")
                        add(action)
                return finish(include_users=True, include_panels=True)
            if self.view.name == "jobs":
                cur = self.view.current()
                if cur and cur.key != "__error__":
                    for action in ["history", "show", "tail", "explain", "exception", "change priority", "kill", "delete", "undelete", "edit", "copy", "cancel", "resubmit"]:
                        add(f"job {cur.key} {action}")
                    for action in ["history", "show", "tail", "explain", "exception", "change priority", "kill", "delete", "undelete", "edit", "copy", "cancel", "resubmit"]:
                        add(f"job {action}")
                return finish(include_users=True, include_panels=True)
            if self.view.name == "modules":
                for it in self.view.items:
                    if it.key != "__error__":
                        add(f"module {it.key} explain")
                        add(f"module {it.key} enable")
                        add(f"module {it.key} disable")
                return finish(include_users=True, include_panels=True)
            if self.view.name == "maintenance":
                for it in self.view.items:
                    if it.key != "__error__":
                        add(f"maint {it.key} preview")
                        add(f"maint {it.key} queue")
                        add(f"maint {it.key} direct")
                return finish(include_users=True, include_panels=True)
            if self.view.name == "taskdraft":
                for field in ["name", "command", "class", "priority", "schedule", "runner", "preview", "dryrun", "save", "submit", "clear"]:
                    add(f"task {field}")
                return finish(include_users=True, include_panels=True)
            if self.view.name == "classdraft":
                for field in ["name", "purpose", "restriction", "record", "records", "preview", "validate", "save", "clear"]:
                    add(f"classcreator {field}")
                    add(field)
                for it in load_assets(self):
                    if it.key != "__error__":
                        add(f"classcreator restriction {it.key}")
                return finish(include_users=True, include_panels=True)
            return finish(include_users=True, include_panels=True)

        # If a panel jump has been chosen, '*' should list the objects/actions
        # for the destination rather than forcing the operator to press Enter.
        if norm_head.startswith("panel") or ":" in head:
            target = head.split(":", 1)[1] if ":" in head else (parts[1] if len(parts) > 1 else "")
            if self.switch_view(target):
                self.view.refresh(self)
                return self.command_completion_choices("")
            return finish(include_users=False, include_panels=True)

        policy_heads = ["policy", "policies", "pol", "site-policy", "shared-policy"]
        policy_resolved, _ = resolve_unique_choice(head, policy_heads)
        if policy_resolved:
            self.execute_policy_command(tail)
            return

        global_heads = ["global", "globals", "claim", "claims", "resource", "resources"]
        global_resolved, _ = resolve_unique_choice(head, global_heads)
        if global_resolved:
            add("global claims")
            add("global health")
            add("global cleanup --dryrun")
            gv = next((v for v in self.views if v.name == "global"), None)
            if gv and not gv.items:
                gv.refresh(self)
            if gv:
                for it in gv.items:
                    if it.key != "__error__":
                        add(f"global claim {it.key}")
            return finish(include_users=True, include_panels=True)

        module_heads = ["module", "modules", "mod", "mods", "plugin", "plugins", "cap", "caps"]
        module_resolved, _ = resolve_unique_choice(head, module_heads)
        if module_resolved:
            mods_view = next((v for v in self.views if v.name == "modules"), None)
            if mods_view and not mods_view.items:
                mods_view.refresh(self)
            prefix_parts = parts[1:] if module_resolved not in {"cap", "caps"} else ["cap", *parts[1:]]
            if not prefix_parts:
                if mods_view:
                    for it in mods_view.items:
                        if it.key != "__error__":
                            add(f"module {it.key} explain")
                            add(f"module {it.key} enable")
                            add(f"module {it.key} disable")
                add("module refresh class classes")
                add("module refresh asset assets.d")
                add("module refresh cap caps.d")
                return finish(include_users=False, include_panels=True)
            target = " ".join(prefix_parts)
            if mods_view:
                n = normalize_panel_token(target)
                for it in mods_view.items:
                    if it.key != "__error__" and n and (n in normalize_panel_token(it.key) or n in normalize_panel_token(it.label)):
                        add(f"module {it.key} explain")
                        add(f"module {it.key} enable")
                        add(f"module {it.key} disable")
            return finish(include_users=False, include_panels=True)

        classcreator_heads = ["classcreator", "class-creator", "classdraft", "newclass", "cc", "restriction", "restrict"]
        classcreator_resolved, _ = resolve_unique_choice(head, classcreator_heads, {"res": "restriction", "restr": "restriction"})
        if classcreator_resolved:
            fields = ["name", "purpose", "restriction", "record", "records", "preview", "validate", "save", "clear"]
            if len(parts) == 1:
                for f in fields:
                    add(f"classcreator {f}")
                for it in load_assets(self):
                    if it.key != "__error__":
                        add(f"classcreator restriction {it.key}")
            else:
                wants_restriction = any(normalize_panel_token(x) in {"restriction", "restrict", "asset"} for x in parts[1:]) or classcreator_resolved in {"restriction", "restrict"}
                if wants_restriction:
                    for it in load_assets(self):
                        if it.key != "__error__":
                            add(f"classcreator restriction {it.key}")
                    for it in load_modules(self):
                        if it.key.startswith("cap:"):
                            add(f"classcreator restriction {it.key}")
            return finish(include_users=False, include_panels=True)

        # class <partial> *  -> class <resolved-class>
        # class <class> *    -> class <class> <action>
        class_heads = ["class", "classes", "cls"]
        class_resolved, _ = resolve_unique_choice(head, class_heads)
        if class_resolved:
            classes = [it.key for it in load_classes(self) if it.key != "__error__"]
            if len(parts) == 1:
                for cname in classes:
                    add(f"class {cname}")
                return finish(include_users=False, include_panels=True)
            target = parts[1]
            resolved_class, _ = resolve_unique_choice(target, classes)
            if not resolved_class:
                n = normalize_panel_token(target)
                for cname in classes:
                    if n and n in normalize_panel_token(cname):
                        add(f"class {cname}")
                return finish(include_users=False, include_panels=True)
            if len(parts) == 2:
                class_action_choices(f"class {resolved_class}")
            else:
                action_text = " ".join(parts[2:])
                action_choices = ["explain", "show", "validate", "enable", "disable", "edit", "history", "backups", "rollback", "delete", "use"]
                resolved_action, _ = resolve_unique_choice(action_text, action_choices, {"hist": "history", "h": "history"})
                add(f"class {resolved_class} {resolved_action or action_text}")
            return finish(include_users=False, include_panels=True)

        asset_heads = ["asset", "assets", "facility", "facilities"]
        asset_resolved, _ = resolve_unique_choice(head, asset_heads)
        if asset_resolved:
            assets = [it.key for it in load_assets(self) if it.key != "__error__"]
            if len(parts) == 1:
                for aname in assets:
                    add(f"asset {aname}")
                return finish(include_users=False, include_panels=True)
            target = parts[1]
            resolved_asset, _ = resolve_unique_choice(target, assets)
            if not resolved_asset:
                n = normalize_panel_token(target)
                for aname in assets:
                    if n and n in normalize_panel_token(aname):
                        add(f"asset {aname}")
                return finish(include_users=False, include_panels=True)
            actions = ["explain", "hint", "validate", "enable", "disable", "delete", "refresh", "rollback"]
            if len(parts) == 2:
                for action in actions:
                    add(f"asset {resolved_asset} {action}")
            else:
                action_text = " ".join(parts[2:])
                resolved_action, _ = resolve_unique_choice(action_text, actions, {"x": "explain", "h": "hint", "on": "enable", "off": "disable"})
                add(f"asset {resolved_asset} {resolved_action or action_text}")
            return finish(include_users=False, include_panels=True)

        job_heads = ["job", "jobs", "qid", "history", "hist", "show", "tail", "explain"]
        job_resolved, _ = resolve_unique_choice(head, job_heads, {"h": "history"})
        if job_resolved:
            jobs_view = next((v for v in self.views if v.name == "jobs"), None)
            if jobs_view and not jobs_view.items:
                jobs_view.refresh(self)
            if len(parts) == 1:
                if jobs_view:
                    for it in jobs_view.items[:50]:
                        if it.key != "__error__":
                            add(f"job {it.key} history")
                return finish(include_users=False, include_panels=True)
            frag = parts[1]
            if jobs_view:
                n = normalize_panel_token(frag)
                for it in jobs_view.items:
                    if it.key != "__error__" and n and (n in normalize_panel_token(it.key) or n in normalize_panel_token(it.label) or n in normalize_panel_token(it.meta)):
                        for action in ["history", "show", "tail", "explain", "exception", "change priority", "kill", "delete", "undelete", "edit", "copy"]:
                            add(f"job {it.key} {action}")
            return finish(include_users=False, include_panels=True)

        maint_heads = ["maintenance", "maint", "fixes", "fix", "tidy", "tidyup", "clean", "cleanup", "logs"]
        maint_resolved, _ = resolve_unique_choice(head, maint_heads)
        if maint_resolved:
            maint_view = next((v for v in self.views if v.name == "maintenance"), None)
            if maint_view and not maint_view.items:
                maint_view.refresh(self)
            if maint_view:
                if len(parts) == 1:
                    for it in maint_view.items:
                        if it.key != "__error__":
                            add(f"maint {it.key}")
                elif len(parts) == 2:
                    for action in ["preview", "queue", "direct", "schedule", "priority", "command", "reset"]:
                        add(f"maint {parts[1]} {action}")
            return finish(include_users=False, include_panels=True)

        task_heads = ["task", "taskcreator", "task-creator", "taskdraft", "newtask", "submitter", "tc"]
        task_resolved, _ = resolve_unique_choice(head, task_heads)
        if task_resolved:
            fields = ["name", "command", "class", "priority", "submit-user", "directory", "schedule", "retries", "backoff", "runner", "preview", "dryrun", "save", "submit", "clear"]
            if len(parts) == 1:
                for f in fields:
                    add(f"task {f}")
            elif len(parts) == 2 and normalize_panel_token(parts[1]) in {"class", "cls"}:
                for it in load_classes(self):
                    if it.key != "__error__":
                        add(f"task class {it.key}")
            return finish(include_users=False, include_panels=True)

        classcreator_heads = ["classcreator", "class-creator", "classdraft", "newclass", "cc", "restriction", "restrict"]
        classcreator_resolved, _ = resolve_unique_choice(head, classcreator_heads, {"res": "restriction", "restr": "restriction"})
        if classcreator_resolved:
            fields = ["name", "purpose", "restriction", "record", "records", "preview", "validate", "save", "clear"]
            if len(parts) == 1:
                for f in fields:
                    add(f"classcreator {f}")
                for it in load_assets(self):
                    if it.key != "__error__":
                        add(f"classcreator restriction {it.key}")
            else:
                wants_restriction = any(normalize_panel_token(x) in {"restriction", "restrict", "asset"} for x in parts[1:]) or classcreator_resolved in {"restriction", "restrict"}
                if wants_restriction:
                    for it in load_assets(self):
                        if it.key != "__error__":
                            add(f"classcreator restriction {it.key}")
                    for it in load_modules(self):
                        if it.key.startswith("cap:"):
                            add(f"classcreator restriction {it.key}")
            return finish(include_users=False, include_panels=True)

        return finish(include_users=True, include_panels=True)

    def choose_command_expansion(self, current: str) -> str:
        choices = self.command_completion_choices(current)
        if not choices:
            self.status = "No command completions available"
            return current
        picked = self.select_from_list("Command completions", choices, current if current and current != "*" else "")
        return picked or current

    def command_prompt(self, initial: str = "") -> None:
        """AS/400-style command entry.

        '*' in this prompt opens a context-aware list.  Choosing an entry does
        not immediately execute it; it expands the command line, so the operator
        can continue with another '*' or edit/confirm the expanded command.
        """
        current = initial or ""
        while True:
            text = self.prompt("Command (* list)", current)
            # prompt() shows the initial character as a default, but curses getstr()
            # does not place that character into the editable buffer.  When the
            # operator simply types the rest of the command, preserve the first
            # key instead of swallowing it ("e" + "xpl" => "expl").
            if initial and text and text != current and not text.startswith(current):
                text = current + text
            if not text:
                return
            if text.strip() == "*":
                current = self.choose_command_expansion(current)
                continue
            if text.endswith(" *") or text.endswith("*"):
                current = self.choose_command_expansion(text[:-1].strip())
                continue
            self.execute_panel_command(text)
            return

    def execute_panel_command(self, text: str) -> None:
        raw = (text or "").strip()
        if not raw:
            return
        try:
            parts = shlex.split(raw)
        except ValueError as exc:
            self.status = f"Command parse error: {exc}"
            return
        if not parts:
            return
        head = parts[0]
        tail = parts[1:]

        if head.casefold().startswith("panel:"):
            self.switch_view(head.split(":", 1)[1])
            return

        global_actions = ["help", "refresh", "filter", "dryrun", "live", "action", "exception", "clear-exception", "quit"]
        action_aliases = {
            "?": "help", "h": "help",
            "r": "refresh", "ref": "refresh",
            "f": "filter",
            "d": "dryrun", "dry": "dryrun",
            "l": "live",
            "x": "action", "enter": "action",
            "e": "exception",
            "ce": "clear-exception",
            "q": "quit", "exit": "quit",
        }
        resolved, _ = resolve_unique_choice(head, global_actions, action_aliases)
        if resolved == "help":
            self.help(); return
        if resolved == "refresh":
            self.refresh_current(); return
        if resolved == "filter":
            self.set_filter(); return
        if resolved == "dryrun":
            self.dry_run = True; self.status = "Dry-run mode ON"; return
        if resolved == "live":
            self.dry_run = False; self.status = "Dry-run mode OFF"; return
        if resolved == "action":
            self.action(); return
        if resolved == "exception":
            if self.view.name == "jobs": self.add_exception()
            else: self.status = "Exception applies on Jobs panel"
            return
        if resolved == "clear-exception":
            if self.view.name in {"jobs", "exceptions"}: self.clear_exception()
            else: self.status = "Clear exception applies on Jobs/Exceptions"
            return
        if resolved == "quit":
            self.status = "Use F12/Esc to quit the panel"
            return

        # Classes/Assets panel object context: bare typed actions act on the selected object.
        if self.view.name == "classes":
            class_context_heads = ["select", "explain", "show", "validate", "enable", "disable", "edit", "delete", "refresh", "rollback", "history", "backups", "use"]
            class_context_resolved, _ = resolve_unique_choice(head, class_context_heads, {"hist": "history", "h": "history", "cat": "show", "on": "enable", "off": "disable"})
            if class_context_resolved:
                self.execute_class_command([head] + tail)
                return

        if self.view.name == "assets":
            asset_context_heads = ["select", "explain", "hint", "show", "validate", "enable", "disable", "delete", "refresh", "rollback"]
            asset_context_resolved, _ = resolve_unique_choice(head, asset_context_heads, {"x": "explain", "h": "hint", "cat": "show", "on": "enable", "off": "disable"})
            if asset_context_resolved:
                self.execute_asset_command([head] + tail)
                return

        # Jobs panel object context: bare typed actions act on the selected job.
        # Examples on Jobs: "kill", "delete", "undelete", "change priority 5", "edit".
        if self.view.name == "jobs":
            job_context_heads = ["change", "priority", "prio", "kill", "delete", "undelete", "edit", "cancel", "resubmit", "authorise", "authorize", "history", "show", "tail", "explain", "exception", "copy"]
            job_context_resolved, _ = resolve_unique_choice(head, job_context_heads, {"del": "delete", "undel": "undelete", "restore": "undelete", "pri": "priority", "p": "priority", "hist": "history", "h": "history", "ex": "exception", "cp": "copy", "auth": "authorise"})
            if job_context_resolved:
                self.execute_job_command(parts)
                return

        # Context-first command handling.  When the operator is already in the
        # Task Creator/job editor, a bare action such as "submit", "save",
        # "preview", or "clear" should apply to this task.  Without this guard,
        # bare words are first tested against global/panel/job routing and can
        # feel detached from the current editor.
        #
        # Example expected behaviour:
        #   Task Creator screen + typed "submit" => task submit
        if self.view.name == "taskdraft":
            task_context_actions = [
                "name", "command", "class", "priority", "submit-user", "user",
                "directory", "cwd", "schedule", "not-before", "retries",
                "backoff", "runner", "cpu", "memory", "mem", "log",
                "preview", "dryrun", "save", "submit", "clear",
            ]
            task_context_aliases = {
                "n": "name", "cmd": "command", "c": "class", "cls": "class",
                "p": "priority", "pri": "priority", "su": "submit-user",
                "submituser": "submit-user", "u": "user", "dir": "directory",
                "pwd": "cwd", "when": "schedule", "nb": "not-before",
                "r": "retries", "retry": "retries", "b": "backoff",
                "run": "runner", "m": "memory", "maxlog": "log",
                "logcap": "log", "pv": "preview", "dr": "dryrun",
                "s": "save", "go": "submit", "sub": "submit",
                "reset": "clear",
            }
            task_context, _ = resolve_unique_choice(head, task_context_actions, task_context_aliases)
            if task_context:
                self.execute_task_command(parts)
                return

        # Class Creator context: bare typed commands apply to the current
        # class draft, including hint-driven restriction building.
        if self.view.name == "classdraft":
            classdraft_context_actions = [
                "name", "purpose", "allow-parallel", "parallel", "max-concurrent",
                "runner", "timeout", "kill-after", "cpu", "memory", "log",
                "run-user", "submit-user", "sandbox", "restriction", "restrict", "asset",
                "record", "records", "preview", "validate", "save", "clear",
            ]
            classdraft_aliases = {
                "n": "name", "p": "purpose", "ap": "allow-parallel",
                "mc": "max-concurrent", "r": "runner", "t": "timeout",
                "ka": "kill-after", "mem": "memory", "maxlog": "log",
                "ru": "run-user", "su": "submit-user", "res": "restriction",
                "restr": "restriction", "a": "asset", "rec": "record",
                "pv": "preview", "v": "validate", "s": "save", "reset": "clear",
            }
            classdraft_context, _ = resolve_unique_choice(head, classdraft_context_actions, classdraft_aliases)
            if classdraft_context:
                self.execute_classdraft_command([head] + tail)
                return

        user_heads = ["user", "users", "owner", "queue-user", "queueuser"]
        user_resolved, _ = resolve_unique_choice(head, user_heads)
        if user_resolved:
            if not tail:
                self.switch_view("users")
                return
            normal = _normalise_optional_user(" ".join(tail))
            self.queue_user = normal
            global PANEL_QUEUE_USER
            PANEL_QUEUE_USER = self.queue_user
            for v in self.views:
                v.refresh(self)
            self.status = f"Queue owner: {self.queue_user or '<current/default>'}"
            return

        task_heads = ["task", "taskcreator", "task-creator", "taskdraft", "newtask", "submitter", "tc"]
        task_resolved, _ = resolve_unique_choice(head, task_heads)
        if task_resolved:
            self.switch_view("task")
            self.execute_task_command(tail)
            return

        asset_heads = ["asset", "assets", "facility", "facilities"]
        asset_resolved, _ = resolve_unique_choice(head, asset_heads)
        if asset_resolved:
            self.execute_asset_command(tail)
            return

        policy_heads = ["policy", "policies", "pol", "site-policy", "shared-policy"]
        policy_resolved, _ = resolve_unique_choice(head, policy_heads)
        if policy_resolved:
            self.execute_policy_command(tail)
            return

        global_heads = ["global", "globals", "claim", "claims", "resource", "resources"]
        global_resolved, _ = resolve_unique_choice(head, global_heads)
        if global_resolved:
            self.execute_global_command(tail if global_resolved not in {"claim", "claims"} else [global_resolved, *tail])
            return

        module_heads = ["module", "modules", "mod", "mods", "plugin", "plugins", "cap", "caps"]
        module_resolved, _ = resolve_unique_choice(head, module_heads)
        if module_resolved:
            self.execute_module_command(tail if module_resolved not in {"cap", "caps"} else ["cap", *tail])
            return

        classcreator_heads = ["classcreator", "class-creator", "classdraft", "newclass", "cc", "restriction", "restrict"]
        classcreator_resolved, _ = resolve_unique_choice(head, classcreator_heads, {"res": "restriction", "restr": "restriction"})
        if classcreator_resolved:
            self.switch_view("classdraft")
            if classcreator_resolved in {"restriction", "restrict"}:
                self.execute_classdraft_command([classcreator_resolved] + tail)
            else:
                self.execute_classdraft_command(tail)
            return

        class_heads = ["class", "classes", "cls"]
        class_resolved, _ = resolve_unique_choice(head, class_heads)
        if class_resolved:
            self.execute_class_command(tail)
            return

        maint_heads = ["maintenance", "maint", "fixes", "fix", "tidy", "tidyup", "clean", "cleanup", "logs"]
        maint_resolved, _ = resolve_unique_choice(head, maint_heads)
        if maint_resolved:
            self.execute_maintenance_command(tail)
            return

        draft_heads = ["draft", "drafts", "dr"]
        draft_resolved, _ = resolve_unique_choice(head, draft_heads)
        if draft_resolved:
            self.execute_draft_command(tail)
            return

        job_heads = ["job", "jobs", "qid", "history", "hist", "show", "tail", "explain"]
        job_resolved, _ = resolve_unique_choice(head, job_heads, {"h": "history"})
        if job_resolved:
            if job_resolved in {"history", "hist", "show", "tail", "explain"}:
                self.execute_job_command([job_resolved] + tail)
            else:
                self.execute_job_command(tail)
            return

        if self.switch_view(raw):
            return
        if self.view.name == "taskdraft":
            self.execute_task_command(parts)
            return
        self.status = f"Unknown panel command: {raw}"

    def select_job_by_fragment(self, fragment: str) -> Optional[str]:
        self.switch_view("jobs")
        jobs_view = self.view
        if not jobs_view.items:
            jobs_view.refresh(self)
        if self.select_item_by_text(jobs_view, fragment):
            item = jobs_view.current()
            return item.key if item and item.key != "__error__" else None
        norm = normalize_panel_token(fragment)
        matches = [
            (idx, it) for idx, it in enumerate(jobs_view.items)
            if it.key != "__error__" and norm and (
                norm in normalize_panel_token(it.key)
                or norm in normalize_panel_token(it.label)
                or norm in normalize_panel_token(it.meta)
            )
        ]
        if len(matches) == 1:
            idx, it = matches[0]
            jobs_view.selected = idx
            jobs_view.detail_scroll = 0
            return it.key
        if not matches:
            self.status = f"No job matches: {fragment}"
        else:
            self.status = f"Ambiguous job fragment {fragment}: {len(matches)} matches"
        return None

    def current_job_fragment(self) -> str:
        item = self.view.current()
        if item and item.key != "__error__":
            return item.key
        return ""

    def execute_job_command(self, parts: Sequence[str]) -> None:
        self.switch_view("jobs")
        if not parts:
            self.status = "Jobs panel"
            return

        job_actions = [
            "select", "show", "tail", "history", "explain", "exception", "exceptions",
            "copy", "cancel", "kill", "delete", "undelete", "edit", "resubmit",
            "authorise", "authorize", "priority", "change-priority",
        ]
        action_aliases = {
            "sel": "select", "s": "show", "h": "history", "hist": "history",
            "x": "explain", "exc": "exception", "ex": "exception", "cp": "copy",
            "prio": "priority", "pri": "priority", "p": "priority",
            "changepriority": "change-priority", "chpri": "change-priority", "chp": "change-priority",
            "k": "kill", "del": "delete", "rm": "delete", "remove": "delete",
            "undel": "undelete", "restore": "undelete", "ed": "edit", "auth": "authorise", "authorise": "authorise", "authorize": "authorise",
        }

        def resolve_action_words(seq: Sequence[str]) -> tuple[str, int]:
            if not seq:
                return "", 0
            if len(seq) >= 2 and normalize_panel_token(seq[0]) in {"change", "chg", "set"}:
                second, _ = resolve_unique_choice(seq[1], ["priority"], action_aliases)
                if second == "priority":
                    return "priority", 2
            action, _ = resolve_unique_choice(seq[0], job_actions, action_aliases)
            if action == "change-priority":
                action = "priority"
            return action, 1 if action else 0

        action, consumed = resolve_action_words(parts)
        fragment = ""
        value = ""

        if action:
            rest = list(parts[consumed:])
            if action == "priority":
                if not rest:
                    fragment = self.current_job_fragment()
                    value = self.prompt("New priority")
                elif len(rest) == 1:
                    fragment = self.current_job_fragment()
                    value = rest[0]
                else:
                    fragment = rest[0]
                    value = rest[1]
            elif action in {"authorise", "authorize"}:
                if not rest:
                    fragment = self.current_job_fragment()
                    value = self.prompt("Authorisation reason")
                elif len(rest) == 1:
                    fragment = rest[0]
                    value = self.prompt("Authorisation reason")
                else:
                    fragment = rest[0]
                    value = " ".join(rest[1:])
            else:
                fragment = " ".join(rest) if rest else self.current_job_fragment()
        else:
            fragment = parts[0]
            if len(parts) >= 2:
                action, consumed2 = resolve_action_words(parts[1:])
                action = action or "select"
                if action == "priority":
                    value_index = 1 + consumed2
                    value = parts[value_index] if value_index < len(parts) else self.prompt("New priority")
                elif action in {"authorise", "authorize"}:
                    value_index = 1 + consumed2
                    value = " ".join(parts[value_index:]) if value_index < len(parts) else self.prompt("Authorisation reason")
            else:
                action = "select"

        if not fragment:
            self.status = f"No selected job for: {action or 'select'}"
            return

        qid = self.select_job_by_fragment(fragment)
        if not qid:
            return

        if action == "select":
            self.status = f"Selected job {qid}"
            return

        if action == "copy":
            self.copy_job_to_task_draft(qid)
            return

        if action == "edit":
            if not self.confirm(f"Cancel {qid} and create a new draft for editing?"):
                self.status = "Cancelled edit"
                return
            rc, out = qrun(["cancel", qid], dry_run=self.dry_run)
            if rc != 0:
                self.status = out.splitlines()[-1] if out else f"edit cancel rc={rc}"
                return
            self.copy_job_to_task_draft(qid)
            tail = out.splitlines()[-1] if out else "job cancelled"
            self.status = f"Edit draft created from {qid}; {tail}"
            self.refresh_current()
            return

        if action == "priority":
            if not value:
                value = self.prompt("New priority")
            if not value:
                self.status = "Priority unchanged"
                return
            rc, out = qrun(["priority", qid, value], dry_run=self.dry_run)
            self.status = out.splitlines()[-1] if out else f"priority rc={rc}"
            self.refresh_current()
            return

        if action in {"authorise", "authorize"}:
            if not value:
                value = self.prompt("Authorisation reason")
            args = ["authorise", qid]
            if value:
                args.extend(["--reason", value])
            rc, out = qrun(args, dry_run=self.dry_run)
            self.status = out.splitlines()[-1] if out else f"authorise rc={rc}"
            self.refresh_current()
            return

        if action in {"cancel", "kill", "delete", "undelete"}:
            if not self.confirm(f"{action} {qid}?"):
                self.status = "Cancelled action"
                return

        if action in {"history", "explain", "show", "tail", "exception", "exceptions"}:
            if action == "history":
                self.detail_tab_index = self.DETAIL_TABS.index("History")
            elif action == "explain":
                self.detail_tab_index = self.DETAIL_TABS.index("Explain")
            elif action in {"exception", "exceptions"}:
                self.detail_tab_index = self.DETAIL_TABS.index("Exceptions")
            elif action == "show":
                self.detail_tab_index = self.DETAIL_TABS.index("Log")
            elif action == "tail":
                self.detail_tab_index = self.DETAIL_TABS.index("Tail")
            self.view.detail_scroll = 0
            self.status = f"Selected job {qid}; right panel mode: {action}"
            return

        cmd = {"delete": "delete", "cancel": "cancel", "kill": "kill", "undelete": "undelete", "resubmit": "resubmit"}.get(action, action)
        rc, out = qrun([cmd, qid], dry_run=self.dry_run)
        self.status = out.splitlines()[-1] if out else f"{action} rc={rc}"
        self.refresh_current()

    def execute_task_command(self, parts: Sequence[str]) -> None:
        self.switch_view("task")
        if not parts:
            self.status = "Task Creator"
            return
        d = self.task_draft
        field_choices = ["name", "command", "class", "priority", "submit-user", "user", "directory", "cwd", "schedule", "not-before", "retries", "backoff", "runner", "sandbox", "security-reason", "reason", "authorisation", "authorization", "auth", "no-security-exemption", "no-exemption", "cpu", "memory", "mem", "log", "dependencies", "depends", "after", "inherit-env", "inherit", "on-success", "on-failure", "on-retry-failure", "hook-success", "hook-failure", "hook-retry", "preview", "dryrun", "save", "submit", "clear"]
        aliases = {"n":"name", "cmd":"command", "c":"class", "cls":"class", "p":"priority", "pri":"priority", "su":"submit-user", "submituser":"submit-user", "u":"user", "dir":"directory", "pwd":"cwd", "when":"schedule", "nb":"not-before", "r":"retries", "retry":"retries", "b":"backoff", "run":"runner", "sb":"sandbox", "sand":"sandbox", "sec":"security-reason", "why":"reason", "authcode":"authorisation", "noex":"no-security-exemption", "m":"memory", "maxlog":"log", "logcap":"log", "dep":"dependencies", "deps":"dependencies", "depends":"dependencies", "after":"dependencies", "after-success":"dependencies", "inherit":"inherit-env", "inheritenv":"inherit-env", "env":"inherit-env", "success":"on-success", "onsuccess":"on-success", "failure":"on-failure", "onfailure":"on-failure", "retryhook":"on-retry-failure", "onretry":"on-retry-failure", "attempt":"on-retry-failure", "pv":"preview", "dr":"dryrun", "s":"save", "go":"submit", "sub":"submit", "reset":"clear"}
        field, _ = resolve_unique_choice(parts[0], field_choices, aliases)
        if not field:
            classes = [it.key for it in load_classes(self) if it.key != "__error__"]
            choice, _ = resolve_unique_choice(parts[0], classes)
            if choice:
                d.job_class = choice
                self.status = f"Task Creator class set to {choice}"
                self.view.refresh(self)
                return
            self.status = f"Unknown Task Creator field/action: {parts[0]}"
            return
        value = " ".join(parts[1:])
        if field == "name": d.name = value or self.prompt("Task/job name", d.name)
        elif field == "command": d.command = value or self.prompt("Command", d.command)
        elif field == "class":
            if value:
                classes = [it.key for it in load_classes(self) if it.key != "__error__"]
                choice, _ = resolve_unique_choice(value, classes)
                d.job_class = choice or value.upper().replace("-", "_").replace(" ", "_")
                self.status = f"Task Creator class set to {d.job_class}"
            else:
                self.select_class_for_task()
        elif field == "priority": d.priority = value or self.prompt("Priority", d.priority or "10")
        elif field in {"submit-user", "user"}: d.submit_user = _normalise_optional_user(value or self.prompt("Submit as user", d.submit_user))
        elif field in {"directory", "cwd"}: d.execution_dir = value or self.prompt("Execution directory", d.execution_dir)
        elif field in {"schedule", "not-before"}: d.not_before = value or self.prompt("Schedule / not-before", d.not_before)
        elif field == "retries": d.retries = value or self.prompt("Retries", d.retries or "0")
        elif field == "backoff": d.retry_backoff = value or self.prompt("Retry backoff", d.retry_backoff)
        elif field == "runner": d.runner = value or self.prompt_choice("Runner override", ["auto", "direct", "systemd"], d.runner, allow_free=True)
        elif field == "sandbox": d.sandbox_level = value or self.prompt_choice("Sandbox override", self.sandbox_policy_choices(), d.sandbox_level, allow_free=True)
        elif field in {"security-reason", "reason"}:
            d.security_reason = value or self.prompt("Security exception reason (description-approved)", d.security_reason)
            if d.security_reason:
                d.authorisation_code = ""
                d.no_security_exemption_required = False
        elif field in {"authorisation", "authorization", "auth"}:
            d.authorisation_code = value or self.prompt("Authorisation code (blank means use any valid on-file code)", d.authorisation_code)
            if d.authorisation_code:
                d.security_reason = ""
                d.no_security_exemption_required = False
        elif field in {"no-security-exemption", "no-exemption"}:
            d.security_reason = ""
            d.authorisation_code = ""
            d.no_security_exemption_required = True
            self.status = "Task Creator: no security exemption requested; policy may still require one"
        elif field == "cpu": d.cpu_limit = value or self.prompt("CPU override, e.g. 50%", d.cpu_limit)
        elif field in {"memory", "mem"}: d.mem_limit = value or self.prompt("Memory override, e.g. 512M", d.mem_limit)
        elif field == "log": d.max_log_size = value or self.prompt("Max log size bytes", d.max_log_size)
        elif field in {"dependencies", "depends", "after"}: d.dependencies = self.edit_job_reference_field("After-success dependencies", d.dependencies, value)
        elif field in {"inherit-env", "inherit"}: d.inherit_env_from = self.edit_job_reference_field("Inherit env from", d.inherit_env_from, value)
        elif field in {"on-success", "hook-success"}: d.on_success = value or self.prompt("On-success hook command", d.on_success)
        elif field in {"on-failure", "hook-failure"}: d.on_failure = value or self.prompt("On-failure hook command", d.on_failure)
        elif field in {"on-retry-failure", "hook-retry"}: d.on_retry_failure = value or self.prompt("On-retry-failure hook command", d.on_retry_failure)
        elif field == "preview": self.popup("Task submit preview", d.render_command())
        elif field == "dryrun": self.popup("Task dry-run submit", "DRY-RUN: would run:\n\n" + d.render_command())
        elif field == "save": self.run_task_save_from_command()
        elif field == "submit": self.run_task_submit_from_command()
        elif field == "clear":
            if self.confirm("Clear task draft?"):
                self.task_draft = TaskDraft()
        self.view.refresh(self)

    def run_task_save_from_command(self) -> None:
        d = self.task_draft
        if not d.name or not d.command:
            self.status = "Task name and command are required before saving"
            return
        try:
            preview = d.render_draft_save_command(); args = d.draft_create_args()
        except ValueError as exc:
            self.status = f"Task command cannot be parsed: {exc}"
            return
        if not self.confirm("Save this task as a persistent draft?"):
            self.status = "Save draft cancelled"; return
        rc, out = qrun(args, dry_run=self.dry_run, timeout=30)
        self.popup("Task saved as draft", (out or f"draft save rc={rc}") + "\n\n" + preview)
        if rc == 0:
            self.status = "Task saved as persistent draft"
            for v in self.views:
                if v.name == "drafts": v.refresh(self)

    def run_task_submit_from_command(self) -> None:
        d = self.task_draft
        if not d.name or not d.command:
            self.status = "Task name and command are required"; return
        if not self.confirm("Submit this task?"):
            self.status = "Submit cancelled"; return
        rc, out = qrun(d.submit_args(), dry_run=self.dry_run, cwd=d.execution_dir, as_user=_normalise_optional_user(d.submit_user))
        self.popup("Task submit", out or f"submit rc={rc}")
        for v in self.views:
            if v.name == "jobs": v.refresh(self)
        if rc == 0 and not self.dry_run:
            self.task_draft = TaskDraft(); self.status = "Task submitted; Task Creator draft cleared"
        elif rc == 0:
            self.status = "Task submit dry-run complete; draft retained"

    def _class_assignment_value(self, line: str) -> str:
        """Parse the RHS from a simple CLASS_* assignment line."""
        _key, _sep, value = line.partition("=")
        value = value.strip()
        try:
            parts = shlex.split(value)
            if len(parts) == 1:
                return parts[0]
        except ValueError:
            pass
        return value.strip('"\'')

    def load_class_into_creator(self, class_name: str) -> None:
        """Load an existing class into the panel Class Creator draft.

        The panel must not call ``queue classes edit`` because that launches
        ``$EDITOR`` and blocks inside curses/qrun().  Edit in the panel means:
        read the class record, populate the Class Creator, then let the
        operator preview/validate/save through normal noninteractive paths.
        """
        rc, out = qrun(["classes", "show", class_name], timeout=8)
        if rc != 0:
            self.popup(f"Load class for edit: {class_name}", out or f"classes show rc={rc}")
            self.status = f"Could not load class {class_name}"
            return

        draft = ClassDraft(name=class_name)
        records: List[str] = []
        lines = out.splitlines()
        in_purpose = False
        purpose_lines: List[str] = []

        for raw in lines:
            line = raw.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("=== class:") or stripped.startswith("file:"):
                continue

            if stripped.startswith("# bashqueues class:"):
                maybe = stripped.split(":", 1)[1].strip()
                if maybe:
                    draft.name = maybe
                continue
            if stripped == "# Purpose:":
                in_purpose = True
                continue
            if in_purpose:
                if stripped.startswith("#   "):
                    purpose_lines.append(stripped[4:])
                    continue
                if stripped == "#":
                    in_purpose = False
                    continue
                in_purpose = False

            if stripped.startswith("CLASS_") and "=" in stripped:
                key = stripped.split("=", 1)[0]
                value = self._class_assignment_value(stripped)
                if key == "CLASS_ALLOW_PARALLEL":
                    draft.allow_parallel = value
                elif key == "CLASS_MAX_CONCURRENT":
                    draft.max_concurrent = value
                elif key == "CLASS_DEFAULT_RUNNER":
                    draft.default_runner = value
                elif key == "CLASS_DEFAULT_TIMEOUT":
                    draft.default_timeout = value
                elif key == "CLASS_DEFAULT_KILL_AFTER":
                    draft.default_kill_after = value
                elif key == "CLASS_DEFAULT_CPU_LIMIT":
                    draft.default_cpu_limit = value
                elif key == "CLASS_DEFAULT_MEM_LIMIT":
                    draft.default_mem_limit = value
                elif key == "CLASS_DEFAULT_MAX_LOG_SIZE_BYTES":
                    draft.default_log_cap = value
                elif key == "CLASS_DEFAULT_RUN_USER":
                    draft.default_run_user = value
                elif key == "CLASS_DEFAULT_SUBMIT_USER":
                    draft.default_submit_user = value
                elif key == "CLASS_DEFAULT_SANDBOX_LEVEL":
                    draft.default_sandbox_level = value
                elif key == "CLASS_DEFAULT_SECCOMP_PROFILE":
                    draft.default_seccomp_profile = value
                elif key == "CLASS_DEFAULT_SECCOMP_ALLOW":
                    draft.default_seccomp_allow = value
                else:
                    records.append(stripped)
                continue

            if stripped.startswith("#"):
                continue
            records.append(stripped)

        if purpose_lines:
            draft.purpose = "\n".join(purpose_lines)
        draft.records = records
        self.class_draft = draft
        self.switch_view("classdraft")
        self.view.refresh(self)
        self.status = f"Loaded class {class_name} into Class Creator; edit then save to apply changes"

    def perform_class_command_action(self, action: str, class_name: str) -> None:
        """Perform a class action selected from typed command entry.

        This keeps typed commands deterministic.  Prompt-driven class_action()
        remains available on F10/Enter, but commands like:
            class MYCLASS history
            cla mycl hist
        should jump directly to the selected class and requested output.
        """
        action_choices = ["explain", "show", "validate", "enable", "disable", "edit", "delete", "refresh", "rollback", "use", "history", "backups"]
        action, _ = resolve_unique_choice(action, action_choices, {"hist": "history", "h": "history", "cat": "show"})
        action = action or "select"
        if action == "select":
            self.status = f"Selected class {class_name}"
            return
        if action == "use":
            self.task_draft.job_class = class_name
            self.switch_view("task")
            self.status = f"Task Creator class set to {class_name}"
            self.view.refresh(self)
            return
        if action in {"explain", "show", "validate", "history", "backups"}:
            # History uses qrun(["classes", "backups", class_name]) through the right-pane detail renderer.
            self.class_detail_mode = "history" if action == "backups" else action
            self.view.detail_scroll = 0
            self.status = f"Selected class {class_name}; right panel mode: {self.class_detail_mode}"
            return
        if action == "enable":
            rc, out = qrun(["classes", "enable", class_name], dry_run=self.dry_run)
            self.status = out.splitlines()[-1] if out else f"class enable rc={rc}"
            self.refresh_current()
            return
        if action == "disable":
            if self.confirm(f"disable class {class_name}?"):
                rc, out = qrun(["classes", "disable", class_name], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"class disable rc={rc}"
                self.refresh_current()
            return
        if action == "edit":
            self.load_class_into_creator(class_name)
            return
        if action == "rollback":
            rc, out = qrun(["classes", "rollback", class_name], dry_run=self.dry_run)
            self.popup(f"Class rollback: {class_name}", out[:12000] if out else f"rollback rc={rc}")
            self.status = f"class {class_name} rollback rc={rc}"
            return
        if action == "delete":
            if self.confirm(f"archive class {class_name}?"):
                rc, out = qrun(["classes", "delete", class_name], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"class delete rc={rc}"
            return
        if action == "refresh":
            d = self.prompt_choice("Directory", ["classes"], "classes", allow_free=True)
            rc, out = qrun(["classes", "refresh", d], dry_run=self.dry_run)
            self.popup("Class refresh", out[:12000] if out else f"refresh rc={rc}")
            return
        self.status = f"Unknown class action: {action}"

    def execute_policy_command(self, parts: Sequence[str]) -> None:
        self.switch_view("policies")
        self.view.refresh(self)
        if not parts:
            self.status = "Policies panel"
            return
        actions = ["select", "show", "explain", "path", "edit", "create", "refresh"]
        action_aliases = {"x": "explain", "cat": "show", "e": "edit", "new": "create", "r": "refresh"}
        action, _ = resolve_unique_choice(parts[0], actions, action_aliases)
        rest = list(parts[1:]) if action else list(parts)
        if not action:
            action = "select"
        if action == "refresh":
            self.view.refresh(self); self.status = "Policies refreshed"; return
        kind = ""
        name = ""
        if len(rest) >= 2 and rest[0] in {"sandbox", "seccomp", "class-statement"}:
            kind, name = rest[0], rest[1]
        elif rest and ":" in rest[0]:
            kind, name = rest[0].split(":", 1)
        elif rest:
            name = rest[0]
            # Let queue infer the kind for show/explain; for edit/path try selected item.
            cur = self.view.current()
            if cur and cur.key != "__error__" and name in {cur.fields.get("name", ""), cur.key}:
                kind = cur.fields.get("kind", "")
        else:
            cur = self.view.current()
            if cur and cur.key != "__error__":
                kind = cur.fields.get("kind", "")
                name = cur.fields.get("name", "")
        if action == "select":
            if name and self.select_item_by_text(self.view, name):
                self.status = f"Selected policy {name}"
            else:
                self.status = "Usage: policy select KIND:NAME or NAME"
            return
        if action in {"show", "explain"}:
            args = ["policy", action]
            if kind and name:
                args += [kind, name]
            elif name:
                args += [name]
            rc, out = qrun(args, timeout=10)
            self.popup("Policy " + action, out[:12000] if out else f"policy {action} rc={rc}")
            return
        if action == "path":
            if not (kind and name):
                self.status = "Usage: policy path KIND NAME"; return
            rc, out = qrun(["policy", "path", kind, name], timeout=5)
            self.popup("Policy path", out or f"policy path rc={rc}")
            return
        if action == "edit":
            if not (kind and name):
                self.status = "Usage: policy edit KIND NAME"; return
            rc, out = qrun(["policy", "edit", kind, name], dry_run=self.dry_run, timeout=5)
            # In a curses panel, $EDITOR may not be usable; still provide the
            # command and any diagnostic so the operator knows the exact target.
            self.popup("Policy edit", out or f"policy edit rc={rc}")
            self.view.refresh(self)
            return
        if action == "create":
            if not (kind and name):
                self.status = "Usage: policy create KIND NAME"; return
            rc, out = qrun(["policy", "create", kind, name], dry_run=self.dry_run, timeout=10)
            self.popup("Policy create", out or f"policy create rc={rc}")
            self.view.refresh(self)
            return
        self.status = "Usage: policy show|explain|path|edit|create [KIND] NAME"

        self.switch_view("global")
        if not parts:
            self.view.refresh(self)
            self.status = "Global resources"
            return
        action = parts[0].lower()
        if action in {"claims", "list"}:
            self.view.refresh(self)
            self.status = "Global claims refreshed"
            return
        if action in {"claim", "explain", "show"}:
            if len(parts) < 2:
                self.status = "Usage: global claim CLAIM"
                return
            claim = " ".join(parts[1:])
            self.select_item_by_text(self.view, claim)
            self.status = f"Global claim: {claim}"
            return
        if action == "cleanup":
            args = ["global", "cleanup"] + list(parts[1:])
            rc, out = qrun(args, dry_run=self.dry_run)
            self.status = one_line(out) if rc == 0 else f"global cleanup failed: {one_line(out)}"
            self.view.refresh(self)
            return
        if action == "health":
            rc, out = qrun(["global", "health"], dry_run=self.dry_run)
            self.status = one_line(out) if rc == 0 else f"global health failed: {one_line(out)}"
            self.view.refresh(self)
            return
        self.status = "Usage: global claims|claim CLAIM|cleanup [--dryrun]|health"

    def execute_module_command(self, parts: Sequence[str]) -> None:
        self.switch_view("modules")
        self.view.refresh(self)
        if not parts:
            return
        actions = ["enable", "disable", "explain", "show", "refresh"]
        action_aliases = {"on": "enable", "off": "disable", "e": "enable", "d": "disable", "x": "explain"}
        # Forms:
        #   module asset net disable
        #   module disable asset net
        #   cap net_usage disable
        #   modules refresh caps caps.d
        first_action, _ = resolve_unique_choice(parts[0], actions, action_aliases)
        if first_action:
            action = first_action
            rest = list(parts[1:])
        else:
            action = ""
            rest = list(parts)
        if action == "refresh":
            kind = rest[0] if rest else ""
            directory = rest[1] if len(rest) > 1 else {"class": "classes", "classes": "classes", "asset": "assets.d", "assets": "assets.d", "cap": "caps.d", "caps": "caps.d"}.get(kind, "")
            if not kind or not directory:
                self.status = "Usage: module refresh class|asset|cap <directory>"; return
            rc, out = qrun(["modules", "refresh", kind, directory], dry_run=self.dry_run)
            self.popup("Module refresh", out[:12000] if out else f"refresh rc={rc}")
            self.refresh_current()
            return

        kind = ""
        target = ""
        if len(rest) >= 2 and rest[0].casefold() in {"class", "classes", "asset", "assets", "cap", "caps"}:
            kind = {"classes": "class", "assets": "asset", "caps": "cap"}.get(rest[0].casefold(), rest[0].casefold())
            target = rest[1]
            if not action and len(rest) >= 3:
                action, _ = resolve_unique_choice(rest[2], actions, action_aliases)
        elif rest and ":" in rest[0]:
            # Completion entries often expand to forms such as:
            #   class:CAPS_TEST explain
            #   cap:net_usage disable
            # Treat the first token as the module identity and the following
            # token as an optional action, instead of searching for the whole
            # string as one target.
            maybe_kind, maybe_target = rest[0].split(":", 1)
            if maybe_kind.casefold() in {"class", "asset", "cap"} and maybe_target:
                kind = maybe_kind.casefold()
                target = maybe_target
                if not action and len(rest) >= 2:
                    action, _ = resolve_unique_choice(rest[1], actions, action_aliases)
            else:
                target = " ".join(rest)
        else:
            target = " ".join(rest)
        if not action:
            action = "explain"
        search = f"{kind}:{target}" if kind and target else target
        if search and self.select_item_by_text(self.view, search):
            item = self.view.current()
            if not item: return
            kind = item.fields.get("kind", item.key.split(":", 1)[0])
            name = item.fields.get("name", item.key.split(":", 1)[1] if ":" in item.key else item.key)
            if action in {"explain", "show"}:
                self.status = f"Selected module {kind}:{name}"
                return
            if action == "enable":
                rc, out = qrun(["modules", "enable", kind, name], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"enable rc={rc}"
                self.refresh_current(); return
            if action == "disable":
                if self.confirm(f"disable {kind}:{name}?"):
                    rc, out = qrun(["modules", "disable", kind, name], dry_run=self.dry_run)
                    self.status = out.splitlines()[-1] if out else f"disable rc={rc}"
                    self.refresh_current()
                return
        self.status = f"Module not found uniquely: {' '.join(parts)}"

    def execute_class_command(self, parts: Sequence[str]) -> None:
        self.switch_view("classes")
        self.view.refresh(self)
        if not parts:
            return
        action_words = ["use", "select", "explain", "show", "validate", "enable", "disable", "edit", "delete", "refresh", "rollback", "history", "hist", "backups"]
        action_aliases = {"h": "history", "hist": "history", "cat": "show", "on": "enable", "off": "disable"}

        # Accept both forms:
        #   class explain MYCLASS
        #   class MYCLASS history
        first_action, _ = resolve_unique_choice(parts[0], action_words, action_aliases)
        if first_action and len(parts) >= 2:
            action = first_action
            target = " ".join(parts[1:])
        elif first_action and len(parts) == 1 and self.view.name == "classes":
            action = first_action
            cur = self.view.current()
            target = cur.key if cur and cur.key != "__error__" else ""
        else:
            target = parts[0]
            if len(parts) >= 2:
                action, _ = resolve_unique_choice(parts[1], action_words, action_aliases)
                action = action or "select"
            else:
                action = "select"

        if target and self.select_item_by_text(self.view, target):
            current = self.view.current()
            class_name = current.key if current else target
            self.perform_class_command_action(action, class_name)
        elif target:
            self.status = f"Class not found uniquely: {target}"

    def perform_asset_command_action(self, action: str, asset_key: str) -> None:
        """Perform an asset action selected from typed command entry.

        Asset actions are available from F2/typed commands just like class
        actions.  Non-mutating inspect actions update the right-hand pane where
        possible or show bounded output.  Mutating actions respect dry-run and
        confirmation semantics.
        """
        actions = ["select", "explain", "hint", "show", "validate", "enable", "disable", "delete", "refresh", "rollback"]
        action, _ = resolve_unique_choice(action or "select", actions, {"x": "explain", "h": "hint", "cat": "show", "on": "enable", "off": "disable"})
        action = action or "select"
        family = asset_key.split(":", 1)[0]
        if action == "select":
            self.status = f"Selected asset {asset_key}"
            return
        if action in {"explain", "show"}:
            _, out = qrun(["assets", "explain", asset_key])
            self.popup(f"Asset explain: {asset_key}", out[:12000])
            self.status = f"asset {asset_key} explain"
            return
        if action == "hint":
            _, out = qrun(["asset-hint", asset_key])
            self.popup(f"Asset hint: {asset_key}", out[:12000])
            self.status = f"asset {asset_key} hint"
            return
        if action == "validate":
            rc, out = qrun(["assets", "validate", family])
            self.popup(f"Asset validate: {family}", out[:12000] if out else f"validate rc={rc}")
            self.status = f"asset {family} validate rc={rc}"
            return
        if action == "enable":
            rc, out = qrun(["assets", "enable", family], dry_run=self.dry_run)
            self.status = out.splitlines()[-1] if out else f"asset enable rc={rc}"
            self.refresh_current()
            return
        if action == "disable":
            if self.confirm(f"disable asset plugin {family}?"):
                rc, out = qrun(["assets", "disable", family], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"asset disable rc={rc}"
                self.refresh_current()
            return
        if action == "delete":
            if self.confirm(f"archive asset plugin {family}?"):
                rc, out = qrun(["assets", "delete", family], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"asset delete rc={rc}"
                self.refresh_current()
            return
        if action == "refresh":
            d = self.prompt_choice("Directory", ["assets.d"], "assets.d", allow_free=True)
            rc, out = qrun(["assets", "refresh", d], dry_run=self.dry_run)
            self.popup("Asset refresh", out[:12000] if out else f"refresh rc={rc}")
            self.refresh_current()
            return
        if action == "rollback":
            rc, out = qrun(["assets", "rollback", family], dry_run=self.dry_run)
            self.popup(f"Asset rollback: {family}", out[:12000] if out else f"rollback rc={rc}")
            self.status = f"asset {family} rollback rc={rc}"
            return
        self.status = f"Unknown asset action: {action}"

    def execute_asset_command(self, parts: Sequence[str]) -> None:
        self.switch_view("assets")
        self.view.refresh(self)
        if not parts:
            return
        action_words = ["select", "explain", "hint", "show", "validate", "enable", "disable", "delete", "refresh", "rollback"]
        action_aliases = {"x": "explain", "h": "hint", "cat": "show", "on": "enable", "off": "disable"}

        # Accept both forms:
        #   asset explain net:allowance
        #   asset net:allowance disable
        #   on Assets panel: disable
        first_action, _ = resolve_unique_choice(parts[0], action_words, action_aliases)
        if first_action and len(parts) >= 2:
            action = first_action
            target = " ".join(parts[1:])
        elif first_action and len(parts) == 1 and self.view.name == "assets":
            action = first_action
            cur = self.view.current()
            target = cur.key if cur and cur.key != "__error__" else ""
        else:
            target = parts[0]
            if len(parts) >= 2:
                action, _ = resolve_unique_choice(parts[1], action_words, action_aliases)
                action = action or "select"
            else:
                action = "select"

        if target and self.select_item_by_text(self.view, target):
            current = self.view.current()
            asset_key = current.key if current else target
            self.perform_asset_command_action(action, asset_key)
        elif target:
            self.status = f"Asset not found uniquely: {target}"
        else:
            self.status = "No asset selected"

    def execute_maintenance_command(self, parts: Sequence[str]) -> None:
        self.switch_view("maintenance")
        self.view.refresh(self)
        if not parts:
            return
        actions = ["queue", "direct", "preview", "schedule", "priority", "command", "reset"]
        action = ""; recipe_text = ""
        if len(parts) >= 2:
            maybe_action, _ = resolve_unique_choice(parts[-1], actions)
            if maybe_action:
                action = maybe_action; recipe_text = " ".join(parts[:-1])
        if not recipe_text: recipe_text = " ".join(parts)
        if recipe_text and not self.select_item_by_text(self.view, recipe_text):
            self.status = f"Maintenance recipe not found uniquely: {recipe_text}"; return
        if action == "preview":
            recipe = maintenance_recipe_by_key(self.view.current().key) if self.view.current() else None
            if recipe:
                args = self.maintenance_command_overrides.get(recipe.key, list(recipe.queue_args))
                submit_preview = "queue " + " ".join(shlex.quote(a) for a in self.maintenance_submit_args(recipe, args))
                direct_preview = "queue " + " ".join(shlex.quote(a) for a in args)
                self.popup("Maintenance preview", "Queued job:\n  " + submit_preview + "\n\nDirect now:\n  " + direct_preview)
                return
        self.status = f"Selected maintenance recipe {self.view.current().key if self.view.current() else ''}; press F10/Enter for action"

    def execute_draft_command(self, parts: Sequence[str]) -> None:
        self.switch_view("drafts")
        self.view.refresh(self)
        if not parts: return
        action_words = ["show", "load", "submit", "ready", "abandon"]
        action, _ = resolve_unique_choice(parts[0], action_words)
        target = " ".join(parts[1:] if action and len(parts) > 1 else parts)
        if target and self.select_item_by_text(self.view, target):
            if action: self.draft_action()
            else: self.status = f"Selected draft {self.view.current().key}"
        elif target:
            self.status = f"Draft not found uniquely: {target}"

    def confirm(self, prompt: str) -> bool:
        return self.prompt_choice(prompt + " y/N", ["yes", "no"], "no", aliases={"y": "yes", "n": "no"}) == "yes"

    def popup(self, title: str, body: str) -> None:
        """Scrollable modal panel.

        The old popup drew a border over existing content but did not clear the
        whole rectangle, which left stale text behind short outputs.  This modal
        blanks the rectangle first and supports scrolling so explain/history/log
        output is usable rather than disappearing on the first key.
        """
        h, w = self.stdscr.getmaxyx()
        raw_lines = body.splitlines() or [""]
        natural_width = max((len(x) for x in raw_lines), default=40)

        ph = min(h - 4, max(10, min(h - 4, len(raw_lines) + 5)))
        pw = min(w - 4, max(60, min(w - 4, natural_width + 4)))
        y, x = max(1, (h - ph) // 2), max(1, (w - pw) // 2)

        content_h = max(1, ph - 4)
        content_w = max(20, pw - 4)

        wrapped: List[str] = []
        for line in raw_lines:
            if len(line) <= content_w:
                wrapped.append(line)
            else:
                wrapped.extend(textwrap.wrap(line, width=content_w, replace_whitespace=False) or [""])

        scroll = 0
        while True:
            # Clear the entire modal rectangle, not just the text we overwrite.
            for yy in range(y, min(y + ph, h)):
                self.safe_addstr(yy, x, " " * max(0, min(pw, w - x - 1)))

            self.draw_box(y, x, ph, pw, title)

            max_scroll = max(0, len(wrapped) - content_h)
            scroll = max(0, min(scroll, max_scroll))

            for i in range(content_h):
                idx = scroll + i
                if idx >= len(wrapped):
                    break
                self.safe_addstr(y + 1 + i, x + 2, wrapped[idx][:content_w])

            footer = "↑/↓ PgUp/PgDn/Home/End scroll   q/Esc/Enter close"
            if max_scroll:
                footer += f"   {scroll + 1}-{min(scroll + content_h, len(wrapped))}/{len(wrapped)}"
            self.safe_addstr(y + ph - 2, x + 2, footer[: pw - 4], curses.A_REVERSE)

            self.stdscr.refresh()
            k = self.stdscr.getch()

            if k in (ord("q"), ord("Q"), 27, 10, 13):
                break
            if k == curses.KEY_DOWN:
                scroll += 1
            elif k == curses.KEY_UP:
                scroll -= 1
            elif k == curses.KEY_NPAGE:
                scroll += content_h
            elif k == curses.KEY_PPAGE:
                scroll -= content_h
            elif k == curses.KEY_HOME:
                scroll = 0
            elif k == curses.KEY_END:
                scroll = max_scroll

        # Force a full redraw behind the modal on return.
        self.draw()

    def refresh_current(self) -> None:
        self.view.refresh(self)
        self.status = f"Refreshed {self.view.title}"

    def set_filter(self) -> None:
        if self.view.name == "jobs":
            state = self.prompt_choice("State filter", ["all", "pending", "running", "done", "failed", "cancelled", "deleted", "interrupted"], self.job_state_filter)
            self.job_state_filter = state or "all"
            self.job_text_filter = self.prompt("Job text filter", self.job_text_filter)
        elif self.view.name == "classes":
            self.class_filter = self.prompt("Class filter", self.class_filter)
        elif self.view.name == "assets":
            self.asset_filter = self.prompt("Asset/facility filter", self.asset_filter)
        elif self.view.name == "modules":
            self.module_filter = self.prompt("Module filter", self.module_filter)
        self.view.refresh(self)

    def maintenance_submit_args(self, recipe: MaintenanceRecipe, args: Sequence[str]) -> List[str]:
        scheduled = self.maintenance_schedule_overrides.get(recipe.key, recipe.default_not_before)
        pri = self.maintenance_priority_overrides.get(recipe.key, recipe.default_priority)
        payload = queue_payload_command(args)
        submit: List[str] = [
            "submit", recipe.job_name(),
            "--priority", pri,
            "--class", recipe.default_class,
            "--runner", recipe.default_runner,
            "--max-log-size", recipe.default_max_log_size,
        ]
        if scheduled:
            submit.extend(["--not-before", scheduled])
        submit.extend(["--", "bash", "-lc", payload])
        return submit

    def maintenance_action(self) -> None:
        item = self.view.current()
        if not item:
            return
        recipe = maintenance_recipe_by_key(item.key)
        if recipe is None:
            self.status = "Unknown maintenance recipe"
            return
        actions = ["queue", "direct", "preview", "schedule", "priority", "command", "reset"]
        action = self.prompt_choice("Maintenance action", actions, "queue")
        args = self.maintenance_command_overrides.get(recipe.key, list(recipe.queue_args))

        if action == "preview":
            submit_preview = "queue " + " ".join(shlex.quote(a) for a in self.maintenance_submit_args(recipe, args))
            direct_preview = "queue " + " ".join(shlex.quote(a) for a in args)
            self.popup("Maintenance preview", "Queued job:\n  " + submit_preview + "\n\nDirect now:\n  " + direct_preview)
            return

        if action == "schedule":
            cur = self.maintenance_schedule_overrides.get(recipe.key, recipe.default_not_before)
            self.maintenance_schedule_overrides[recipe.key] = self.prompt("Not-before / schedule", cur)
            self.refresh_current()
            return

        if action == "priority":
            cur = self.maintenance_priority_overrides.get(recipe.key, recipe.default_priority)
            self.maintenance_priority_overrides[recipe.key] = self.prompt("Priority", cur or "5")
            self.refresh_current()
            return

        if action == "command":
            cur = " ".join(shlex.quote(a) for a in args)
            raw = self.prompt("Queue command args", cur)
            try:
                parsed = shlex.split(raw)
            except ValueError as exc:
                self.status = f"Invalid command args: {exc}"
                return
            if parsed:
                self.maintenance_command_overrides[recipe.key] = parsed
                self.status = f"Maintenance command updated for {recipe.key}"
            self.refresh_current()
            return

        if action == "reset":
            self.maintenance_schedule_overrides.pop(recipe.key, None)
            self.maintenance_priority_overrides.pop(recipe.key, None)
            self.maintenance_command_overrides.pop(recipe.key, None)
            self.status = f"Reset maintenance recipe {recipe.key}"
            self.refresh_current()
            return

        if action == "direct":
            if not self.confirm(f"Run {recipe.label} directly now? Queue job is safer."):
                self.status = "Direct maintenance cancelled"
                return
            rc, out = qrun(args, dry_run=False, timeout=120)
            self.popup("Maintenance direct run", out or f"direct rc={rc}")
            self.refresh_current()
            return

        if action == "queue":
            if not self.confirm(f"Submit queued maintenance job {recipe.job_name()}?"):
                self.status = "Queued maintenance cancelled"
                return
            rc, out = qrun(self.maintenance_submit_args(recipe, args), dry_run=self.dry_run, timeout=30)
            self.popup("Maintenance queued job", out or f"submit rc={rc}")
            for v in self.views:
                if v.name == "jobs":
                    v.refresh(self)
            self.refresh_current()
            return

        self.status = "Unknown maintenance action"

    def queue_user_action(self) -> None:
        item = self.view.current()
        if not item:
            return
        self.queue_user = item.key
        global PANEL_QUEUE_USER
        PANEL_QUEUE_USER = self.queue_user
        if self.queue_user:
            self.status = f"Queue owner set to {self.queue_user}"
        else:
            self.status = "Queue owner selection cleared; using current/default queue"
        for v in self.views:
            v.refresh(self)

    def selected_qid(self) -> Optional[str]:
        it = self.view.current()
        if not it or it.key == "__error__":
            return None
        return it.key

    def add_exception(self) -> None:
        qid = self.selected_qid()
        if not qid:
            return
        current_class = job_class(qid)
        if current_class:
            _, class_detail = qrun(["classes", "explain", current_class])
            self.popup("Class policy before exception", class_detail[:5000])
        facilities = [it.key for it in load_assets(self) if it.key != "__error__"]
        asset = self.prompt_choice("Asset/facility to ignore, e.g. time:window", facilities, allow_free=True)
        if not asset:
            return
        reason = self.prompt("Reason")
        if not reason:
            self.status = "Exception not added: reason is required"
            return
        rc, out = qrun(["exception", "add", qid, asset, "--reason", reason], dry_run=self.dry_run)
        self.status = out.splitlines()[-1] if out else f"exception add rc={rc}"
        self.refresh_current()

    def clear_exception(self) -> None:
        qid = self.selected_qid()
        if not qid:
            return
        facilities = [it.key for it in load_assets(self) if it.key != "__error__"]
        asset = self.prompt_choice("Asset/facility to clear", facilities, allow_free=True)
        if not asset:
            return
        rc, out = qrun(["exception", "clear", qid, asset], dry_run=self.dry_run)
        self.status = out.splitlines()[-1] if out else f"exception clear rc={rc}"
        self.refresh_current()

    def copy_job_to_task_draft(self, qid: str = "") -> None:
        if not qid:
            qid = self.selected_qid() or ""
        if not qid:
            return

        text = queue_job_file_text(qid)
        env = parse_job_env_from_text(text)
        explain = parse_job_explain_fields(qid)

        d = self.task_draft

        old_name = env.get("JOB_NAME") or explain.get("name") or "copied_job"
        d.name = self.prompt("New task name", f"{old_name}_copy")
        d.command = parse_job_command_from_text(text) or explain.get("command", "")
        d.job_class = env.get("JOB_CLASS") or explain.get("class", "")
        if d.job_class in {"none", "-", "DEFAULT"}:
            d.job_class = "" if d.job_class in {"none", "-"} else d.job_class

        d.priority = env.get("PRIORITY") or explain.get("priority") or "10"
        d.execution_dir = env.get("PWD_AT_SUBMIT") or explain.get("submit_directory", "")
        d.retries = env.get("RETRIES_MAX") or "0"
        d.retry_backoff = env.get("RETRY_BACKOFF") or ""
        d.runner = env.get("RUNNER") or ""
        d.cpu_limit = env.get("CPU_LIMIT") or ""
        d.mem_limit = env.get("MEM_LIMIT") or ""
        d.max_log_size = env.get("MAX_LOG_SIZE_BYTES") or ""

        not_before = env.get("NOT_BEFORE_EPOCH") or ""
        if not_before and not_before != "0":
            d.not_before = f"@{not_before}"
        else:
            d.not_before = ""

        # Preserve submit user only if it was explicitly recorded and not just current.
        submit_user = env.get("SUBMIT_USER", "")
        if submit_user and submit_user not in {"current", "-"}:
            d.submit_user = submit_user

        rc, out = qrun(["draft", "create-from-job", qid], dry_run=self.dry_run)
        if rc == 0 and out:
            self.status = out.splitlines()[0]
        else:
            self.status = f"Copied job {qid} into Task Creator draft"
        for v in self.views:
            if v.name == "drafts":
                v.refresh(self)
        for i, v in enumerate(self.views):
            if v.name == "taskdraft":
                self.active = i
                v.refresh(self)
                break

    def job_action(self) -> None:
        qid = self.selected_qid()
        if not qid:
            return
        job_actions = ["authorise", "change priority", "kill", "delete", "undelete", "edit", "cancel", "resubmit", "copy", "show", "tail", "history", "explain"]
        action = self.prompt_choice("Job action", job_actions)
        if not action:
            return
        if action == "change priority":
            new_priority = self.prompt("New priority")
            if not new_priority:
                self.status = "Priority unchanged"
                return
            self.execute_job_command(["priority", qid, new_priority])
            return
        self.execute_job_command([action, qid])

    def queue_clear_action(self) -> None:
        target = self.prompt_choice("Clear queue", ["done", "failed", "cancelled", "deleted", "interrupted"])
        mapping = {
            "done": "clear-done",
            "failed": "clear-failed",
            "cancelled": "clear-cancelled",
            "deleted": "clear-deleted",
            "interrupted": "clear-interrupted",
        }
        cmd = mapping.get(target)
        if not cmd:
            self.status = "Unknown clear target"
            return
        if not self.confirm(f"{cmd}?"):
            return
        rc, out = qrun([cmd], dry_run=self.dry_run)
        self.status = out.splitlines()[-1] if out else f"{cmd} rc={rc}"
        self.refresh_current()

    def class_action(self) -> None:
        it = self.view.current()
        if not it or it.key == "__error__":
            return
        action = self.prompt_choice("Class action", ["explain", "edit", "validate", "enable", "disable", "delete", "refresh", "rollback", "use-for-task"])
        if action == "explain":
            _, out = qrun(["classes", "explain", it.key])
            self.popup("Class explain", out[:8000])
        elif action == "edit":
            self.load_class_into_creator(it.key)
        elif action == "validate":
            rc, out = qrun(["classes", "validate", it.key])
            self.popup("Class validate", out[:8000])
        elif action == "enable":
            rc, out = qrun(["classes", "enable", it.key], dry_run=self.dry_run)
            self.status = out.splitlines()[-1] if out else f"enable rc={rc}"
        elif action == "disable":
            if self.confirm(f"disable class {it.key}?"):
                rc, out = qrun(["classes", "disable", it.key], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"disable rc={rc}"
        elif action == "delete":
            if self.confirm(f"archive class {it.key}?"):
                rc, out = qrun(["classes", "delete", it.key], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"delete rc={rc}"
        elif action == "refresh":
            d = self.prompt_choice("Directory", ["classes"], "classes", allow_free=True)
            rc, out = qrun(["classes", "refresh", d], dry_run=self.dry_run)
            self.popup("Class refresh", out[:8000])
        elif action == "rollback":
            rc, out = qrun(["classes", "rollback", it.key], dry_run=self.dry_run)
            self.popup("Class rollback", out[:8000])
        elif action == "use-for-task":
            self.task_draft.job_class = it.key
            self.status = f"Task Creator class set to {it.key}"
            for i, v in enumerate(self.views):
                if v.name == "taskdraft":
                    self.active = i
                    v.refresh(self)
                    break
        self.refresh_current()

    def module_action(self) -> None:
        it = self.view.current()
        if not it or it.key == "__error__":
            return
        kind = it.fields.get("kind", it.key.split(":", 1)[0])
        name = it.fields.get("name", it.key.split(":", 1)[1] if ":" in it.key else it.key)
        status = it.fields.get("status", "")
        choices = ["explain", "enable", "disable", "refresh"]
        action = self.prompt_choice("Module action", choices)
        if action == "explain":
            _, out = qrun(["modules", "explain", f"{kind}:{name}"])
            self.popup("Module explain", out[:12000])
        elif action == "enable":
            rc, out = qrun(["modules", "enable", kind, name], dry_run=self.dry_run)
            self.status = out.splitlines()[-1] if out else f"enable rc={rc}"
            self.refresh_current()
        elif action == "disable":
            if self.confirm(f"disable {kind}:{name}?"):
                rc, out = qrun(["modules", "disable", kind, name], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"disable rc={rc}"
                self.refresh_current()
        elif action == "refresh":
            default_dir = {"class": "classes", "asset": "assets.d", "cap": "caps.d"}.get(kind, ".")
            d = self.prompt_choice("Refresh from directory", [default_dir], default_dir, allow_free=True)
            rc, out = qrun(["modules", "refresh", kind, d], dry_run=self.dry_run)
            self.popup("Module refresh", out[:12000] if out else f"refresh rc={rc}")
            self.refresh_current()

    def global_action(self) -> None:
        it = self.view.current()
        choices = ["claims", "explain", "cleanup-dryrun", "cleanup", "release"]
        action = self.prompt_choice("Global resource action", choices, "explain" if it else "claims")
        if action == "claims":
            self.view.refresh(self); self.status = "Global claims refreshed"; return
        if action == "explain":
            if not it or it.key == "__error__":
                self.status = "No global claim selected"; return
            _, out = qrun(["global", "claim", it.key])
            self.popup("Global claim", out[:12000])
            return
        if action == "cleanup-dryrun":
            rc, out = qrun(["global", "cleanup", "--dryrun"], dry_run=self.dry_run)
            self.popup("Global cleanup dry-run", out[:12000] if out else f"cleanup rc={rc}")
            self.view.refresh(self); return
        if action == "cleanup":
            if not self.confirm("Run global cleanup now?"):
                return
            rc, out = qrun(["global", "cleanup"], dry_run=self.dry_run)
            self.popup("Global cleanup", out[:12000] if out else f"cleanup rc={rc}")
            self.view.refresh(self); return
        if action == "release":
            claim = it.key if it and it.key != "__error__" else self.prompt("Claim")
            qid = self.prompt("QID holder to release")
            if not claim or not qid:
                self.status = "release needs claim and QID"; return
            if not self.confirm(f"Force release {claim} holder {qid}?"):
                return
            rc, out = qrun(["global", "release", claim, qid, "--force"], dry_run=self.dry_run)
            self.popup("Global release", out[:12000] if out else f"release rc={rc}")
            self.view.refresh(self)

    def policy_action(self) -> None:
        it = self.view.current()
        if not it or it.key == "__error__":
            return
        kind = it.fields.get("kind", it.key.split(":", 1)[0])
        name = it.fields.get("name", it.key.split(":", 1)[1] if ":" in it.key else it.key)
        action = self.prompt_choice("Policy action", ["show", "explain", "path", "edit", "create-copy", "refresh"], "show")
        if action in {"show", "explain"}:
            _, out = qrun(["policy", action, kind, name], timeout=10)
            self.popup("Policy " + action, out[:12000])
        elif action == "path":
            _, out = qrun(["policy", "path", kind, name], timeout=5)
            self.popup("Policy path", out)
        elif action == "edit":
            rc, out = qrun(["policy", "edit", kind, name], dry_run=self.dry_run, timeout=5)
            self.popup("Policy edit", out or f"policy edit rc={rc}")
            self.view.refresh(self)
        elif action == "create-copy":
            new_name = self.prompt("New policy name", name + "-copy")
            if new_name:
                rc, out = qrun(["policy", "create", kind, new_name, "--from", name], dry_run=self.dry_run, timeout=10)
                self.popup("Policy create", out or f"policy create rc={rc}")
                self.view.refresh(self)
        elif action == "refresh":
            self.view.refresh(self); self.status = "Policies refreshed"

    def asset_action(self) -> None:
        it = self.view.current()
        if not it or it.key == "__error__":
            return
        family = it.key.split(":", 1)[0]
        action = self.prompt_choice("Asset action", ["explain", "hint", "validate", "enable", "disable", "delete", "refresh", "rollback"])
        if action == "explain":
            _, out = qrun(["assets", "explain", it.key])
            self.popup("Asset explain", out[:8000])
        elif action == "hint":
            _, out = qrun(["asset-hint", it.key])
            self.popup("Asset hint", out[:8000])
        elif action == "validate":
            _, out = qrun(["assets", "validate", family])
            self.popup("Asset validate", out[:8000])
        elif action == "enable":
            rc, out = qrun(["assets", "enable", family], dry_run=self.dry_run)
            self.status = out.splitlines()[-1] if out else f"enable rc={rc}"
        elif action == "disable":
            if self.confirm(f"disable asset plugin {family}?"):
                rc, out = qrun(["assets", "disable", family], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"disable rc={rc}"
        elif action == "delete":
            if self.confirm(f"archive asset plugin {family}?"):
                rc, out = qrun(["assets", "delete", family], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"delete rc={rc}"
        elif action == "refresh":
            d = self.prompt_choice("Directory", ["assets.d"], "assets.d", allow_free=True)
            rc, out = qrun(["assets", "refresh", d], dry_run=self.dry_run)
            self.popup("Asset refresh", out[:8000])
        elif action == "rollback":
            rc, out = qrun(["assets", "rollback", family], dry_run=self.dry_run)
            self.popup("Asset rollback", out[:8000])
        self.refresh_current()

    def select_class_for_task(self) -> None:
        classes = [it.key for it in load_classes(self) if it.key != "__error__"]
        choice = self.prompt_choice(
            "Class for task",
            classes,
            self.task_draft.job_class,
            allow_free=True,
        )
        if not choice:
            return
        if choice in classes:
            self.task_draft.job_class = choice
            self.status = f"Task Creator class set to {choice}"
            return
        self.task_draft.job_class = choice.upper().replace("-", "_").replace(" ", "_")
        self.status = f"Task Creator class set to {self.task_draft.job_class}"

    def task_creator_action(self) -> None:
        item = self.view.current()
        if not item:
            return
        d = self.task_draft
        key = item.key
        if key == "name":
            d.name = self.prompt("Task/job name", d.name)
        elif key == "command":
            d.command = self.prompt("Command", d.command)
        elif key == "job_class":
            self.select_class_for_task()
        elif key == "priority":
            d.priority = self.prompt("Priority", d.priority or "10")
        elif key == "submit_user":
            users = [it.key for it in load_queue_users(self) if it.key != "__error__"]
            d.submit_user = _normalise_optional_user(self.prompt_choice("Submit as user", users, d.submit_user, allow_free=True))
        elif key == "execution_dir":
            d.execution_dir = self.prompt("Execution directory", d.execution_dir)
        elif key == "not_before":
            d.not_before = self.prompt("Schedule / not-before", d.not_before)
        elif key == "retries":
            d.retries = self.prompt("Retries", d.retries or "0")
        elif key == "retry_backoff":
            d.retry_backoff = self.prompt("Retry backoff", d.retry_backoff)
        elif key == "runner":
            d.runner = self.prompt_choice("Runner override", ["auto", "direct", "systemd"], d.runner, allow_free=True)
        elif key == "sandbox_level":
            d.sandbox_level = self.prompt_choice("Sandbox override", self.sandbox_policy_choices(), d.sandbox_level, allow_free=True)
        elif key == "security_reason":
            d.security_reason = self.prompt("Security exception reason (description-approved)", d.security_reason)
            if d.security_reason:
                d.authorisation_code = ""
                d.no_security_exemption_required = False
        elif key == "authorisation":
            d.authorisation_code = self.prompt("Authorisation code (blank means use any valid on-file code)", d.authorisation_code)
            if d.authorisation_code:
                d.security_reason = ""
                d.no_security_exemption_required = False
        elif key == "no_security_exemption":
            d.security_reason = ""
            d.authorisation_code = ""
            d.no_security_exemption_required = True
            self.status = "Task Creator: no security exemption requested; policy may still require one"
        elif key == "cpu_limit":
            d.cpu_limit = self.prompt("CPU override, e.g. 50%", d.cpu_limit)
        elif key == "mem_limit":
            d.mem_limit = self.prompt("Memory override, e.g. 512M", d.mem_limit)
        elif key == "max_log_size":
            d.max_log_size = self.prompt("Max log size bytes", d.max_log_size)
        elif key == "dependencies":
            d.dependencies = self.edit_job_reference_field("After-success dependencies", d.dependencies)
        elif key == "inherit_env_from":
            d.inherit_env_from = self.edit_job_reference_field("Inherit env from", d.inherit_env_from)
        elif key == "on_success":
            d.on_success = self.prompt("On-success hook command", d.on_success)
        elif key == "on_failure":
            d.on_failure = self.prompt("On-failure hook command", d.on_failure)
        elif key == "on_retry_failure":
            d.on_retry_failure = self.prompt("On-retry-failure hook command", d.on_retry_failure)
        elif key == "preview":
            self.popup("Task submit preview", d.render_command())
        elif key == "dryrun":
            self.popup("Task dry-run submit", "DRY-RUN: would run:\n\n" + d.render_command())
        elif key == "save":
            if not d.name or not d.command:
                self.status = "Task name and command are required before saving"
                return
            try:
                preview = d.render_draft_save_command()
                args = d.draft_create_args()
            except ValueError as exc:
                self.status = f"Task command cannot be parsed: {exc}"
                return
            if not self.confirm("Save this task as a persistent draft?"):
                self.status = "Save draft cancelled"
                return
            rc, out = qrun(args, dry_run=self.dry_run, timeout=30)
            self.popup("Task saved as draft", (out or f"draft save rc={rc}") + "\n\n" + preview)
            if rc == 0:
                self.status = "Task saved as persistent draft"
                for v in self.views:
                    if v.name == "drafts":
                        v.refresh(self)
        elif key == "submit":
            if not d.name or not d.command:
                self.status = "Task name and command are required"
                return
            if not self.confirm("Submit this task?"):
                self.status = "Submit cancelled"
                return
            rc, out = qrun(d.submit_args(), dry_run=self.dry_run, cwd=d.execution_dir, as_user=_normalise_optional_user(d.submit_user))
            self.popup("Task submit", out or f"submit rc={rc}")
            for v in self.views:
                if v.name == "jobs":
                    v.refresh(self)
            if rc == 0 and not self.dry_run:
                self.task_draft = TaskDraft()
                self.status = "Task submitted; Task Creator draft cleared"
            elif rc == 0:
                self.status = "Task submit dry-run complete; draft retained"
        elif key == "clear":
            if self.confirm("Clear task draft?"):
                self.task_draft = TaskDraft()
        self.refresh_current()

    def class_restriction_variable_choices(self) -> List[str]:
        """Common variables used when building class restrictions.

        These are deliberately offered through the same '*' chooser as other
        fields so operators can build safe class records without remembering
        every variable name.
        """
        return [
            "${QUEUEBASH_COMMAND_0}",
            "${QUEUEBASH_COMMAND_ARG_1}",
            "${QUEUEBASH_COMMAND_ARG_1_ABSPATH}",
            "${QUEUEBASH_COMMAND_ARG_2}",
            "${QUEUEBASH_JOB_WORKDIR}",
            "${PWD_AT_SUBMIT}",
            "${JOB_NAME}",
            "${JOB_ID}",
            "${QUEUEBASH_ROOT}",
            "*",
        ]

    def class_restriction_facility_choices(self) -> List[str]:
        """Return selectable asset/cap facilities for class restriction records."""
        choices: List[str] = []
        for it in load_assets(self):
            if it.key and it.key != "__error__":
                choices.append(it.key)
        # caps.d modules can be class-relevant even when they are not normal
        # asset facilities.  Include them as cap:<family> so the operator can
        # discover billing/net_usage from the same chooser.
        for it in load_modules(self):
            if it.key.startswith("cap:") and it.key not in choices:
                choices.append(it.key)
        return choices

    def class_restriction_hint(self, facility: str) -> str:
        """Return best-effort hint text for a selected class facility."""
        if facility.startswith("cap:"):
            _, out = qrun(["modules", "explain", facility])
            return out or f"No cap hint available for {facility}"
        _, hint = qrun(["asset-hint", facility])
        if not hint:
            _, hint = qrun(["assets", "explain", facility])
        return hint or f"No asset hint available for {facility}"

    def parse_class_restriction_hint(self, facility: str, hint: str) -> dict[str, str]:
        """Extract target/params/example/notes from asset/cap hint text.

        Asset plugins publish hints as tab-delimited records such as::

            time:window target=policy name params=weekdays=mon-fri ...

        The CLI may also render those records as a human-readable block with
        ``Target:``, ``Params:``, ``Example:``, and ``Notes:`` lines.  The panel
        needs the structured fields so Class Creator can ask useful questions
        instead of dumping a single free-text params prompt.
        """
        meta: dict[str, str] = {"facility": facility, "target": "", "params": "", "example": "", "notes": ""}
        lines = hint.splitlines()

        # Raw queue_asset_hints line.
        for line in lines:
            if not line.strip():
                continue
            if not line.startswith(facility):
                continue
            for part in line.split("\t")[1:]:
                if "=" in part:
                    k, v = part.split("=", 1)
                    meta[k.strip().casefold()] = v.strip()
            break

        # Pretty CLI block.
        current = ""
        for raw in lines:
            line = raw.strip()
            low = line.casefold()
            if low.startswith("target:"):
                current = "target"
                meta[current] = line.split(":", 1)[1].strip()
            elif low.startswith("params:"):
                current = "params"
                meta[current] = line.split(":", 1)[1].strip()
            elif low.startswith("example:"):
                current = "example"
                meta[current] = line.split(":", 1)[1].strip()
            elif low.startswith("notes:"):
                current = "notes"
                meta[current] = line.split(":", 1)[1].strip()
            elif current in {"example", "notes"} and line:
                meta[current] = (meta[current] + "\n" + line).strip()

        return meta

    def class_restriction_target_choices(self, facility: str, target_hint: str) -> List[str]:
        """Contextual target choices for the Class Creator restriction wizard."""
        low = target_hint.casefold()
        choices: List[str] = []
        if "policy" in low:
            choices.extend(["overnight", "business-hours", "weekend", "weekday", "always", "maintenance-window"])
        if "interface" in low:
            choices.extend(["eth0", "wlan0", "wwan0", "tun0", "ppp0"])
        if "url" in low:
            choices.extend(["https://github.com", "https://example.com", "${QUEUEBASH_COMMAND_ARG_1}"])
        if "host:port" in low:
            choices.extend(["localhost:5432", "localhost:3306", "localhost:6379", "db.internal:5432"])
        if "path" in low or "directory" in low or "file" in low or "repository" in low:
            choices.extend(["${QUEUEBASH_COMMAND_ARG_1_ABSPATH}", "${QUEUEBASH_JOB_WORKDIR}", "${PWD_AT_SUBMIT}", "/home/hc3/bashqueues", "/tmp"])
        if "system" in low:
            choices.append("system")
        if "command" in low or "interpreter" in low:
            choices.extend(["bash", "python3", "rexx", "git", "curl"])
        choices.extend(self.class_restriction_variable_choices())
        seen: set[str] = set()
        out: List[str] = []
        for c in choices:
            if c and c not in seen:
                seen.add(c)
                out.append(c)
        return out

    def class_restriction_param_is_internal(self, key: str, default: str, facility: str) -> bool:
        """Return True for hint parameters that are test/internal controls.

        These may legitimately exist in asset methods for unit tests or forced
        replay, but the Class Creator must not offer them in the normal
        operator wizard.  A real class should not accidentally contain values
        like ``now_epoch=TEST`` simply because the hint advertised a test hook.
        """
        k = key.casefold().replace("-", "_")
        d = default.casefold()
        return k in {"now_epoch", "counter_file", "test_epoch", "mock", "debug"} or d in {"test", "__test__"}

    def class_restriction_param_label(self, key: str, default: str, facility: str, target: str = "") -> str:
        """Human prompt for a generated restriction parameter."""
        k = key.casefold().replace("-", "_")
        if k == "weekdays":
            return "Weekday set"
        if k == "weekday_windows":
            return "Weekday allowed time window(s)"
        if k == "weekends":
            return "Weekend day set"
        if k == "weekend_windows":
            return "Weekend allowed time window(s)"
        if k == "writable":
            return "Must be writable? 1=yes 0=no"
        if k == "executable":
            return "Must be executable/traversable? 1=yes 0=no"
        if k == "readable":
            return "Must be readable? 1=yes 0=no"
        if k == "allowance_bytes":
            return "Network allowance bytes"
        if k == "direction":
            return "Network direction"
        if k == "require_executable":
            return "Script must be executable? 1=yes 0=no"
        if k == "validate_syntax":
            return "Validate syntax before dispatch? 1=yes 0=no"
        if k == "nonempty":
            return "Environment variable must be non-empty? 1=yes 0=no"
        if k == "min_version":
            return "Minimum version"
        if k == "modules":
            return "Required module/import list"
        return key

    def class_restriction_param_default(self, key: str, default: str, facility: str, target: str = "") -> str:
        """Safe default for a generated restriction parameter."""
        k = key.casefold().replace("-", "_")
        if self.class_restriction_param_is_internal(key, default, facility):
            return ""
        # Directories need the execute/search bit to be traversable.  For /tmp
        # the normal safe gate is writable=1 executable=1, not executable=0.
        if facility == "runnable:filesystem" and k == "executable" and target:
            if target.endswith("/") or target in {"/tmp", "${QUEUEBASH_JOB_WORKDIR}", "${PWD_AT_SUBMIT}"} or "directory" in target.casefold():
                return "1"
        return "" if default.casefold() in {"none", "optional", "<omit>"} else default

    def class_restriction_param_choices(self, key: str, default: str, facility: str, target: str = "") -> List[str]:
        """Contextual values for an individual key=value restriction parameter."""
        k = key.casefold().replace("-", "_")
        choices: List[str] = []
        safe_default = self.class_restriction_param_default(key, default, facility, target)
        if safe_default:
            choices.append(safe_default)
        if k in {"writable", "executable", "readable", "require_executable", "validate_syntax", "nonempty", "allow_relative", "require_shebang"}:
            choices.extend(["1", "0"])
        elif k in {"weekdays", "days"}:
            choices.extend(["mon-fri", "mon-thu", "mon,tue,wed,thu,fri", "fri", "none"])
        elif k in {"weekends"}:
            choices.extend(["sat-sun", "sat", "sun", "none"])
        elif "window" in k or k in {"hours"}:
            choices.extend(["09:00-17:00", "05:00-18:00", "18:00-05:00", "00:00-06:00", "always", "never"])
        elif k in {"direction"}:
            choices.extend(["rx_tx", "rx", "tx"])
        elif k in {"allowance_bytes", "limit", "max_bytes"}:
            choices.extend(["1G", "5G", "10G", "25G", "100G"])
        elif "timeout" in k:
            choices.extend(["3", "5", "10", "30", "60"])
        elif "status" in k:
            choices.extend(["200,201,204,301,302,304,307,308", "200,301,302", "200,403"])
        elif k.startswith("min_") or k.startswith("max_"):
            choices.extend(["1", "5", "10", "50", "80", "100"])
        elif k in {"state"}:
            choices.extend(["UP", "DOWN"])
        elif k in {"mode"}:
            choices.extend(["read", "write", "execute"])
        elif k in {"query"}:
            choices.extend(["SELECT_1", "SELECT 1"])
        elif k in {"user"}:
            choices.extend(["postgres", "root", "${USER}"])
        elif k in {"require_cwd"}:
            choices.extend(["${QUEUEBASH_JOB_WORKDIR}", "${PWD_AT_SUBMIT}", "/home/hc3/bashqueues"])
        choices.append("<omit>")
        seen: set[str] = set()
        out: List[str] = []
        for c in choices:
            if c and c not in seen:
                seen.add(c)
                out.append(c)
        return out

    def class_restriction_param_specs(self, params_hint: str) -> List[tuple[str, str]]:
        """Return ``[(param_name, default_value), ...]`` from hint params text."""
        specs: List[tuple[str, str]] = []
        text = (params_hint or "").strip()
        if not text or text.casefold() in {"none", "n/a", "-"}:
            return specs
        try:
            tokens = shlex.split(text)
        except ValueError:
            tokens = text.split()
        for token in tokens:
            if "=" not in token:
                continue
            key, value = token.split("=", 1)
            key = key.strip()
            if key:
                specs.append((key, value.strip()))
        return specs

    def prompt_class_restriction_params(self, facility: str, params_hint: str, target: str = "") -> str:
        """Ask one useful prompt per advertised hint parameter.

        ``*`` on every generated parameter prompt opens a relevant chooser.
        Blank/clear/omit skips optional parameters.  Test/internal controls
        such as ``now_epoch=TEST`` are deliberately hidden from the normal
        wizard so production class records do not inherit test hooks.
        """
        specs = self.class_restriction_param_specs(params_hint)
        if not specs:
            return ""
        rendered: List[str] = []
        skipped: List[str] = []
        for key, default in specs:
            if self.class_restriction_param_is_internal(key, default, facility):
                skipped.append(key)
                continue
            prompt_default = self.class_restriction_param_default(key, default, facility, target)
            choices = self.class_restriction_param_choices(key, default, facility, target)
            prompt_label = self.class_restriction_param_label(key, default, facility, target)
            value = self.prompt_choice(f"{prompt_label} [{key}=] (* choices; blank omit)", choices, prompt_default, allow_free=True)
            if value.strip().casefold() in {"", "<omit>", "omit", "none", "clear", "-"}:
                continue
            rendered.append(f"{key}={shlex.quote(value)}")
        if skipped:
            self.status = "Skipped test/internal restriction params: " + ", ".join(skipped)
        return " ".join(rendered)

    def build_class_restriction_record(self, supplied_facility: str = "") -> str:
        """Hint-driven class restriction builder.

        Class Creator uses the asset/cap hint contract to generate the wizard:
        facility -> target prompt -> parameter prompts.  This means a
        ``time:window`` restriction automatically asks for a policy name,
        weekdays, weekday windows, weekends, and weekend windows, while
        ``net:allowance`` asks for interface/direction/allowance-style fields.
        Every generated field still supports ``*`` selection, unique prefixes,
        and unique substrings.
        """
        facilities = self.class_restriction_facility_choices()
        if not facilities:
            self.status = "No asset/cap facilities are available"
            return ""

        if supplied_facility:
            resolved, diagnostic = resolve_unique_choice(supplied_facility, facilities)
            if not resolved:
                self.status = diagnostic or f"Facility not found uniquely: {supplied_facility}"
                return ""
            facility = resolved
        else:
            facility = self.prompt_choice("Facility/restriction (* list)", facilities, "", allow_free=False)
            if not facility:
                self.status = "No facility selected"
                return ""

        hint = self.class_restriction_hint(facility)
        hint_meta = self.parse_class_restriction_hint(facility, hint)
        self.popup(f"Hint for {facility}", hint[:12000])

        if facility.startswith("cap:"):
            cap = facility.split(":", 1)[1]
            mode = self.prompt_choice("Cap record type", ["require", "note"], "require")
            if mode == "note":
                return f"# cap:{cap} available; add the relevant cap configuration for this class"
            return f"queue_class_requires_cap {shlex.quote(cap)}"

        family, _, check = facility.partition(":")
        mode = self.prompt_choice("Restriction type", ["shared", "exclusive", "claim"], "shared", aliases={"s":"shared", "x":"exclusive", "e":"exclusive", "c":"claim"})
        if mode == "claim":
            claim = self.prompt_choice("Exclusive claim token (* variables)", self.class_restriction_variable_choices(), "", allow_free=True)
            if not claim:
                self.status = "Claim token required"
                return ""
            return f"queue_class_exclusive_claim {shlex.quote(claim)}"

        target_hint = hint_meta.get("target", "") or "target"
        target_choices = self.class_restriction_target_choices(facility, target_hint)
        target = self.prompt_choice(f"Target: {target_hint}", target_choices, "", allow_free=True)
        if not target:
            self.status = "Restriction target required"
            return ""

        params = self.prompt_class_restriction_params(facility, hint_meta.get("params", ""), target)
        if not params:
            examples = [
                hint_meta.get("params", ""),
                "allowance_bytes=10G direction=rx_tx",
                "path=${QUEUEBASH_COMMAND_ARG_1_ABSPATH}",
                "",
            ]
            params = self.prompt_choice("Additional params key=value... (* examples; blank none)", examples, "", allow_free=True)
            if params.strip().casefold() in {"*", "<omit>", "omit", "none"}:
                params = ""

        func = "queue_class_exclusive_asset" if mode == "exclusive" else "queue_class_shared_asset"
        record = f"{func} {shlex.quote(family)} {shlex.quote(check)} {shlex.quote(target)}"
        if params:
            record += " " + params
        return record

    def add_class_restriction_from_hints(self, supplied_facility: str = "") -> None:
        record = self.build_class_restriction_record(supplied_facility)
        if not record:
            return
        if self.confirm("Add generated restriction to this class draft?"):
            self.class_draft.records.append(record)
            self.status = "Added restriction to Class Creator draft"
            self.refresh_current()
        else:
            self.popup("Generated class restriction", record)

    def execute_classdraft_command(self, parts: Sequence[str]) -> None:
        """Typed command support for Class Creator.

        Examples:
          classcreator restriction net:allowance
          restriction net allowance
          record add
          save
        """
        self.switch_view("classdraft")
        if not parts:
            return
        head = parts[0]
        tail = list(parts[1:])
        actions = [
            "name", "purpose", "allow-parallel", "parallel", "max-concurrent",
            "runner", "timeout", "kill-after", "cpu", "memory", "log",
            "run-user", "submit-user", "sandbox", "seccomp", "seccomp-allow",
            "restriction", "restrict", "asset",
            "record", "records", "preview", "validate", "save", "clear",
        ]
        aliases = {
            "n": "name", "p": "purpose", "ap": "allow-parallel", "mc": "max-concurrent",
            "r": "runner", "t": "timeout", "ka": "kill-after", "mem": "memory",
            "maxlog": "log", "ru": "run-user", "su": "submit-user", "sb": "sandbox",
            "sc": "seccomp", "sec": "seccomp", "sa": "seccomp-allow",
            "res": "restriction", "restr": "restriction", "a": "asset", "rec": "record",
            "pv": "preview", "v": "validate", "s": "save", "reset": "clear",
        }
        action, _ = resolve_unique_choice(head, actions, aliases)
        action = action or head
        d = self.class_draft
        value = " ".join(tail).strip()
        if action == "name":
            d.name = (value or self.prompt("Class name", d.name)).upper().replace("-", "_").replace(" ", "_")
        elif action == "purpose":
            d.purpose = value or self.prompt("Purpose", d.purpose)
        elif action in {"allow-parallel", "parallel"}:
            d.allow_parallel = value or self.prompt_choice("Allow parallel", ["0", "1", "yes", "no"], d.allow_parallel or "1")
            if d.allow_parallel == "yes": d.allow_parallel = "1"
            if d.allow_parallel == "no": d.allow_parallel = "0"
        elif action == "max-concurrent":
            d.max_concurrent = value or self.prompt("Max concurrent 0=unlimited", d.max_concurrent or "0")
        elif action == "runner":
            d.default_runner = value or self.prompt_choice("Default runner", ["auto", "direct", "systemd"], d.default_runner or "auto")
        elif action == "timeout":
            d.default_timeout = value or self.prompt("Default timeout, e.g. 30s", d.default_timeout)
        elif action == "kill-after":
            d.default_kill_after = value or self.prompt("Kill after, e.g. 5s", d.default_kill_after)
        elif action == "cpu":
            d.default_cpu_limit = value or self.prompt("CPU limit, e.g. 50%", d.default_cpu_limit)
        elif action == "memory":
            d.default_mem_limit = value or self.prompt("Memory limit, e.g. 512M", d.default_mem_limit)
        elif action == "log":
            d.default_log_cap = value or self.prompt("Max log size bytes", d.default_log_cap)
        elif action == "run-user":
            users = [it.key for it in load_queue_users(self) if it.key != "__error__"]
            d.default_run_user = _normalise_optional_user(value or self.prompt_choice("Default payload/run user", users, d.default_run_user, allow_free=True))
        elif action == "submit-user":
            users = [it.key for it in load_queue_users(self) if it.key != "__error__"]
            d.default_submit_user = _normalise_optional_user(value or self.prompt_choice("Default queue submit/owner user", users, d.default_submit_user, allow_free=True))
        elif action == "sandbox":
            d.default_sandbox_level = value or self.prompt_choice("Default sandbox", self.sandbox_policy_choices(), d.default_sandbox_level, allow_free=True)
            if d.default_sandbox_level in {"<current/default>", "current", "default", "none", "-"}:
                d.default_sandbox_level = ""
        elif action == "seccomp":
            d.default_seccomp_profile = value or self.prompt_choice("Default seccomp", self.seccomp_policy_choices(), d.default_seccomp_profile, allow_free=True)
            if d.default_seccomp_profile in {"<current/default>", "current", "default", "none", "-"}:
                d.default_seccomp_profile = ""
        elif action == "seccomp-allow":
            d.default_seccomp_allow = value or self.prompt("Seccomp allow groups, e.g. @debug", d.default_seccomp_allow)
        elif action in {"restriction", "restrict", "asset"}:
            self.add_class_restriction_from_hints(value)
            return
        elif action in {"record", "records"}:
            if value:
                d.records.append(value)
                self.status = "Added raw class record"
            else:
                self.edit_class_draft_records()
                return
        elif action == "preview":
            self.popup("Class draft preview", d.render())
        elif action == "validate":
            self.validate_class_draft()
        elif action == "save":
            self.save_class_draft()
        elif action == "clear":
            if self.confirm("Clear class draft?"):
                self.class_draft = ClassDraft()
        else:
            self.status = f"Unknown Class Creator command: {' '.join(parts)}"
        self.refresh_current()

    def class_creator_action(self) -> None:
        item = self.view.current()
        if not item:
            return

        d = self.class_draft
        key = item.key

        if key == "name":
            d.name = self.prompt("Class name", d.name).upper().replace("-", "_").replace(" ", "_")
        elif key == "purpose":
            d.purpose = self.prompt("Purpose", d.purpose)
        elif key == "allow_parallel":
            d.allow_parallel = self.prompt_choice("Allow parallel", ["0", "1", "yes", "no"], d.allow_parallel or "1")
            if d.allow_parallel == "yes":
                d.allow_parallel = "1"
            elif d.allow_parallel == "no":
                d.allow_parallel = "0"
        elif key == "max_concurrent":
            d.max_concurrent = self.prompt("Max concurrent 0=unlimited", d.max_concurrent or "0")
        elif key == "default_runner":
            d.default_runner = self.prompt_choice("Default runner", ["auto", "direct", "systemd"], d.default_runner or "auto")
        elif key == "default_timeout":
            d.default_timeout = self.prompt("Default timeout, e.g. 30s", d.default_timeout)
        elif key == "default_kill_after":
            d.default_kill_after = self.prompt("Kill after, e.g. 5s", d.default_kill_after)
        elif key == "default_cpu_limit":
            d.default_cpu_limit = self.prompt("CPU limit, e.g. 50%", d.default_cpu_limit)
        elif key == "default_mem_limit":
            d.default_mem_limit = self.prompt("Memory limit, e.g. 512M", d.default_mem_limit)
        elif key == "default_log_cap":
            d.default_log_cap = self.prompt("Max log size bytes", d.default_log_cap)
        elif key == "default_run_user":
            users = [it.key for it in load_queue_users(self) if it.key != "__error__"]
            d.default_run_user = _normalise_optional_user(self.prompt_choice("Default payload/run user", users, d.default_run_user, allow_free=True))
        elif key == "default_submit_user":
            users = [it.key for it in load_queue_users(self) if it.key != "__error__"]
            d.default_submit_user = _normalise_optional_user(self.prompt_choice("Default queue submit/owner user", users, d.default_submit_user, allow_free=True))
        elif key == "default_sandbox_level":
            d.default_sandbox_level = self.prompt_choice("Default sandbox", self.sandbox_policy_choices(), d.default_sandbox_level, allow_free=True)
            if d.default_sandbox_level in {"<current/default>", "current", "default", "none", "-"}:
                d.default_sandbox_level = ""
        elif key == "default_seccomp_profile":
            d.default_seccomp_profile = self.prompt_choice("Default seccomp", self.seccomp_policy_choices(), d.default_seccomp_profile, allow_free=True)
            if d.default_seccomp_profile in {"<current/default>", "current", "default", "none", "-"}:
                d.default_seccomp_profile = ""
        elif key == "default_seccomp_allow":
            d.default_seccomp_allow = self.prompt("Seccomp allow groups, e.g. @debug", d.default_seccomp_allow)
        elif key == "add_restriction":
            self.add_class_restriction_from_hints()
            return
        elif key == "records":
            self.edit_class_draft_records()
        elif key == "preview":
            self.popup("Class draft preview", d.render())
        elif key == "validate":
            self.validate_class_draft()
        elif key == "save":
            self.save_class_draft()
        elif key == "clear":
            if self.confirm("Clear class draft?"):
                self.class_draft = ClassDraft()

        self.refresh_current()

    def edit_class_draft_records(self) -> None:
        d = self.class_draft
        action = self.prompt_choice("Records action", ["add", "edit", "delete", "clear", "list"], "add")
        if action == "add":
            rec = self.prompt("Record line")
            if rec:
                d.records.append(rec)
        elif action == "edit":
            idx_s = self.prompt("Record number 1..N")
            try:
                idx = int(idx_s) - 1
                if 0 <= idx < len(d.records):
                    d.records[idx] = self.prompt("Record line", d.records[idx])
            except ValueError:
                self.status = "Invalid record number"
        elif action == "delete":
            idx_s = self.prompt("Record number 1..N")
            try:
                idx = int(idx_s) - 1
                if 0 <= idx < len(d.records):
                    del d.records[idx]
            except ValueError:
                self.status = "Invalid record number"
        elif action == "clear":
            if self.confirm("Clear all records?"):
                d.records.clear()
        elif action == "list":
            numbered = "\n".join(f"{i+1}: {r}" for i, r in enumerate(d.records)) or "No records."
            self.popup("Class draft records", numbered)

    def class_draft_path(self) -> Path:
        return Path(QUEUE_ROOT) / "classes" / f"{self.class_draft.class_name()}.env"

    def validate_class_draft(self) -> None:
        d = self.class_draft
        if not d.name:
            self.status = "Class name is required"
            return
        tmpdir = Path(QUEUE_ROOT) / ".panel_tmp"
        tmpdir.mkdir(parents=True, exist_ok=True)
        tmp = tmpdir / f"{d.class_name()}.env"
        tmp.write_text(d.render())
        # Use a temporary refresh into the live class root only when saving; for
        # validation, use bash syntax plus queue class parser when available.
        rc, out = qrun(["classes", "validate-file", str(tmp)], dry_run=False)
        if rc != 0 and "Usage:" in out:
            rc, out = qrun(["classes", "validate", d.class_name()], dry_run=False)
            out = "Draft syntax checked locally. Full queue validation is available after save.\n\n" + out
        # Always at least bash-parse the file.
        bash_rc = subprocess.run(["bash", "-n", str(tmp)], text=True, capture_output=True).returncode
        if bash_rc == 0:
            out = (out + "\n\nbash -n: OK").strip()
        else:
            out = (out + "\n\nbash -n: FAILED").strip()
        self.popup("Validate class draft", out or f"validate rc={rc}")

    def save_class_draft(self) -> None:
        d = self.class_draft
        if not d.name:
            self.status = "Class name is required"
            return
        path = self.class_draft_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists() and not self.confirm(f"Overwrite {path.name}?"):
            self.status = "Save cancelled"
            return
        if self.dry_run:
            self.popup("Dry-run save class", f"Would write:\n{path}\n\n{d.render()}")
            return
        path.write_text(d.render())
        self.status = f"Saved class: {path}"
        # Refresh the Classes panel data next time.
        for v in self.views:
            if v.name == "classes":
                v.refresh(self)

    def builder_action(self) -> None:
        it = self.view.current()
        if not it or it.key == "__error__":
            return
        family, _, check = it.key.partition(":")
        mode = self.prompt_choice("Record type", ["shared", "exclusive", "claim"], "shared")
        if mode == "claim":
            claim = self.prompt("Exclusive claim token")
            if not claim:
                return
            record = f"queue_class_exclusive_claim {shlex.quote(claim)}"
        else:
            target = self.prompt(f"Target for {it.key}")
            if not target:
                return
            params = self.prompt("Params key=value ...")
            func = "queue_class_exclusive_asset" if mode.startswith("ex") else "queue_class_shared_asset"
            record = f"{func} {shlex.quote(family)} {shlex.quote(check)} {shlex.quote(target)}"
            if params:
                record += " " + params

        if self.confirm("Add this record to Class Creator draft?"):
            self.class_draft.records.append(record)
            self.status = "Added restriction to class draft"
        else:
            self.popup("Generated restriction record", record)

    def draft_action(self) -> None:
        item = self.view.current()
        if not item or item.key == "__error__":
            return
        action = self.prompt_choice("Draft action", ["show", "load", "submit", "ready", "abandon"])
        if action == "show":
            _, out = qrun(["draft", "show", item.key])
            self.popup("Draft", out[:12000])
        elif action == "load":
            _, out = qrun(["draft", "show", item.key])
            env = parse_job_env_from_text(out)
            d = self.task_draft
            d.name = env.get("JOB_NAME", "")
            d.command = parse_job_command_from_text(out)
            d.job_class = env.get("JOB_CLASS", "")
            d.priority = env.get("PRIORITY", "10")
            d.execution_dir = env.get("PWD_AT_SUBMIT", "")
            d.submit_user = env.get("SUBMIT_USER", "")
            d.runner = env.get("RUNNER", "")
            d.sandbox_level = env.get("SANDBOX_LEVEL", "")
            d.cpu_limit = env.get("CPU_LIMIT", "")
            d.mem_limit = env.get("MEM_LIMIT", "")
            d.max_log_size = env.get("MAX_LOG_SIZE_BYTES", "")
            d.retries = env.get("RETRIES_MAX", "0")
            d.retry_backoff = env.get("RETRY_BACKOFF", "")
            self.status = f"Loaded draft {item.key} into Task Creator"
            for i, v in enumerate(self.views):
                if v.name == "taskdraft":
                    self.active = i
                    v.refresh(self)
                    break
        elif action in {"submit", "ready", "abandon"}:
            if action == "submit" and not self.confirm(f"Submit draft {item.key}?"):
                return
            rc, out = qrun(["draft", action, item.key], dry_run=self.dry_run)
            self.popup(f"Draft {action}", out or f"rc={rc}")
            self.refresh_current()
        else:
            self.status = "Unknown draft action"


    def clear_current_editor_field(self) -> None:
        """Clear the selected inactive editor field without opening a prompt.

        This is intentionally bound to the terminal Delete key rather than
        Backspace.  Operators often need to remove an optional value from the
        Task Creator or Class Creator after selecting it from a chooser; opening
        a prompt just to type "clear" is clumsy.  Delete should not perform
        destructive object actions here: it only clears the currently selected
        editor field.
        """
        if self.view.name == "taskdraft":
            self.clear_current_task_field()
            return
        if self.view.name == "classdraft":
            self.clear_current_class_field()
            return
        self.status = "Delete clears the selected field in Task Creator or Class Creator"

    def clear_current_task_field(self) -> None:
        item = self.view.current()
        if not item:
            return
        d = self.task_draft
        key = item.key
        clearable = {
            "name": "name",
            "command": "command",
            "job_class": "job_class",
            "submit_user": "submit_user",
            "execution_dir": "execution_dir",
            "not_before": "not_before",
            "retry_backoff": "retry_backoff",
            "runner": "runner",
            "sandbox_level": "sandbox_level",
            "security_reason": "security_reason",
            "authorisation": "authorisation_code",
            "cpu_limit": "cpu_limit",
            "mem_limit": "mem_limit",
            "max_log_size": "max_log_size",
            "dependencies": "dependencies",
            "inherit_env_from": "inherit_env_from",
            "on_success": "on_success",
            "on_failure": "on_failure",
            "on_retry_failure": "on_retry_failure",
        }
        if key == "priority":
            d.priority = "10"
            self.status = "Task Creator priority reset to 10"
        elif key == "retries":
            d.retries = "0"
            self.status = "Task Creator retries reset to 0"
        elif key == "no_security_exemption":
            d.no_security_exemption_required = False
            self.status = "Task Creator security exemption mode reset to auto/required by policy"
        elif key in clearable:
            setattr(d, clearable[key], "")
            if key in {"security_reason", "authorisation"}:
                d.no_security_exemption_required = False
            self.status = f"Task Creator field cleared: {key}"
        else:
            self.status = f"Task Creator field is not clearable with Delete: {key}"
        self.refresh_current()

    def clear_current_class_field(self) -> None:
        item = self.view.current()
        if not item:
            return
        d = self.class_draft
        key = item.key
        clearable = {
            "name": "name",
            "purpose": "purpose",
            "default_timeout": "default_timeout",
            "default_kill_after": "default_kill_after",
            "default_cpu_limit": "default_cpu_limit",
            "default_mem_limit": "default_mem_limit",
            "default_log_cap": "default_log_cap",
            "default_run_user": "default_run_user",
            "default_submit_user": "default_submit_user",
            "default_sandbox_level": "default_sandbox_level",
            "default_seccomp_profile": "default_seccomp_profile",
            "default_seccomp_allow": "default_seccomp_allow",
        }
        if key == "allow_parallel":
            d.allow_parallel = "1"
            self.status = "Class Creator allow_parallel reset to 1"
        elif key == "max_concurrent":
            d.max_concurrent = "0"
            self.status = "Class Creator max_concurrent reset to 0"
        elif key == "default_runner":
            d.default_runner = "auto"
            self.status = "Class Creator default runner reset to auto"
        elif key == "records":
            if self.confirm("Clear all class draft records?"):
                d.records.clear()
                self.status = "Class Creator records cleared"
            else:
                self.status = "Class Creator records unchanged"
        elif key in clearable:
            setattr(d, clearable[key], "")
            self.status = f"Class Creator field cleared: {key}"
        else:
            self.status = f"Class Creator field is not clearable with Delete: {key}"
        self.refresh_current()

    def action(self) -> None:
        if self.view.name == "queueusers":
            self.queue_user_action()
        elif self.view.name == "jobs":
            self.job_action()
        elif self.view.name == "drafts":
            self.draft_action()
        elif self.view.name == "classes":
            self.class_action()
        elif self.view.name == "assets":
            self.asset_action()
        elif self.view.name == "modules":
            self.module_action()
        elif self.view.name == "policies":
            self.policy_action()
        elif self.view.name == "global":
            self.global_action()
        elif self.view.name == "maintenance":
            self.maintenance_action()
        elif self.view.name == "classdraft":
            self.class_creator_action()
        elif self.view.name == "taskdraft":
            self.task_creator_action()
        elif self.view.name == "exceptions":
            self.clear_exception()

    def help(self) -> None:
        self.popup("Help", "\n".join([
            "Full-screen panel QueueManager",
            "",
            "Navigation:",
            "  Queue Users panel selects which user queue root the UI manages",
            "  Tab             switch panel forward",
            "  Shift-Tab       switch panel backward",
            "  Up/Down         move list",
            "  PgUp/PgDn       scroll list",
            "  Left/Right      scroll detail",
            "  [ and ]         switch right-hand job detail tab",
            "",
            "Command entry:",
            "  Type a command anywhere; the first key opens the command line",
            "  Commands accept first unique letters or unique substrings",
            "  Examples: jo, tas, task class GITHUB, task name publish_git",
            "  Examples: task dependencies setup_job, task on-success bash -c 'echo ok'",
            "  Examples: job 1798231 history, job change priority 5, job kill, job edit",
            "  Examples: job 1798231 authorise Approved maintenance exception",
            "  Examples: user hc3, user clear",
            "  Examples: cla MYCLASS hist, class MYCLASS use, maint health queue",
            "  Examples: module asset net disable, cap billing enable",
            "  Policy: policy show class-statement default, policy edit class-statement default",
            "  Global: global claims, global claim github:publish, global cleanup --dryrun",
            "  Examples: classcreator restriction net:allowance, restriction billing",
            "  Type * in the command line for contextual completions",
            "",
            "Function keys and hotkeys:",
            "  Panel tabs show hotkeys, for example [J] Jobs and [T] Task Creator",
            "  Restriction Builder is temporarily removed; use Classes/Class Creator/module commands instead",
            "  Type the hotkey or any unique command prefix to move panels",
            "  F1 Help         F2 command line      F3 Queue Users",
            "  F4 Jobs         F5 Refresh           F6 Dry-run",
            "  F7 Filter       F8 detail tab        F10 Action",
            "  F12/Esc Quit",
            "  Exception overlays are typed commands: ex, exception, ce, clear-exception.",
            "  F11 is deliberately not bound because many Linux desktops use it for full-screen.",
            "  Terminals that expose F13-F24/Alt-Fn may map them later; the panel keeps commands typeable for normal keyboards.",
            "",
            "Fields:",
            "  Field entry: * opens searchable list; type part to filter; ↑/↓ selects",
            "  Delete on an inactive Class/Task Creator field clears that field",
            "  Optional user fields accept current, none, clear, default, or -",
            "",
            "Maintenance:",
            "  queue/default   submit maintenance as QUEUE_MAINTENANCE job",
            "  direct          urgent run now, after confirmation",
        ]))

    def loop(self) -> None:
        self.setup()
        while True:
            self.draw()
            k = self.stdscr.getch()
            v = self.view

            if k in (27, curses.KEY_F12):
                break
            if k == curses.KEY_F1:
                self.help()
            elif k == curses.KEY_F2:
                self.command_prompt()
            elif k == curses.KEY_F3:
                self.switch_view("users")
            elif k == curses.KEY_F4:
                self.switch_view("jobs")
            elif k == curses.KEY_F5:
                self.refresh_current()
            elif k == curses.KEY_F6:
                self.dry_run = not self.dry_run
                self.status = f"Dry-run mode {'ON' if self.dry_run else 'OFF'}"
            elif k == curses.KEY_F7:
                self.set_filter()
            elif k == curses.KEY_F8:
                self.cycle_right_pane_mode(1)
            elif k == curses.KEY_F9:
                self.status = "F9 is not bound; type job <qid> copy to copy a job into Task Creator"
            elif k == curses.KEY_F10:
                self.action()
            elif k == curses.KEY_F11:
                # Deliberately unbound: many Linux terminal emulators/window managers
                # reserve F11 for full-screen.  Use typed commands instead:
                #   ex / exception
                #   ce / clear-exception
                self.status = "F11 is not bound; type ex/exception or ce/clear-exception"
            elif k == curses.KEY_DC:
                self.clear_current_editor_field()
            elif k in (curses.KEY_BTAB, 353):
                self.active = (self.active - 1) % len(self.views)
            elif k == 9:
                self.active = (self.active + 1) % len(self.views)
            elif k == curses.KEY_UP:
                v.selected = max(0, v.selected - 1)
                v.detail_scroll = 0
            elif k == curses.KEY_DOWN:
                v.selected = min(max(0, len(v.items) - 1), v.selected + 1)
                v.detail_scroll = 0
            elif k == curses.KEY_NPAGE:
                v.selected = min(max(0, len(v.items) - 1), v.selected + 10)
                v.detail_scroll = 0
            elif k == curses.KEY_PPAGE:
                v.selected = max(0, v.selected - 10)
                v.detail_scroll = 0
            elif k == curses.KEY_RIGHT:
                v.detail_scroll += 5
            elif k == curses.KEY_LEFT:
                v.detail_scroll = max(0, v.detail_scroll - 5)
            elif k == ord("]"):
                self.cycle_right_pane_mode(1)
            elif k == ord("["):
                self.cycle_right_pane_mode(-1)
            elif k in (10, 13):
                self.action()
            elif k in (ord(":"), ord("/")):
                self.command_prompt()
            elif 32 <= k <= 126:
                self.command_prompt(chr(k))



def _dev_json_error(message: str, code: int = 1) -> None:
    import json
    import sys
    print(json.dumps({"status": "error", "error": message}))
    raise SystemExit(code)


def _dev_locate_and_extract(target_name: str, extract: bool = False) -> None:
    import inspect
    import json
    import sys

    obj = globals().get(target_name)
    if obj is None:
        _dev_json_error(f"Target '{target_name}' not found.")
    try:
        lines, start_line = inspect.getsourcelines(obj)
        file_name = inspect.getsourcefile(obj) or __file__
        result = {
            "target": target_name,
            "file": file_name,
            "line_start": start_line,
            "line_end": start_line + len(lines) - 1,
        }
        if extract:
            result["body"] = "".join(lines)
        print(json.dumps(result))
    except Exception as exc:
        _dev_json_error(str(exc))


def _dev_functions() -> None:
    import inspect
    import json

    out = []
    for name, obj in sorted(globals().items()):
        if not (inspect.isfunction(obj) or inspect.isclass(obj)):
            continue
        try:
            lines, start_line = inspect.getsourcelines(obj)
            file_name = inspect.getsourcefile(obj) or __file__
            out.append({
                "target": name,
                "kind": "class" if inspect.isclass(obj) else "function",
                "file": file_name,
                "line_start": start_line,
                "line_end": start_line + len(lines) - 1,
            })
        except Exception:
            continue
    print(json.dumps({"targets": out}))


def _dev_patch(target_name: str, source_file: str) -> None:
    import ast
    import json
    import os
    import shutil
    import sys
    from pathlib import Path

    target_file = Path(__file__).resolve()
    new_code_path = Path(source_file)
    if not new_code_path.exists():
        _dev_json_error("Source file not found.")
    new_source = new_code_path.read_text()
    if not new_source.endswith("\n"):
        new_source += "\n"
    original_source = target_file.read_text()
    try:
        tree = ast.parse(original_source)
    except SyntaxError as exc:
        _dev_json_error(f"Current file syntax is broken: {exc}")
    start_lineno = None
    end_lineno = None
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and node.name == target_name:
            start_lineno = node.lineno
            end_lineno = getattr(node, "end_lineno", None)
            break
    if start_lineno is None or end_lineno is None:
        _dev_json_error(f"Target '{target_name}' not found in AST.")
    lines = original_source.splitlines(keepends=True)
    patched_source = "".join(lines[: start_lineno - 1]) + new_source + "".join(lines[end_lineno:])
    try:
        ast.parse(patched_source)
    except SyntaxError as exc:
        _dev_json_error(f"Patch rejected. Syntax error in new code: {exc}")
    backup_path = target_file.with_name(f"{target_file.name}.bak.{os.getpid()}")
    shutil.copy2(target_file, backup_path)
    target_file.write_text(patched_source)
    print(json.dumps({
        "status": "patched",
        "target": target_name,
        "file": str(target_file),
        "line_start": start_lineno,
        "line_end": end_lineno,
        "backup": str(backup_path),
        "syntax_checked": True,
    }))



def _dev_symbols(target_name: str | None = None) -> None:
    import ast
    import json
    from pathlib import Path

    source_path = Path(__file__).resolve()
    source = source_path.read_text()
    tree = ast.parse(source)
    functions = []
    classes = []
    variables: dict[str, dict] = {}
    constants: dict[str, dict] = {}
    strings = []
    scope_stack: list[str] = []

    def rec(name: str) -> dict:
        return variables.setdefault(name, {
            "definitions": [],
            "references": [],
            "defined_in": [],
            "referenced_in": [],
            "scope": "unknown",
            "constant": False,
        })

    def add_unique(items: list, value):
        if value not in items:
            items.append(value)

    def current_scope() -> str:
        return ".".join(scope_stack) if scope_stack else "module"

    class Visitor(ast.NodeVisitor):
        def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
            scope = current_scope()
            functions.append({"name": node.name, "qualified_name": f"{scope}.{node.name}" if scope != "module" else node.name, "line_start": node.lineno, "line_end": getattr(node, "end_lineno", node.lineno)})
            scope_stack.append(node.name)
            self.generic_visit(node)
            scope_stack.pop()

        def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
            self.visit_FunctionDef(node)  # type: ignore[arg-type]

        def visit_ClassDef(self, node: ast.ClassDef) -> None:
            scope = current_scope()
            classes.append({"name": node.name, "qualified_name": f"{scope}.{node.name}" if scope != "module" else node.name, "line_start": node.lineno, "line_end": getattr(node, "end_lineno", node.lineno)})
            scope_stack.append(node.name)
            self.generic_visit(node)
            scope_stack.pop()

        def visit_Assign(self, node: ast.Assign) -> None:
            for target in node.targets:
                self._record_target(target, node.lineno, "assignment")
            self.generic_visit(node)

        def visit_AnnAssign(self, node: ast.AnnAssign) -> None:
            self._record_target(node.target, node.lineno, "annotation")
            self.generic_visit(node)

        def visit_AugAssign(self, node: ast.AugAssign) -> None:
            self._record_target(node.target, node.lineno, "augassign")
            self.generic_visit(node)

        def visit_Name(self, node: ast.Name) -> None:
            if isinstance(node.ctx, ast.Load):
                r = rec(node.id)
                r["references"].append({"line": node.lineno, "scope": current_scope()})
                add_unique(r["referenced_in"], current_scope())
            self.generic_visit(node)

        def visit_Constant(self, node: ast.Constant) -> None:
            if isinstance(node.value, str) and node.value:
                strings.append({"line": node.lineno, "scope": current_scope(), "value": node.value})
            self.generic_visit(node)

        def _record_target(self, target, line: int, kind: str) -> None:
            names = []
            if isinstance(target, ast.Name):
                names.append(target.id)
            elif isinstance(target, (ast.Tuple, ast.List)):
                for elt in target.elts:
                    if isinstance(elt, ast.Name):
                        names.append(elt.id)
            for name in names:
                r = rec(name)
                scope = current_scope()
                r["definitions"].append({"line": line, "scope": scope, "kind": kind})
                add_unique(r["defined_in"], scope)
                r["scope"] = "global" if scope == "module" else "local"
                if name.isupper():
                    r["constant"] = True

    Visitor().visit(tree)
    constants = {name: value for name, value in variables.items() if value.get("constant")}
    result = {
        "status": "ok",
        "file": str(source_path),
        "target": target_name,
        "functions": functions,
        "classes": classes,
        "variables": dict(sorted(variables.items())),
        "constants": dict(sorted(constants.items())),
        "strings": strings,
    }
    if target_name:
        result["functions"] = [f for f in functions if f["name"] == target_name or f["qualified_name"].endswith(f".{target_name}")]
        result["classes"] = [c for c in classes if c["name"] == target_name or c["qualified_name"].endswith(f".{target_name}")]
    print(json.dumps(result))

def _dev_main(argv: list[str]) -> int:
    if not argv:
        print("Usage: --dev functions|locate|extract|patch|symbols", file=sys.stderr)
        return 2
    cmd = argv[0]
    if cmd == "functions":
        _dev_functions()
        return 0
    if cmd == "locate" and len(argv) >= 2:
        _dev_locate_and_extract(argv[1], extract=False)
        return 0
    if cmd == "extract" and len(argv) >= 2:
        _dev_locate_and_extract(argv[1], extract=True)
        return 0
    if cmd == "patch" and len(argv) >= 3:
        _dev_patch(argv[1], argv[2])
        return 0
    if cmd == "symbols":
        _dev_symbols(argv[1] if len(argv) >= 2 else None)
        return 0
    print("Usage: --dev functions|locate TARGET|extract TARGET|patch TARGET SOURCE|symbols [TARGET]", file=sys.stderr)
    return 2


def main() -> int:
    curses.wrapper(lambda stdscr: PanelManager(stdscr).loop())
    return 0


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--dev":
        raise SystemExit(_dev_main(sys.argv[2:]))
    raise SystemExit(main())
