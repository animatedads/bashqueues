#!/usr/bin/env python3
from __future__ import annotations

import curses
import os
import re
import shlex
import subprocess
import textwrap
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, List, Optional, Sequence, Tuple

QUEUE_ROOT = os.environ.get("QUEUEBASH_ROOT", os.path.expanduser("~/.queuebash"))


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
    if not path or not Path(path).is_file():
        return False
    cmd = (
        "export QUEUEBASH_ALLOW_NONINTERACTIVE=1; "
        f"source {shlex.quote(path)} >/dev/null 2>&1; "
        "declare -F queue >/dev/null || type queue >/dev/null 2>&1"
    )
    return subprocess.run(["bash", "-lc", cmd], text=True, capture_output=True, timeout=5).returncode == 0


def _discover_queue_source() -> str:
    for cand in _candidate_queue_sources():
        if _source_defines_queue(cand):
            return cand
    return ""


QUEUE_SOURCE = _discover_queue_source()


def _queue_shell_command(args: Sequence[str]) -> str:
    quoted = " ".join(shlex.quote(a) for a in args)
    if QUEUE_SOURCE:
        return (
            "export QUEUEBASH_ALLOW_NONINTERACTIVE=1; "
            f"source {shlex.quote(QUEUE_SOURCE)} >/dev/null 2>&1; "
            f"queue {quoted}"
        )
    return f"queue {quoted}"


def qrun(args: Sequence[str], timeout: int = 20, dry_run: bool = False, cwd: str = "", as_user: str = "") -> Tuple[int, str]:
    # If root/operator submits as another user and no execution directory was
    # explicitly chosen, do not inherit the operator's current directory. Submit
    # from the target user's HOME so PWD_AT_SUBMIT is accessible to that user.
    delegated_default_home = bool(as_user and not cwd)

    if cwd:
        cwd_prefix = f"cd {shlex.quote(cwd)} && "
    elif delegated_default_home:
        cwd_prefix = 'cd "$HOME" && '
    else:
        cwd_prefix = ""

    base_preview = cwd_prefix + "queue " + " ".join(shlex.quote(a) for a in args)
    if as_user:
        base_preview = f"runuser -u {shlex.quote(as_user)} -- bash -lc " + shlex.quote(base_preview)

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
    if as_user:
        cmd = "runuser -u " + shlex.quote(as_user) + " -- bash -lc " + shlex.quote(cmd)

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
        out = (exc.stdout or "") + (exc.stderr or "")
        return 124, (out + f"\n[timeout running queue command: {cmd}]").strip()


def split_lines(s: str) -> List[str]:
    return s.splitlines() if s else []


@dataclass
class Item:
    key: str
    label: str
    meta: str = ""
    fields: dict[str, str] = field(default_factory=dict)



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
        lines.append("")
        lines.extend(self.records or ["# Add restrictions/claims with the Restriction Builder."])
        lines.append("")
        return "\n".join(lines)

    def class_name(self) -> str:
        return (self.name or "NEW_CLASS").strip().upper().replace("-", "_").replace(" ", "_")


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
    cpu_limit: str = ""
    mem_limit: str = ""
    max_log_size: str = ""

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
        if self.cpu_limit:
            args.extend(["--cpu", self.cpu_limit])
        if self.mem_limit:
            args.extend(["--mem", self.mem_limit])
        if self.max_log_size:
            args.extend(["--max-log-size", self.max_log_size])
        args.append("--")
        args.extend(shlex.split(self.command or "true"))
        return args

    def render_command(self) -> str:
        base = "queue " + " ".join(shlex.quote(x) for x in self.submit_args())
        if self.execution_dir:
            base = "cd " + shlex.quote(self.execution_dir) + " && " + base
        elif self.submit_user:
            # Delegated submit without an explicit directory should not capture
            # the operator's cwd. Submit from the target user's HOME.
            base = 'cd "$HOME" && ' + base
        if self.submit_user:
            base = "runuser -u " + shlex.quote(self.submit_user) + " -- bash -lc " + shlex.quote(base)
        return base

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


def load_exceptions(app: "PanelManager") -> List[Item]:
    d = Path(QUEUE_ROOT) / "exceptions"
    items: List[Item] = []
    if d.is_dir():
        for f in sorted(d.glob("*.env")):
            try:
                count = len([x for x in f.read_text(errors="ignore").splitlines() if x.strip()])
            except OSError:
                count = 0
            items.append(Item(f.stem, f.stem, f"{count} overlay(s)"))
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
        "Use Restriction Builder to add shared/exclusive asset records.",
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
        Item("cpu_limit", f"CPU override         {d.cpu_limit or '-'}"),
        Item("mem_limit", f"memory override      {d.mem_limit or '-'}"),
        Item("max_log_size", f"log cap override     {d.max_log_size or '-'}"),
        Item("preview", "preview queue submit command"),
        Item("dryrun", "dry-run submit"),
        Item("submit", "submit task"),
        Item("clear", "clear draft"),
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
        "Submit user uses runuser when set; intended for root/operator use.",
        "Execution directory is used as PWD_AT_SUBMIT.",
        "If submit user is set and execution directory is blank, submit from that user's HOME.",
        "Scheduling uses queue submit --not-before syntax.",
        "Examples: 2026-05-23T22:00:00+01:00, +2h, tomorrow 18:00",
        "",
        "=== SUBMIT PREVIEW ===",
        d.render_command(),
        class_detail,
    ])

class PanelManager:
    DETAIL_TABS = ["Explain", "Class", "Exceptions", "History", "Log"]

    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.dry_run = False
        self.class_draft = ClassDraft()
        self.task_draft = TaskDraft()
        self.job_state_filter = "all"
        self.job_text_filter = ""
        self.class_filter = ""
        self.asset_filter = ""
        self.detail_tab_index = 0
        self.status = "F1 Help  F5 Refresh  d Dry-run  f Filter  Tab Switch  [/] Detail tab  e Exception  x/Enter Action  q Quit"
        self.views = [
            ViewState("jobs", "Jobs", load_jobs, detail_job),
            ViewState("classes", "Classes", load_classes, detail_class),
            ViewState("assets", "Assets", load_assets, detail_asset),
            ViewState("exceptions", "Exceptions", load_exceptions, detail_exception),
            ViewState("builder", "Restriction Builder", load_restriction_builder, detail_restriction_builder),
            ViewState("classdraft", "Class Creator", load_class_draft, detail_class_draft),
            ViewState("taskdraft", "Task Creator", load_task_draft, detail_task_draft),
        ]
        self.active = 0

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

    def draw_tabs(self, y: int) -> None:
        x = 2
        for i, v in enumerate(self.views):
            label = f" {i + 1}:{v.title} "
            self.safe_addstr(y, x, label, curses.A_REVERSE | curses.A_BOLD if i == self.active else curses.A_NORMAL)
            x += len(label) + 1

    def draw_detail_tabs(self, y: int, x: int, w: int) -> None:
        if self.view.name != "jobs":
            return
        xx = x
        for i, tab in enumerate(self.DETAIL_TABS):
            label = f" {tab} "
            attr = curses.A_REVERSE | curses.A_BOLD if i == self.detail_tab_index else curses.A_NORMAL
            self.safe_addstr(y, xx, label[: max(0, w - (xx - x))], attr)
            xx += len(label) + 1

    def draw(self) -> None:
        self.stdscr.erase()
        h, w = self.stdscr.getmaxyx()
        self.safe_addstr(0, 2, "QUEUEBASH PANEL MANAGER", curses.A_BOLD)
        src_label = Path(QUEUE_SOURCE).name if QUEUE_SOURCE else "NO QUEUE SOURCE"
        mode = "DRY-RUN" if self.dry_run else "LIVE"
        self.safe_addstr(0, 28, f"src: {src_label}  mode: {mode}", curses.A_BOLD if self.dry_run else curses.A_NORMAL)
        self.safe_addstr(0, max(2, w - len(QUEUE_ROOT) - 8), f"root: {QUEUE_ROOT}")
        self.draw_tabs(1)

        filter_line = f"state={self.job_state_filter} text={self.job_text_filter or '-'} class={self.class_filter or '-'} asset={self.asset_filter or '-'}"
        self.safe_addstr(2, 2, filter_line[: w - 4])

        left_w = max(38, w // 2)
        right_w = w - left_w - 1
        top = 3
        body_h = max(6, h - 6)

        self.draw_box(top, 0, body_h, left_w, self.view.title)
        self.draw_box(top, left_w, body_h, right_w, "Detail / Hint / Output")
        self.draw_detail_tabs(top, left_w + 2, right_w - 4)

        self.draw_left(top + 1, 1, body_h - 2, left_w - 2)
        self.draw_right(top + 1, left_w + 1, body_h - 2, right_w - 2)

        self.safe_addstr(h - 2, 0, "─" * (w - 1))
        self.safe_addstr(h - 1, 1, self.status[: w - 2], curses.A_REVERSE)
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

    def confirm(self, prompt: str) -> bool:
        return self.prompt(prompt + " y/N", "N").lower().startswith("y")

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
            state = self.prompt("State filter all/pending/running/done/failed/cancelled/deleted", self.job_state_filter)
            self.job_state_filter = state or "all"
            self.job_text_filter = self.prompt("Job text filter", self.job_text_filter)
        elif self.view.name == "classes":
            self.class_filter = self.prompt("Class filter", self.class_filter)
        elif self.view.name in {"assets", "builder"}:
            self.asset_filter = self.prompt("Asset/facility filter", self.asset_filter)
        self.view.refresh(self)

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
        asset = self.prompt("Asset/facility to ignore, e.g. time:window")
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
        asset = self.prompt("Asset/facility to clear")
        if not asset:
            return
        rc, out = qrun(["exception", "clear", qid, asset], dry_run=self.dry_run)
        self.status = out.splitlines()[-1] if out else f"exception clear rc={rc}"
        self.refresh_current()

    def job_action(self) -> None:
        qid = self.selected_qid()
        if not qid:
            return
        action = self.prompt("Job action cancel/delete/resubmit/show/tail/history/explain")
        if action not in {"cancel", "delete", "resubmit", "show", "tail", "history", "explain"}:
            self.status = "Unknown job action"
            return
        if action in {"cancel", "delete"} and not self.confirm(f"{action} {qid}?"):
            self.status = "Cancelled action"
            return
        cmd = {"delete": "delete", "cancel": "cancel", "resubmit": "resubmit"}.get(action, action)
        rc, out = qrun([cmd, qid], dry_run=self.dry_run)
        if action in {"show", "tail", "history", "explain"}:
            self.popup(f"queue {cmd} {qid}", out[:8000])
        else:
            self.status = out.splitlines()[-1] if out else f"{action} rc={rc}"
            self.refresh_current()

    def queue_clear_action(self) -> None:
        target = self.prompt("Clear queue done/failed/cancelled/deleted/interrupted")
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
        action = self.prompt("Class action explain/edit/validate/delete/refresh/rollback/use-for-task")
        if action == "explain":
            _, out = qrun(["classes", "explain", it.key])
            self.popup("Class explain", out[:8000])
        elif action == "edit":
            rc, out = qrun(["classes", "edit", it.key], dry_run=self.dry_run)
            self.status = out.splitlines()[-1] if out else f"edit rc={rc}"
        elif action == "validate":
            rc, out = qrun(["classes", "validate", it.key])
            self.popup("Class validate", out[:8000])
        elif action == "delete":
            if self.confirm(f"archive class {it.key}?"):
                rc, out = qrun(["classes", "delete", it.key], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"delete rc={rc}"
        elif action == "refresh":
            d = self.prompt("Directory", "classes")
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

    def asset_action(self) -> None:
        it = self.view.current()
        if not it or it.key == "__error__":
            return
        family = it.key.split(":", 1)[0]
        action = self.prompt("Asset action explain/hint/validate/delete/refresh/rollback")
        if action == "explain":
            _, out = qrun(["assets", "explain", it.key])
            self.popup("Asset explain", out[:8000])
        elif action == "hint":
            _, out = qrun(["asset-hint", it.key])
            self.popup("Asset hint", out[:8000])
        elif action == "validate":
            _, out = qrun(["assets", "validate", family])
            self.popup("Asset validate", out[:8000])
        elif action == "delete":
            if self.confirm(f"archive asset plugin {family}?"):
                rc, out = qrun(["assets", "delete", family], dry_run=self.dry_run)
                self.status = out.splitlines()[-1] if out else f"delete rc={rc}"
        elif action == "refresh":
            d = self.prompt("Directory", "assets.d")
            rc, out = qrun(["assets", "refresh", d], dry_run=self.dry_run)
            self.popup("Asset refresh", out[:8000])
        elif action == "rollback":
            rc, out = qrun(["assets", "rollback", family], dry_run=self.dry_run)
            self.popup("Asset rollback", out[:8000])
        self.refresh_current()

    def select_class_for_task(self) -> None:
        classes = [it.key for it in load_classes(self) if it.key != "__error__"]
        if classes:
            self.popup("Available classes", "\n".join(f"{i+1}: {name}" for i, name in enumerate(classes)))
        choice = self.prompt("Class number or name", self.task_draft.job_class)
        if not choice:
            return
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(classes):
                self.task_draft.job_class = classes[idx]
                return
        self.task_draft.job_class = choice.upper().replace("-", "_").replace(" ", "_")

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
            d.submit_user = self.prompt("Submit as user", d.submit_user)
        elif key == "execution_dir":
            d.execution_dir = self.prompt("Execution directory", d.execution_dir)
        elif key == "not_before":
            d.not_before = self.prompt("Schedule / not-before", d.not_before)
        elif key == "retries":
            d.retries = self.prompt("Retries", d.retries or "0")
        elif key == "retry_backoff":
            d.retry_backoff = self.prompt("Retry backoff", d.retry_backoff)
        elif key == "runner":
            d.runner = self.prompt("Runner override auto/direct/systemd", d.runner)
        elif key == "cpu_limit":
            d.cpu_limit = self.prompt("CPU override, e.g. 50%", d.cpu_limit)
        elif key == "mem_limit":
            d.mem_limit = self.prompt("Memory override, e.g. 512M", d.mem_limit)
        elif key == "max_log_size":
            d.max_log_size = self.prompt("Max log size bytes", d.max_log_size)
        elif key == "preview":
            self.popup("Task submit preview", d.render_command())
        elif key == "dryrun":
            self.popup("Task dry-run submit", "DRY-RUN: would run:\n\n" + d.render_command())
        elif key == "submit":
            if not d.name or not d.command:
                self.status = "Task name and command are required"
                return
            if not self.confirm("Submit this task?"):
                self.status = "Submit cancelled"
                return
            rc, out = qrun(d.submit_args(), dry_run=self.dry_run, cwd=d.execution_dir, as_user=d.submit_user)
            self.popup("Task submit", out or f"submit rc={rc}")
            for v in self.views:
                if v.name == "jobs":
                    v.refresh(self)
        elif key == "clear":
            if self.confirm("Clear task draft?"):
                self.task_draft = TaskDraft()
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
            d.allow_parallel = self.prompt("Allow parallel 0/1", d.allow_parallel or "1")
        elif key == "max_concurrent":
            d.max_concurrent = self.prompt("Max concurrent 0=unlimited", d.max_concurrent or "0")
        elif key == "default_runner":
            d.default_runner = self.prompt("Default runner auto/direct/systemd", d.default_runner or "auto")
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
            d.default_run_user = self.prompt("Default payload/run user", d.default_run_user)
        elif key == "default_submit_user":
            d.default_submit_user = self.prompt("Default queue submit/owner user", d.default_submit_user)
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
        action = self.prompt("Records action add/edit/delete/clear/list", "add")
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
        mode = self.prompt("Record type shared/exclusive/claim", "shared")
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

    def action(self) -> None:
        if self.view.name == "jobs":
            self.job_action()
        elif self.view.name == "classes":
            self.class_action()
        elif self.view.name == "assets":
            self.asset_action()
        elif self.view.name == "builder":
            self.builder_action()
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
            "  1-7 / Tab       switch panel",
            "  Up/Down         move list",
            "  PgUp/PgDn       scroll list",
            "  Left/Right      scroll detail",
            "  [ and ]         switch right-hand job detail tab",
            "",
            "Global:",
            "  F5/r            refresh",
            "  d               toggle dry-run mode",
            "  f               filter current panel",
            "  x / Enter       context action; command output opens a scrollable panel",
            "  C               clear queue buckets",
            "",
            "Jobs:",
            "  e               add QID exception overlay; class is shown first",
            "  c               clear QID exception overlay",
            "",
            "Classes/Assets:",
            "  x               explain/edit/validate/delete/refresh/rollback",
            "",
            "q                 quit",
        ]))

    def loop(self) -> None:
        self.setup()
        while True:
            self.draw()
            k = self.stdscr.getch()
            v = self.view

            if k in (ord("q"), ord("Q")):
                break
            if k in (curses.KEY_F1, ord("?")):
                self.help()
            elif k in (curses.KEY_F5, ord("r"), ord("R")):
                self.refresh_current()
            elif k in (ord("d"), ord("D")):
                self.dry_run = not self.dry_run
                self.status = f"Dry-run mode {'ON' if self.dry_run else 'OFF'}"
            elif k in (ord("f"), ord("F")):
                self.set_filter()
            elif k == 9:
                self.active = (self.active + 1) % len(self.views)
            elif ord("1") <= k <= ord("9"):
                idx = k - ord("1")
                if idx < len(self.views):
                    self.active = idx
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
                self.detail_tab_index = (self.detail_tab_index + 1) % len(self.DETAIL_TABS)
                v.detail_scroll = 0
            elif k == ord("["):
                self.detail_tab_index = (self.detail_tab_index - 1) % len(self.DETAIL_TABS)
                v.detail_scroll = 0
            elif k in (10, 13, ord("x"), ord("X")):
                self.action()
            elif k in (ord("e"), ord("E")) and v.name == "jobs":
                self.add_exception()
            elif k in (ord("c"),) and v.name in {"jobs", "exceptions"}:
                self.clear_exception()
            elif k == ord("C"):
                self.queue_clear_action()


def main() -> int:
    curses.wrapper(lambda stdscr: PanelManager(stdscr).loop())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
