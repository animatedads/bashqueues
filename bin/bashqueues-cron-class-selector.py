#!/usr/bin/env python3
"""bashqueues cron class selector plugin.

Conservative cron class selector with optional governance routing.

Default behaviour remains pattern based.  When cron metadata provides a
jurisdiction/security classification tuple, the selector may choose a compliant
cloud/security class from policy rather than hard-coding one into the crontab.
If fail-closed is requested and no compliant class can be selected, the selector
returns CRON_POLICY_BLOCKED so the job is submitted into a non-runnable class
rather than silently falling back to a generated generic cron class.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple


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
    return command.lower()


def _has_token(command: str, *tokens: str) -> bool:
    c = _cmd(command)
    for t in tokens:
        if re.search(r'(?:^|[\s/])' + re.escape(t.lower()) + r'(?:$|[\s\.])', c):
            return True
    return False


def _has_substr(command: str, *substrings: str) -> bool:
    c = _cmd(command)
    return any(s.lower() in c for s in substrings)


RULES: List[Rule] = [
    Rule(10, "SENSITIVE_DATA_EXPORT", 90,
         "command contains export/extract keywords alongside sensitive data signals",
         lambda cmd, env: (_has_token(cmd, "export", "extract", "dump") and
                           _has_substr(cmd, "pii", "gdpr", "hipaa", "sensitive", "regulated", "personal", "confidential", "restricted"))),
    Rule(20, "DB_MIGRATION", 88,
         "command invokes a migration tool or migration script pattern",
         lambda cmd, env: (_has_token(cmd, "migrate", "migration", "flyway", "liquibase", "alembic", "schema", "dbmate", "sqitch") or
                           (_has_substr(cmd, "db") and _has_token(cmd, "migrate", "migration", "upgrade", "schema")) or
                           re.search(r'\bmigrat', _cmd(cmd)) is not None)),
    Rule(30, "BACKUP_JOB", 85,
         "command is a backup/archive/snapshot operation",
         lambda cmd, env: ((_has_token(cmd, "backup", "rsync", "restic", "borg", "rclone", "duplicati", "bacula", "tar", "snapshot") and not
                            _has_token(cmd, "restore", "recover", "extract")) or
                           _has_substr(cmd, "backup.sh", "backup.py", "do-backup", "run-backup", "nightly-backup", "weekly-backup"))),
    Rule(40, "DEPLOY_RELEASE", 85,
         "command performs a deployment or release promotion",
         lambda cmd, env: (_has_token(cmd, "deploy", "deployment", "release", "promote", "rollout", "ansible-playbook", "kubectl", "helm", "capistrano", "fabric") or
                           _has_substr(cmd, "deploy.sh", "release.sh", "publish.sh", "push-release", "do-deploy"))),
    Rule(50, "DEADLINE_CRITICAL", 80,
         "command name suggests a hard-deadline or period-end workload",
         lambda cmd, env: _has_substr(cmd, "month-end", "monthend", "period-end", "eom", "year-end", "yearend", "eoy", "quarter-end", "regulatory", "reconcil", "close-of-business", "cob-run", "deadline")),
    Rule(60, "FILE_TRANSFER", 80,
         "command is a file transfer operation to a remote system",
         lambda cmd, env: (((_has_token(cmd, "sftp", "scp", "ftp", "rclone", "s3cmd", "aws s3", "gsutil", "azcopy", "curl", "wget") and
                             _has_token(cmd, "upload", "download", "sync", "push", "put", "copy", "transfer", "send"))) or
                           _has_substr(cmd, "sftp-upload", "ftp-push", "s3-upload", "transfer.sh", "send-file"))),
    Rule(70, "REPORT_GENERATION", 78,
         "command generates a report, spreadsheet, or document",
         lambda cmd, env: (_has_token(cmd, "report", "reporting") or _has_substr(cmd, "generate-report", "run-report", "report.py", "report.sh", "render-report", "crystal-report", "jasper", "weasyprint", "pdfkit", "openpyxl-report"))),
    Rule(80, "LOG_HOUSEKEEPING", 78,
         "command performs log rotation, compression, or purge",
         lambda cmd, env: (_has_token(cmd, "logrotate", "log-rotate") or
                           (_has_token(cmd, "log", "logs") and _has_token(cmd, "clean", "rotate", "purge", "archive", "compress", "truncate", "prune")) or
                           _has_substr(cmd, "log-clean", "clean-logs", "purge-logs", "rotate-logs", "log-housekeep"))),
    Rule(90, "BATCH_PROCESSING", 72,
         "command is a batch processing, ETL, or transformation job",
         lambda cmd, env: (_has_token(cmd, "batch", "etl", "transform", "process", "ingest", "import", "pipeline") or
                           _has_substr(cmd, "batch.sh", "batch.py", "run-batch", "process-batch", "etl.sh", "etl.py", "data-pipeline", "ingest.sh"))),
    Rule(100, "QUEUE_MAINTENANCE", 65,
         "command is a queue or system maintenance operation",
         lambda cmd, env: (_has_substr(cmd, "queue health", "queue clean", "queue compress", "queue maintenance") or
                           (_has_token(cmd, "maintenance", "housekeep", "cleanup", "tidy") and not _has_token(cmd, "log", "backup", "deploy")))),
    Rule(110, "ALERT_NOTIFICATION", 70,
         "command sends an alert, notification, or status message",
         lambda cmd, env: (_has_token(cmd, "notify", "alert", "notification", "alarm", "pagerduty", "opsgenie", "slack-notify", "sendmail", "mail", "telegram-bot", "webhook") or
                           _has_substr(cmd, "send-alert", "send-notification", "alert.sh", "notify.sh", "send-mail.sh"))),
]
RULES.sort(key=lambda r: r.priority)


def _csv(value: str) -> List[str]:
    return [x.strip() for x in (value or "").replace(";", ",").split(",") if x.strip()]


def _norm(value: str) -> str:
    return re.sub(r"[^A-Z0-9]+", "_", (value or "").upper()).strip("_")


def _parse_env_file(path: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if not path.exists():
        return out
    rx = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = rx.match(line)
        if not m:
            continue
        k, v = m.group(1), m.group(2).strip()
        if v.startswith("$'") and v.endswith("'"):
            v = v[2:-1].encode("utf-8").decode("unicode_escape")
        elif (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
            v = v[1:-1]
        out[k] = v
    return out


def _policy_roots(user: str) -> List[Path]:
    roots: List[Path] = []
    home = os.path.expanduser(f"~{user}") if user else os.path.expanduser("~")
    queue_root = Path(os.environ.get("QUEUEBASH_ROOT", os.path.join(home, ".queuebash")))
    roots.append(Path("/etc/queuebash/policies.d"))
    roots.append(queue_root / "policies.d")
    here = Path(__file__).resolve()
    roots.append(here.parent.parent / "policies.d")
    qsrc = os.environ.get("QUEUEBASH_SOURCE", "")
    if qsrc:
        roots.append(Path(qsrc).resolve().parent / "policies.d")
    roots.append(Path.cwd() / "policies.d")
    out: List[Path] = []
    seen = set()
    for r in roots:
        s = str(r)
        if s not in seen:
            seen.add(s)
            out.append(r)
    return out


def _load_policy_candidates(user: str, rels: List[str]) -> Dict[str, str]:
    data: Dict[str, str] = {}
    for root in _policy_roots(user):
        for rel in rels:
            data.update(_parse_env_file(root / rel))
    return data


def _class_exists(class_name: str, user: str) -> bool:
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


def _infer_jurisdiction(command: str, tags: List[str], explicit: str) -> str:
    if explicit:
        return _norm(explicit)
    joined = " ".join(tags + [command]).lower()
    for name in ["gdpr", "uk_dpa", "hipaa", "itar", "cptpp", "au", "afcfta", "australia", "canada", "usa"]:
        if name.lower() in joined:
            return _norm(name)
    return ""


def _infer_classification(command: str, tags: List[str], explicit: str) -> str:
    if explicit:
        return _norm(explicit)
    joined = " ".join(tags + [command]).lower()
    for name in ["confidential", "secret", "sensitive", "official", "hipaa", "protected", "cui"]:
        if name in joined:
            return _norm(name)
    return ""


def _load_market_data() -> Dict[str, float]:
    paths: List[Path] = []
    if os.environ.get("QUEUEBASH_FINOPS_STATUS_JSON"):
        paths.append(Path(os.environ["QUEUEBASH_FINOPS_STATUS_JSON"]))
    paths.extend([Path("/var/tmp/bashqueues_finops_status.json"), Path("/etc/bashqueues/finops_status.json")])
    for p in paths:
        try:
            data = json.loads(p.read_text())
        except Exception:
            continue
        out: Dict[str, float] = {}
        if isinstance(data, dict):
            for k, v in data.items():
                try:
                    out[str(k)] = float(v)
                except Exception:
                    pass
        return out
    return {}


def _parse_registry_entry(item: str) -> Tuple[str, str, str]:
    # Accepted: provider:region:CLASS, provider:region=CLASS, provider:region
    item = item.strip()
    cls = ""
    if "=" in item:
        left, cls = item.split("=", 1)
    else:
        parts = item.split(":")
        if len(parts) >= 3:
            left = ":".join(parts[:2])
            cls = parts[2]
        else:
            left = item
    bits = left.split(":", 1)
    provider = bits[0].strip().lower() if bits else ""
    region = bits[1].strip() if len(bits) > 1 else ""
    return provider, region, cls.strip()


def _default_cloud_class(provider: str, jurisdiction: str) -> str:
    p = _norm(provider)
    j = _norm(jurisdiction)
    if p and j:
        return f"CLOUD_{p}_{j}"
    return ""


def _select_governance_class(command: str, user: str, tags: List[str], jurisdiction: str,
                             classification: str, cost_budget: str,
                             require_class_exists: bool) -> Tuple[Optional[str], int, str, Dict[str, object]]:
    j = _infer_jurisdiction(command, tags, jurisdiction)
    c = _infer_classification(command, tags, classification)
    meta: Dict[str, object] = {"jurisdiction": j, "classification": c, "tags": tags}
    if not j and not c:
        return None, 0, "no governance metadata supplied", meta

    registry = _load_policy_candidates(user, ["legal-registry/default.env", "legal_registry.env", "legal-framework/default.env", "legal_framework.env"])
    candidates_raw = registry.get(f"REGISTRY_{j}", "") or registry.get(f"LEGAL_FRAMEWORK_{j}_REGIONS", "")
    candidates: List[Dict[str, object]] = []
    market = _load_market_data()
    for item in _csv(candidates_raw):
        provider, region, cls = _parse_registry_entry(item)
        if not cls:
            cls = _default_cloud_class(provider, j)
        if not cls:
            continue
        exists = _class_exists(cls, user)
        price = None
        for key in (f"{provider}:{region}", f"{provider}:{region}:{cls}", f"{region}"):
            if key in market:
                price = market[key]
                break
        under_budget = True
        if cost_budget:
            try:
                if price is not None:
                    under_budget = float(price) <= float(cost_budget)
            except Exception:
                under_budget = True
        candidates.append({"provider": provider, "region": region, "class": cls,
                           "class_exists": exists, "price": price, "under_budget": under_budget})
    meta["candidates"] = candidates

    eligible = [x for x in candidates if x.get("under_budget") and (x.get("class_exists") or not require_class_exists)]
    if not eligible:
        return None, 0, f"no compliant class for jurisdiction={j or '-'} classification={c or '-'}", meta
    # Prefer known price lowest; otherwise declaration order.
    eligible.sort(key=lambda x: (x.get("price") is None, float(x.get("price") or 0)))
    chosen = str(eligible[0]["class"])
    conf = 96 if j else 82
    reason = f"governance route jurisdiction={j or '-'} classification={c or '-'} provider={eligible[0].get('provider')} region={eligible[0].get('region')}"
    return chosen, conf, reason, meta


def select_class(command: str, user: str, env: Optional[dict] = None,
                 require_class_exists: bool = True, min_confidence: int = 70,
                 tags: Optional[List[str]] = None, jurisdiction: str = "",
                 classification: str = "", cost_budget: str = "",
                 fail_closed: bool = False) -> Tuple[Optional[str], int, str, Dict[str, object]]:
    if env is None:
        env = {}
    if tags is None:
        tags = []

    gcls, gconf, greason, meta = _select_governance_class(
        command, user, tags, jurisdiction, classification, cost_budget, require_class_exists
    )
    if gcls and gconf >= min_confidence:
        return gcls, gconf, greason, meta
    if fail_closed and (jurisdiction or classification or tags):
        blocked = os.environ.get("QUEUEBASH_CRON_POLICY_BLOCK_CLASS", "CRON_POLICY_BLOCKED")
        if (not require_class_exists) or _class_exists(blocked, user):
            meta["fail_closed"] = True
            return blocked, 100, greason + "; fail-closed", meta
        return None, 0, greason + "; fail-closed class absent", meta

    for rule in RULES:
        if rule.matches(command, env):
            if rule.confidence < min_confidence:
                continue
            if require_class_exists and not _class_exists(rule.class_name, user):
                continue
            return rule.class_name, rule.confidence, rule.reason, meta
    return None, 0, "no rule matched with sufficient confidence", meta


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Select a bashqueues class for a cron command")
    ap.add_argument("--command", required=True, help="Cron command string")
    ap.add_argument("--user", default=os.environ.get("USER", ""), help="Cron user")
    ap.add_argument("--json", "-j", action="store_true", help="JSON output")
    ap.add_argument("--explain", action="store_true", help="Show all rule evaluations")
    ap.add_argument("--min-confidence", type=int, default=70, help="Minimum confidence threshold")
    ap.add_argument("--no-existence-check", action="store_true", help="Skip class file existence check")
    ap.add_argument("--tags", default=os.environ.get("QUEUEBASH_CRON_TAGS", ""), help="Comma-separated cron tags")
    ap.add_argument("--jurisdiction", default=os.environ.get("QUEUEBASH_CRON_JURISDICTION", ""), help="Legal/compliance jurisdiction")
    ap.add_argument("--classification", default=os.environ.get("QUEUEBASH_CRON_CLASSIFICATION", ""), help="Security classification")
    ap.add_argument("--cost-budget", default=os.environ.get("QUEUEBASH_CRON_COST_BUDGET", ""), help="Max price hint for FinOps routing")
    ap.add_argument("--fail-closed", action="store_true", default=os.environ.get("QUEUEBASH_CRON_SELECTOR_FAIL_CLOSED", "0").lower() in {"1", "yes", "true", "on"}, help="Return CRON_POLICY_BLOCKED when metadata cannot route")
    ns = ap.parse_args(argv)
    tags = _csv(ns.tags)

    if ns.explain:
        class_name, confidence, reason, meta = select_class(
            ns.command, ns.user, min_confidence=ns.min_confidence,
            require_class_exists=not ns.no_existence_check, tags=tags,
            jurisdiction=ns.jurisdiction, classification=ns.classification,
            cost_budget=ns.cost_budget, fail_closed=ns.fail_closed,
        )
        results = []
        for rule in RULES:
            matched = rule.matches(ns.command, {})
            exists = (ns.no_existence_check or _class_exists(rule.class_name, ns.user))
            results.append({"priority": rule.priority, "class": rule.class_name,
                            "confidence": rule.confidence, "reason": rule.reason,
                            "matched": matched, "class_exists": exists,
                            "would_select": bool(matched and rule.confidence >= ns.min_confidence and exists)})
        if ns.json:
            print(json.dumps({"command": ns.command, "user": ns.user,
                              "selected_class": class_name or "", "confidence": confidence,
                              "reason": reason, "governance": meta, "rules": results}, indent=2))
        else:
            print(f"Command: {ns.command}")
            print(f"User:    {ns.user}")
            if meta.get("jurisdiction") or meta.get("classification"):
                print(f"Governance: jurisdiction={meta.get('jurisdiction') or '-'} classification={meta.get('classification') or '-'}")
                print(f"Selected:   {class_name or '-'} confidence={confidence} reason={reason}")
            print()
            for r in results:
                marker = ">>> " if r["would_select"] else "    "
                tick = "✓" if r["matched"] else "✗"
                exist = "exists" if r["class_exists"] else "absent"
                print(f"{marker}[{tick}] p={r['priority']:3d} conf={r['confidence']:3d} class={r['class']:<30s} ({exist}) {r['reason'][:60]}")
        return 0

    class_name, confidence, reason, meta = select_class(
        ns.command, ns.user, min_confidence=ns.min_confidence,
        require_class_exists=not ns.no_existence_check, tags=tags,
        jurisdiction=ns.jurisdiction, classification=ns.classification,
        cost_budget=ns.cost_budget, fail_closed=ns.fail_closed,
    )
    if ns.json:
        print(json.dumps({"class": class_name or "", "confidence": confidence,
                          "reason": reason, "command": ns.command, "user": ns.user,
                          "governance": meta}))
    else:
        if class_name:
            print(class_name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
