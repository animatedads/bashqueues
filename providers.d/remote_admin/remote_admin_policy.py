#!/usr/bin/env python3
"""ACL-gated remote queue management policy editor.

This helper intentionally provides typed operations for the remote-management
policy files. It is not a shell and not a generic file editor.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import getpass
import hashlib
import hmac
import json
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile
from typing import Any, Dict, Iterable, List, Optional, Tuple

SCHEMA_PREFIX = "queuebash.remote_admin"
DEFAULT_ROOT = "/etc/bashqueues"
DEFAULT_AUDIT = "/var/log/queuebash/remote-queue-management-audit.jsonl"

READ_OPS = {
    ("validate", ""): "remote-admin.validate",
    ("config", "show"): "remote-admin.config.read",
    ("config", "get"): "remote-admin.config.read",
    ("client", "list"): "remote-admin.client.read",
    ("client", "show"): "remote-admin.client.read",
    ("acl", "list"): "remote-admin.acl.read",
    ("acl", "check"): "remote-admin.acl.read",
    ("secret", "list"): "remote-admin.secret.read-metadata",
    ("secret", "status"): "remote-admin.secret.read-metadata",
    ("secret", "verify"): "remote-admin.secret.read-metadata",
    ("audit", "tail"): "remote-admin.audit.read",
    ("audit", "show"): "remote-admin.audit.read",
    ("audit", "verify"): "remote-admin.audit.verify",
}
WRITE_OPS = {
    ("config", "set"): "remote-admin.config.write",
    ("config", "unset"): "remote-admin.config.write",
    ("client", "add"): "remote-admin.client.write",
    ("client", "set"): "remote-admin.client.write",
    ("client", "disable"): "remote-admin.client.write",
    ("acl", "grant"): "remote-admin.acl.write",
    ("acl", "deny"): "remote-admin.acl.write",
    ("acl", "revoke"): "remote-admin.acl.write",
    ("secret", "set"): "remote-admin.secret.write",
    ("secret", "rotate"): "remote-admin.secret.rotate",
    ("secret", "revoke"): "remote-admin.secret.write",
    ("audit", "note"): "remote-admin.audit.append",
}


def now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def emit(obj: Dict[str, Any], as_json: bool = True) -> int:
    if as_json:
        print(json.dumps(obj, sort_keys=True, separators=(",", ":")))
    else:
        print(obj.get("status", "unknown"))
    return int(obj.get("exit_code", 0))


def deny(message: str, operation: str = "", actor: str = "", resource: str = "*", as_json: bool = True, code: int = 1) -> int:
    return emit({
        "schema": f"{SCHEMA_PREFIX}.response.v1",
        "status": "denied",
        "decision": "deny",
        "reason": message,
        "operation": operation,
        "actor": actor,
        "resource": resource,
        "mutated": False,
        "exit_code": code,
    }, as_json)


class Paths:
    def __init__(self, root: str, audit_log: Optional[str] = None) -> None:
        self.root = Path(root)
        self.policy_dir = self.root / "policies.d" / "remote-queue"
        self.env = self.policy_dir / "remote-management.env"
        self.clients = self.policy_dir / "clients.tsv"
        self.acl = self.policy_dir / "acl.tsv"
        self.secrets_dir = self.policy_dir / "secrets"
        if audit_log:
            self.audit = Path(audit_log)
        elif root == DEFAULT_ROOT:
            self.audit = Path(DEFAULT_AUDIT)
        else:
            self.audit = self.root / "var" / "log" / "queuebash" / "remote-queue-management-audit.jsonl"


def safe_token(value: str, name: str) -> str:
    if not value or any(c in value for c in "\t\n\r"):
        raise ValueError(f"invalid {name}: tabs/newlines are not allowed")
    if "/" in value or value in (".", ".."):
        raise ValueError(f"invalid {name}: path separators are not allowed")
    return value


def read_env(path: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if "=" not in s:
            raise ValueError(f"invalid env line in {path}: {line!r}")
        k, v = s.split("=", 1)
        if not k or any(c in k for c in " \t\r\n"):
            raise ValueError(f"invalid env key in {path}: {k!r}")
        out[k] = v
    return out


def write_env(path: Path, data: Dict[str, str], dry_run: bool) -> bool:
    lines = ["# Managed by queue remote-admin; preserve comments in source control examples, not live generated output."]
    for k in sorted(data):
        lines.append(f"{k}={data[k]}")
    atomic_write(path, "\n".join(lines) + "\n", 0o640, dry_run)
    return not dry_run


def read_tsv(path: Path, columns: List[str]) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    if not path.exists():
        return rows
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < len(columns):
            raise ValueError(f"invalid TSV line {n} in {path}: expected {len(columns)} columns")
        row = {columns[i]: parts[i] for i in range(len(columns))}
        if len(parts) > len(columns):
            row[columns[-1]] = "\t".join(parts[len(columns)-1:])
        rows.append(row)
    return rows


def write_tsv(path: Path, columns: List[str], rows: List[Dict[str, str]], dry_run: bool, header: str = "") -> bool:
    lines = []
    if header:
        lines.extend(header.rstrip("\n").splitlines())
    for row in rows:
        lines.append("\t".join(str(row.get(c, "")) for c in columns))
    atomic_write(path, "\n".join(lines) + ("\n" if lines else ""), 0o640, dry_run)
    return not dry_run


def backup_path(path: Path) -> Path:
    ts = _dt.datetime.now(_dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return path.with_name(f"{path.name}.bak.{ts}")


def atomic_write(path: Path, text: str, mode: int, dry_run: bool) -> None:
    if dry_run:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        b = backup_path(path)
        shutil.copy2(path, b)
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        try:
            if os.path.exists(tmp):
                os.unlink(tmp)
        except OSError:
            pass


def append_jsonl(path: Path, event: Dict[str, Any], dry_run: bool) -> None:
    if dry_run:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, sort_keys=True, separators=(",", ":")) + "\n")
        f.flush()
        os.fsync(f.fileno())
    try:
        os.chmod(path, 0o640)
    except OSError:
        pass


def acl_rows(paths: Paths) -> List[Dict[str, str]]:
    return read_tsv(paths.acl, ["subject", "operation", "resource", "decision", "reason"])


def acl_decision(paths: Paths, actor: str, operation: str, resource: str = "*") -> Tuple[bool, str, Optional[Dict[str, str]]]:
    if not actor:
        return False, "missing_actor", None
    try:
        rows = acl_rows(paths)
    except Exception as e:
        return False, f"acl_parse_error:{e}", None
    matched_allow = None
    for row in rows:
        subj = row.get("subject", "")
        op = row.get("operation", "")
        res = row.get("resource", "") or "*"
        dec = row.get("decision", "").lower()
        if subj not in (actor, "*"):
            continue
        if op not in (operation, "*"):
            continue
        if res not in (resource, "*"):
            continue
        if dec == "deny":
            return False, row.get("reason", "explicit deny"), row
        if dec == "allow":
            matched_allow = row
    if matched_allow:
        return True, matched_allow.get("reason", "allowed"), matched_allow
    return False, "no_matching_remote_admin_acl_rule", None


def required_operation(area: str, action: str) -> str:
    return WRITE_OPS.get((area, action)) or READ_OPS.get((area, action)) or f"remote-admin.{area}.{action}"


def audit(paths: Paths, ns: argparse.Namespace, operation: str, resource: str, decision: str, status: str, detail: Dict[str, Any]) -> None:
    event = {
        "schema": f"{SCHEMA_PREFIX}.audit.v1",
        "ts": now_iso(),
        "actor": ns.actor,
        "operation": operation,
        "resource": resource,
        "decision": decision,
        "status": status,
        "ticket": ns.ticket or "",
        "reason": ns.reason or "",
        "dry_run": bool(ns.dry_run),
        "detail": detail,
    }
    append_jsonl(paths.audit, event, bool(ns.dry_run))


def require_acl(paths: Paths, ns: argparse.Namespace, operation: str, resource: str = "*") -> Tuple[bool, Dict[str, Any]]:
    ok, why, rule = acl_decision(paths, ns.actor, operation, resource)
    out = {"allowed": ok, "reason": why, "rule": rule}
    if not ok:
        audit(paths, ns, operation, resource, "deny", "denied", {"acl_reason": why})
    return ok, out


def success(ns: argparse.Namespace, schema: str, **kw: Any) -> int:
    obj = {"schema": schema, "status": "ok", "exit_code": 0}
    obj.update(kw)
    return emit(obj, ns.json)


def secret_path(paths: Paths, client_id: str) -> Path:
    safe_token(client_id, "client_id")
    return paths.secrets_dir / f"{client_id}.secret"


def secret_fingerprint(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:16]


def parse_common(argv: List[str]) -> Tuple[argparse.Namespace, List[str]]:
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("--root", default=DEFAULT_ROOT)
    p.add_argument("--audit-log", default=None)
    p.add_argument("--actor", default=os.environ.get("QUEUE_REMOTE_ADMIN_ACTOR", ""))
    p.add_argument("--json", action="store_true", default=False)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--reason", default="")
    p.add_argument("--ticket", default="")
    ns, rest = p.parse_known_args(argv)
    return ns, rest


def cmd_validate(paths: Paths, ns: argparse.Namespace, args: List[str]) -> int:
    op = "remote-admin.validate"
    ok, info = require_acl(paths, ns, op)
    if not ok:
        return deny(info["reason"], op, ns.actor, as_json=ns.json)
    checks = []
    errors = []
    for name, path in [("env", paths.env), ("clients", paths.clients), ("acl", paths.acl)]:
        exists = path.exists()
        checks.append({"name": name, "path": str(path), "exists": exists})
        if exists:
            try:
                if name == "env": read_env(path)
                elif name == "clients": read_tsv(path, ["client_id", "key_id", "subject", "secret_file", "status", "comment"])
                else: read_tsv(path, ["subject", "operation", "resource", "decision", "reason"])
            except Exception as e:
                errors.append({"name": name, "error": str(e)})
    status = "ok" if not errors else "invalid"
    audit(paths, ns, op, "*", "allow", status, {"errors": errors})
    return emit({"schema": f"{SCHEMA_PREFIX}.validate.v1", "status": status, "checks": checks, "errors": errors, "mutated": False, "exit_code": 0 if not errors else 1}, ns.json)


def cmd_config(paths: Paths, ns: argparse.Namespace, args: List[str]) -> int:
    action = args[0] if args else "show"
    op = required_operation("config", action)
    ok, info = require_acl(paths, ns, op)
    if not ok: return deny(info["reason"], op, ns.actor, as_json=ns.json)
    data = read_env(paths.env)
    mutated = False
    result: Dict[str, Any] = {}
    if action == "show":
        result = {"config": data}
    elif action == "get":
        key = args[1] if len(args) > 1 else ""
        if not key: return deny("config get requires KEY", op, ns.actor, as_json=ns.json, code=2)
        result = {"key": key, "value": data.get(key, ""), "found": key in data}
    elif action == "set":
        if len(args) < 3: return deny("config set requires KEY VALUE", op, ns.actor, as_json=ns.json, code=2)
        key, value = args[1], args[2]
        safe_token(key, "key")
        data[key] = value
        mutated = write_env(paths.env, data, ns.dry_run)
        result = {"key": key, "dry_run": ns.dry_run}
    elif action == "unset":
        if len(args) < 2: return deny("config unset requires KEY", op, ns.actor, as_json=ns.json, code=2)
        key = args[1]
        data.pop(key, None)
        mutated = write_env(paths.env, data, ns.dry_run)
        result = {"key": key, "dry_run": ns.dry_run}
    else:
        return deny(f"unknown config action: {action}", op, ns.actor, as_json=ns.json, code=2)
    audit(paths, ns, op, result.get("key", "*"), "allow", "ok", {"mutated": mutated})
    return success(ns, f"{SCHEMA_PREFIX}.config.v1", operation=op, mutated=mutated, **result)


def clients_columns() -> List[str]:
    return ["client_id", "key_id", "subject", "secret_file", "status", "comment"]


def cmd_client(paths: Paths, ns: argparse.Namespace, args: List[str]) -> int:
    action = args[0] if args else "list"
    op = required_operation("client", action)
    ok, info = require_acl(paths, ns, op)
    if not ok: return deny(info["reason"], op, ns.actor, as_json=ns.json)
    rows = read_tsv(paths.clients, clients_columns())
    mutated = False
    if action == "list":
        audit(paths, ns, op, "*", "allow", "ok", {"count": len(rows)})
        return success(ns, f"{SCHEMA_PREFIX}.client.v1", clients=rows, mutated=False)
    if len(args) < 2: return deny(f"client {action} requires CLIENT_ID", op, ns.actor, as_json=ns.json, code=2)
    cid = safe_token(args[1], "client_id")
    idx = next((i for i, r in enumerate(rows) if r.get("client_id") == cid), None)
    if action == "show":
        row = rows[idx] if idx is not None else None
        audit(paths, ns, op, cid, "allow", "ok", {"found": row is not None})
        return success(ns, f"{SCHEMA_PREFIX}.client.v1", client=row, found=row is not None, mutated=False)
    opts = dict(a.split("=", 1) for a in args[2:] if "=" in a)
    if action == "add":
        if idx is not None: return deny("client already exists", op, ns.actor, cid, ns.json)
        row = {
            "client_id": cid,
            "key_id": opts.get("key_id", "default"),
            "subject": opts.get("subject", cid),
            "secret_file": opts.get("secret_file", str(secret_path(paths, cid))),
            "status": opts.get("status", "active"),
            "comment": opts.get("comment", "managed by queue remote-admin"),
        }
        rows.append(row)
        mutated = write_tsv(paths.clients, clients_columns(), rows, ns.dry_run, "# client_id\tkey_id\tsubject\tsecret_file\tstatus\tcomment")
        result = {"client": row}
    elif action == "set":
        if idx is None: return deny("client not found", op, ns.actor, cid, ns.json)
        for k, v in opts.items():
            if k in clients_columns() and k != "client_id": rows[idx][k] = v
        mutated = write_tsv(paths.clients, clients_columns(), rows, ns.dry_run, "# client_id\tkey_id\tsubject\tsecret_file\tstatus\tcomment")
        result = {"client": rows[idx]}
    elif action == "disable":
        if idx is None: return deny("client not found", op, ns.actor, cid, ns.json)
        rows[idx]["status"] = "disabled"
        mutated = write_tsv(paths.clients, clients_columns(), rows, ns.dry_run, "# client_id\tkey_id\tsubject\tsecret_file\tstatus\tcomment")
        result = {"client": rows[idx]}
    else:
        return deny(f"unknown client action: {action}", op, ns.actor, as_json=ns.json, code=2)
    audit(paths, ns, op, cid, "allow", "ok", {"mutated": mutated, "dry_run": ns.dry_run})
    return success(ns, f"{SCHEMA_PREFIX}.client.v1", operation=op, mutated=mutated, dry_run=ns.dry_run, **result)


def acl_columns() -> List[str]:
    return ["subject", "operation", "resource", "decision", "reason"]


def cmd_acl(paths: Paths, ns: argparse.Namespace, args: List[str]) -> int:
    action = args[0] if args else "list"
    op = required_operation("acl", action)
    ok, info = require_acl(paths, ns, op)
    if not ok: return deny(info["reason"], op, ns.actor, as_json=ns.json)
    rows = read_tsv(paths.acl, acl_columns())
    mutated = False
    if action == "list":
        audit(paths, ns, op, "*", "allow", "ok", {"count": len(rows)})
        return success(ns, f"{SCHEMA_PREFIX}.acl.v1", rules=rows, mutated=False)
    if action == "check":
        if len(args) < 3: return deny("acl check requires SUBJECT OPERATION [RESOURCE]", op, ns.actor, as_json=ns.json, code=2)
        subj, chk_op = args[1], args[2]
        res = args[3] if len(args) > 3 else "*"
        allow, why, rule = acl_decision(paths, subj, chk_op, res)
        audit(paths, ns, op, res, "allow", "ok", {"checked_subject": subj, "checked_operation": chk_op, "decision": "allow" if allow else "deny"})
        return success(ns, f"{SCHEMA_PREFIX}.acl_check.v1", subject=subj, operation=chk_op, resource=res, decision="allow" if allow else "deny", reason=why, rule=rule, mutated=False)
    if len(args) < 4: return deny(f"acl {action} requires SUBJECT OPERATION RESOURCE", op, ns.actor, as_json=ns.json, code=2)
    subj, rule_op, resource = args[1], args[2], args[3]
    reason = " ".join(args[4:]) or ns.reason or f"managed {action}"
    if action in ("grant", "deny"):
        decision = "allow" if action == "grant" else "deny"
        rows.append({"subject": subj, "operation": rule_op, "resource": resource, "decision": decision, "reason": reason})
        mutated = write_tsv(paths.acl, acl_columns(), rows, ns.dry_run, "# subject\toperation\tresource\tdecision\treason")
        result = {"rule": rows[-1]}
    elif action == "revoke":
        before = len(rows)
        rows = [r for r in rows if not (r.get("subject") == subj and r.get("operation") == rule_op and r.get("resource") == resource)]
        mutated = write_tsv(paths.acl, acl_columns(), rows, ns.dry_run, "# subject\toperation\tresource\tdecision\treason")
        result = {"removed": before - len(rows)}
    else:
        return deny(f"unknown acl action: {action}", op, ns.actor, as_json=ns.json, code=2)
    audit(paths, ns, op, resource, "allow", "ok", {"mutated": mutated, "dry_run": ns.dry_run, **result})
    return success(ns, f"{SCHEMA_PREFIX}.acl.v1", operation=op, mutated=mutated, dry_run=ns.dry_run, **result)


def read_secret_stdin() -> bytes:
    data = sys.stdin.buffer.read()
    if data.endswith(b"\n"):
        data = data[:-1]
    if not data:
        raise ValueError("empty secret is not allowed")
    return data


def cmd_secret(paths: Paths, ns: argparse.Namespace, args: List[str]) -> int:
    action = args[0] if args else "list"
    op = required_operation("secret", action)
    ok, info = require_acl(paths, ns, op)
    if not ok: return deny(info["reason"], op, ns.actor, as_json=ns.json)
    mutated = False
    if action == "list":
        items = []
        if paths.secrets_dir.exists():
            for p in sorted(paths.secrets_dir.glob("*.secret")):
                st = p.stat()
                items.append({"client_id": p.stem, "path": str(p), "mode": oct(stat.S_IMODE(st.st_mode)), "size": st.st_size})
        audit(paths, ns, op, "*", "allow", "ok", {"count": len(items)})
        return success(ns, f"{SCHEMA_PREFIX}.secret.v1", secrets=items, mutated=False)
    if len(args) < 2: return deny(f"secret {action} requires CLIENT_ID", op, ns.actor, as_json=ns.json, code=2)
    cid = safe_token(args[1], "client_id")
    spath = secret_path(paths, cid)
    if action in ("set", "rotate"):
        data = read_secret_stdin()
        if not ns.dry_run:
            paths.secrets_dir.mkdir(parents=True, exist_ok=True)
            atomic_write(spath, data.decode("utf-8", "replace"), 0o600, False)
        mutated = not ns.dry_run
        result = {"client_id": cid, "fingerprint": secret_fingerprint(data), "dry_run": ns.dry_run}
    elif action == "revoke":
        if not ns.dry_run and spath.exists():
            b = backup_path(spath)
            shutil.move(str(spath), str(b))
            mutated = True
        result = {"client_id": cid, "dry_run": ns.dry_run}
    elif action == "status":
        result = {"client_id": cid, "exists": spath.exists()}
    elif action == "verify":
        data = read_secret_stdin()
        exists = spath.exists()
        stored = spath.read_bytes() if exists else b""
        ok_verify = exists and hmac.compare_digest(stored.rstrip(b"\n"), data)
        result = {"client_id": cid, "verified": ok_verify, "fingerprint": secret_fingerprint(data)}
    else:
        return deny(f"unknown secret action: {action}", op, ns.actor, as_json=ns.json, code=2)
    audit(paths, ns, op, cid, "allow", "ok", {"mutated": mutated, "secret_fingerprint": result.get("fingerprint", "")})
    return success(ns, f"{SCHEMA_PREFIX}.secret.v1", operation=op, mutated=mutated, **result)


def cmd_audit(paths: Paths, ns: argparse.Namespace, args: List[str]) -> int:
    action = args[0] if args else "tail"
    op = required_operation("audit", action)
    ok, info = require_acl(paths, ns, op)
    if not ok: return deny(info["reason"], op, ns.actor, as_json=ns.json)
    lines: List[Dict[str, Any]] = []
    if action in ("tail", "show", "verify"):
        raw = paths.audit.read_text(encoding="utf-8").splitlines() if paths.audit.exists() else []
        errors = []
        for i, line in enumerate(raw, 1):
            try:
                lines.append(json.loads(line))
            except Exception as e:
                errors.append({"line": i, "error": str(e)})
        if action == "tail": lines = lines[-20:]
        audit(paths, ns, op, "audit", "allow", "ok", {"count": len(lines), "errors": len(errors)})
        return success(ns, f"{SCHEMA_PREFIX}.audit_read.v1", entries=lines, errors=errors, verified=(not errors), mutated=False)
    if action == "note":
        text = " ".join(args[1:]) or ns.reason
        if not text: return deny("audit note requires text or --reason", op, ns.actor, as_json=ns.json, code=2)
        audit(paths, ns, op, "audit", "allow", "ok", {"note": text})
        return success(ns, f"{SCHEMA_PREFIX}.audit_note.v1", mutated=not ns.dry_run, dry_run=ns.dry_run)
    return deny(f"unknown audit action: {action}", op, ns.actor, as_json=ns.json, code=2)


def usage() -> str:
    return """queue remote-admin --actor ACTOR [--root DIR] [--json] COMMAND ...

Commands:
  validate
  config show|get KEY|set KEY VALUE|unset KEY
  client list|show ID|add ID key_id=K subject=S status=active|set ID key=value|disable ID
  acl list|check SUBJECT OPERATION [RESOURCE]|grant SUBJECT OPERATION RESOURCE [REASON]|deny ...|revoke ...
  secret list|status ID|set ID|rotate ID|revoke ID|verify ID   # set/rotate/verify read secret from stdin
  audit tail|show|verify|note TEXT
"""


def main(argv: List[str]) -> int:
    ns, rest = parse_common(argv)
    ns.json = bool(ns.json)
    if not rest or rest[0] in ("--help", "-h", "help"):
        print(usage())
        return 0
    paths = Paths(ns.root, ns.audit_log)
    area = rest[0]
    args = rest[1:]
    try:
        if area == "validate": return cmd_validate(paths, ns, args)
        if area == "config": return cmd_config(paths, ns, args)
        if area == "client": return cmd_client(paths, ns, args)
        if area == "acl": return cmd_acl(paths, ns, args)
        if area == "secret": return cmd_secret(paths, ns, args)
        if area == "audit": return cmd_audit(paths, ns, args)
        return deny(f"unknown command: {area}", as_json=ns.json, code=2)
    except Exception as e:
        return emit({"schema": f"{SCHEMA_PREFIX}.error.v1", "status": "error", "error": str(e), "mutated": False, "exit_code": 1}, ns.json)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
