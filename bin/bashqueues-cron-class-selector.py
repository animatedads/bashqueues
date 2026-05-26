#!/usr/bin/env python3
"""bashqueues cron class selector plugin.

Analyses a cron command string and returns the most appropriate bashqueues
class name for it. Called by the cron ticker when no explicit BASHQUEUES_CLASS
is declared in the crontab entry.

Usage (from ticker or CLI):
    bashqueues-cron-class-selector.py --command "CMD" --user USER [--json]
    bashqueues-cron-class-selector.py --command "CMD" --user USER [--explain]

Returns (stdout):
    Plain:  CLASS_NAME  (or empty string if no match — use generated safe class)
    JSON:   {"class": "CLASS_NAME", "confidence": 0-100, "reason": "..."}

The selector applies ordered rules from highest confidence to lowest.
The first rule that fires wins. Rules are intentionally conservative:
when in doubt, return empty and let the ticker generate a safe cron class.

Integration with the cron ticker:
    In _resolve_cron_class, when explicit_class is None, call this selector.
    If it returns a non-empty class name, use it in place of the generated class.
    The selector-chosen class is treated as operator-declared for policy purposes
    and must pass _cron_class_below_minimum before being accepted.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import List, Optional, Tuple


# ---------------------------------------------------------------------------
# Rule definitions
# ---------------------------------------------------------------------------
# Each rule is (priority, class_name, confidence, reason, pattern_fn)
# pattern_fn(command: str, env: dict) -> bool

class Rule:
    def __init__(self, priority: int, class_name: str, confidence: int,
                 reason: str, pattern_fn):
        self.priority = priority
        self.class_name = class_name
        self.confidence = confidence
        self.reason = reason
        self.pattern_fn = pattern_fn

    def matches(self, command: str, env: dict) -> bool:
        try:
            return bool(self.pattern_fn(command, env))
        except Exception:
            return False


def _cmd(command: str) -> str:
    """Normalised lowercase command for matching."""
    return command.lower()


def _has_token(command: str, *tokens: str) -> bool:
    """True if any token appears as a word boundary in the command."""
    c = _cmd(command)
    for t in tokens:
        if re.search(r'(?:^|[\s/])' + re.escape(t.lower()) + r'(?:$|[\s\.])', c):
            return True
    return False


def _has_substr(command: str, *substrings: str) -> bool:
    c = _cmd(command)
    return any(s.lower() in c for s in substrings)


def _looks_like_script(command: str, *extensions: str) -> bool:
    c = _cmd(command)
    return any(c.endswith('.' + e) or ('.' + e + ' ') in c for e in extensions)


RULES: List[Rule] = [

    # ── Sensitive / regulated data exports (highest priority) ──────────────
    Rule(10, "SENSITIVE_DATA_EXPORT", 90,
         "command contains export/extract keywords alongside sensitive data signals",
         lambda cmd, env: (
             _has_token(cmd, "export", "extract", "dump") and
             _has_substr(cmd, "pii", "gdpr", "hipaa", "sensitive", "regulated",
                         "personal", "confidential", "restricted")
         )),

    # ── Database migrations ─────────────────────────────────────────────────
    Rule(20, "DB_MIGRATION", 88,
         "command invokes a migration tool or migration script pattern",
         lambda cmd, env: (
             _has_token(cmd, "migrate", "migration", "flyway", "liquibase",
                        "alembic", "schema", "dbmate", "sqitch") or
             (_has_substr(cmd, "db") and _has_token(cmd, "migrate", "migration", "upgrade", "schema")) or
             re.search(r'\bmigrat', _cmd(cmd)) is not None
         )),

    # ── Backup jobs ─────────────────────────────────────────────────────────
    Rule(30, "BACKUP_JOB", 85,
         "command is a backup/archive/snapshot operation",
         lambda cmd, env: (
             _has_token(cmd, "backup", "rsync", "restic", "borg", "rclone",
                        "duplicati", "bacula", "tar", "snapshot") and not
             _has_token(cmd, "restore", "recover", "extract")
         ) or _has_substr(cmd, "backup.sh", "backup.py", "do-backup",
                          "run-backup", "nightly-backup", "weekly-backup")),

    # ── Deployment / release ────────────────────────────────────────────────
    Rule(40, "DEPLOY_RELEASE", 85,
         "command performs a deployment or release promotion",
         lambda cmd, env: (
             _has_token(cmd, "deploy", "deployment", "release", "promote",
                        "rollout", "ansible-playbook", "kubectl", "helm",
                        "capistrano", "fabric") or
             _has_substr(cmd, "deploy.sh", "release.sh", "publish.sh",
                         "push-release", "do-deploy")
         )),

    # ── Deadline-critical / month-end / regulatory ──────────────────────────
    Rule(50, "DEADLINE_CRITICAL", 80,
         "command name suggests a hard-deadline or period-end workload",
         lambda cmd, env: (
             _has_substr(cmd, "month-end", "monthend", "period-end", "eom",
                         "year-end", "yearend", "eoy", "quarter-end",
                         "regulatory", "reconcil", "close-of-business",
                         "cob-run", "deadline")
         )),

    # ── File transfer ───────────────────────────────────────────────────────
    Rule(60, "FILE_TRANSFER", 80,
         "command is a file transfer operation to a remote system",
         lambda cmd, env: (
             (_has_token(cmd, "sftp", "scp", "ftp", "rclone", "s3cmd",
                         "aws s3", "gsutil", "azcopy", "curl", "wget") and
              _has_token(cmd, "upload", "download", "sync", "push", "put",
                         "copy", "transfer", "send")) or
             _has_substr(cmd, "sftp-upload", "ftp-push", "s3-upload",
                         "transfer.sh", "send-file")
         )),

    # ── Report generation ───────────────────────────────────────────────────
    Rule(70, "REPORT_GENERATION", 78,
         "command generates a report, spreadsheet, or document",
         lambda cmd, env: (
             _has_token(cmd, "report", "reporting") or
             _has_substr(cmd, "generate-report", "run-report", "report.py",
                         "report.sh", "render-report", "crystal-report",
                         "jasper", "weasyprint", "pdfkit", "openpyxl-report")
         )),

    # ── Log housekeeping ────────────────────────────────────────────────────
    Rule(80, "LOG_HOUSEKEEPING", 78,
         "command performs log rotation, compression, or purge",
         lambda cmd, env: (
             _has_token(cmd, "logrotate", "log-rotate") or
             (_has_token(cmd, "log", "logs") and
              _has_token(cmd, "clean", "rotate", "purge", "archive",
                         "compress", "truncate", "prune")) or
             _has_substr(cmd, "log-clean", "clean-logs", "purge-logs",
                         "rotate-logs", "log-housekeep")
         )),

    # ── Batch processing ────────────────────────────────────────────────────
    Rule(90, "BATCH_PROCESSING", 72,
         "command is a batch processing, ETL, or transformation job",
         lambda cmd, env: (
             _has_token(cmd, "batch", "etl", "transform", "process",
                        "ingest", "import", "pipeline") or
             _has_substr(cmd, "batch.sh", "batch.py", "run-batch",
                         "process-batch", "etl.sh", "etl.py",
                         "data-pipeline", "ingest.sh")
         )),

    # ── Maintenance / housekeeping (generic fallback) ───────────────────────
    Rule(100, "QUEUE_MAINTENANCE", 65,
         "command is a queue or system maintenance operation",
         lambda cmd, env: (
             _has_substr(cmd, "queue health", "queue clean", "queue compress",
                         "queue maintenance") or
             (_has_token(cmd, "maintenance", "housekeep", "cleanup", "tidy") and
              not _has_token(cmd, "log", "backup", "deploy"))
         )),

    # ── Alert / notification ────────────────────────────────────────────────
    Rule(110, "ALERT_NOTIFICATION", 70,
         "command sends an alert, notification, or status message",
         lambda cmd, env: (
             _has_token(cmd, "notify", "alert", "notification", "alarm",
                        "pagerduty", "opsgenie", "slack-notify", "sendmail",
                        "mail", "telegram-bot", "webhook") or
             _has_substr(cmd, "send-alert", "send-notification", "alert.sh",
                         "notify.sh", "send-mail.sh")
         )),
]

# Sort by priority ascending (lower number = higher priority).
RULES.sort(key=lambda r: r.priority)


# ---------------------------------------------------------------------------
# Class availability check
# ---------------------------------------------------------------------------

def _class_exists(class_name: str, user: str) -> bool:
    """Check whether the named class file exists in a queue or bundled tree."""
    home = os.path.expanduser(f"~{user}") if user else os.path.expanduser("~")
    queue_root = os.environ.get("QUEUEBASH_ROOT", os.path.join(home, ".queuebash"))
    here = Path(__file__).resolve()
    candidates = [
        Path(queue_root) / "classes" / f"{class_name}.env",
        here.parent.parent / "classes" / f"{class_name}.env",
        Path.cwd() / "classes" / f"{class_name}.env",
        Path("/usr/local/share/bashqueues/classes") / f"{class_name}.env",
    ]
    qsrc = os.environ.get("QUEUEBASH_SOURCE", "")
    if qsrc:
        candidates.append(Path(qsrc).resolve().parent / "classes" / f"{class_name}.env")
    seen = set()
    for p in candidates:
        try:
            key = str(p)
            if key in seen:
                continue
            seen.add(key)
            if p.exists():
                return True
        except OSError:
            continue
    return False


# ---------------------------------------------------------------------------
# Selector entry point
# ---------------------------------------------------------------------------

def select_class(
    command: str,
    user: str,
    env: Optional[dict] = None,
    require_class_exists: bool = True,
    min_confidence: int = 70,
) -> Tuple[Optional[str], int, str]:
    """Return (class_name, confidence, reason) for the best matching class.

    Returns (None, 0, reason) when no confident match is found or the
    matched class file does not exist on this system.
    """
    if env is None:
        env = {}
    for rule in RULES:
        if rule.matches(command, env):
            if rule.confidence < min_confidence:
                continue
            if require_class_exists and not _class_exists(rule.class_name, user):
                # Class file not installed — skip to next rule.
                continue
            return rule.class_name, rule.confidence, rule.reason
    return None, 0, "no rule matched with sufficient confidence"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description="Select a bashqueues class for a cron command"
    )
    ap.add_argument("--command", required=True, help="Cron command string")
    ap.add_argument("--user", default=os.environ.get("USER", ""), help="Cron user")
    ap.add_argument("--json", "-j", action="store_true", help="JSON output")
    ap.add_argument("--explain", action="store_true",
                    help="Show all rule evaluations")
    ap.add_argument("--min-confidence", type=int, default=70,
                    help="Minimum confidence threshold (default 70)")
    ap.add_argument("--no-existence-check", action="store_true",
                    help="Skip class file existence check")
    ns = ap.parse_args(argv)

    if ns.explain:
        results = []
        for rule in RULES:
            matched = rule.matches(ns.command, {})
            exists = (not ns.no_existence_check and
                      _class_exists(rule.class_name, ns.user))
            results.append({
                "priority": rule.priority,
                "class": rule.class_name,
                "confidence": rule.confidence,
                "reason": rule.reason,
                "matched": matched,
                "class_exists": exists,
                "would_select": (matched and rule.confidence >= ns.min_confidence
                                 and (ns.no_existence_check or exists)),
            })
        if ns.json:
            print(json.dumps({"command": ns.command, "user": ns.user,
                               "rules": results}, indent=2))
        else:
            print(f"Command: {ns.command}")
            print(f"User:    {ns.user}")
            print()
            for r in results:
                marker = ">>> " if r["would_select"] else "    "
                tick = "✓" if r["matched"] else "✗"
                exist = "exists" if r["class_exists"] else "absent"
                print(f"{marker}[{tick}] p={r['priority']:3d} "
                      f"conf={r['confidence']:3d} "
                      f"class={r['class']:<30s} "
                      f"({exist}) {r['reason'][:60]}")
        return 0

    class_name, confidence, reason = select_class(
        ns.command,
        ns.user,
        min_confidence=ns.min_confidence,
        require_class_exists=not ns.no_existence_check,
    )

    if ns.json:
        print(json.dumps({
            "class": class_name or "",
            "confidence": confidence,
            "reason": reason,
            "command": ns.command,
            "user": ns.user,
        }))
    else:
        if class_name:
            print(class_name)
        # Empty output = no match; caller generates safe cron class.

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
