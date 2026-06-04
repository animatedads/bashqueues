#!/usr/bin/env python3
"""Read-only remote queue management listener for bashqueues.

This is the server-side counterpart to ``queue remote``.  It accepts the
signed request schema produced by ``queue-remote-service-client.py`` and
executes only a fixed read-only operation registry.  It is intentionally not a
shell, not a generic command runner, and not a remote mutation API.
"""
from __future__ import print_function

import argparse
import base64
import datetime
import hashlib
import hmac
import json
import os
import re
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler
import socketserver
try:
    from http.server import ThreadingHTTPServer
except ImportError:  # pragma: no cover - Python 3 fallback
    from http.server import HTTPServer as ThreadingHTTPServer

REQ_SCHEMA = "queuebash.remote_queue_request.v1"
RESP_SCHEMA = "queuebash.remote_queue_service.v1"
LISTENER_SCHEMA = "queuebash.remote_queue_management_listener.v1"
DEFAULT_ENDPOINT = "/remote-queue"
DEFAULT_POLICY_FILE = "/etc/queuebash/policies.d/remote-queue/remote-management.env"
DEFAULT_CLIENTS_FILE = "/etc/queuebash/policies.d/remote-queue/clients.tsv"
DEFAULT_ACL_FILE = "/etc/queuebash/policies.d/remote-queue/acl.tsv"
DEFAULT_AUDIT_LOG = "/var/log/queuebash/remote-queue-management-audit.jsonl"
DEFAULT_STATE_DIR = "/var/lib/queuebash/remote-queue-management"

READONLY_OPERATIONS = {
    "health",
    "version",
    "capabilities",
    "queue.status",
    "queue.list",
    "job.explain",
    "job.tail",
    "worker.status",
    "service.ps",
}
DENIED_OPERATION_PREFIXES = ("run", "exec", "shell", "command", "cmd", "bash", "sh", "kill", "cancel")
CLIENT_ID_RE = re.compile(r"^[A-Za-z0-9_.@:-]{1,128}$")
KEY_ID_RE = re.compile(r"^[A-Za-z0-9_.@:-]{1,128}$")
OP_RE = re.compile(r"^[A-Za-z0-9_.:-]{1,128}$")
TARGET_RE = re.compile(r"^[A-Za-z0-9_.:@/+=,-]{0,256}$")
SECRET_KEYS = ("SECRET", "TOKEN", "AUTH", "KEY", "PASSWORD", "PASS", "PRIVATE")


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)


def iso_z(dt):
    return dt.isoformat().replace("+00:00", "Z")


def parse_time_z(value):
    if not value or not isinstance(value, str):
        raise ValueError("missing timestamp")
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.datetime.fromisoformat(value)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    return dt.astimezone(datetime.timezone.utc)


def json_escape_text(value, limit=4096):
    value = "" if value is None else str(value)
    if len(value) > limit:
        return value[-limit:]
    return value


def load_env_file(path):
    data = {}
    if not path or not os.path.exists(path):
        return data
    with open(path, "r") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
                value = value[1:-1]
            data[key] = value
    return data


def cfg_get(cfg, name, default=""):
    return os.environ.get(name) or cfg.get(name) or default


def truthy(value):
    return str(value).strip().lower() in ("1", "yes", "true", "on")


def canonical(req):
    fields = {
        "schema": req.get("schema", ""),
        "client_id": req.get("client_id", ""),
        "key_id": req.get("key_id", ""),
        "operation": req.get("operation", ""),
        "target": req.get("target", ""),
        "nonce": req.get("nonce", ""),
        "issued_at": req.get("issued_at", ""),
        "expires_at": req.get("expires_at", ""),
    }
    return json.dumps(fields, sort_keys=True, separators=(",", ":")).encode("utf-8")


def compute_signature(req, secret):
    digest = hmac.new(secret.encode("utf-8"), canonical(req), hashlib.sha256).digest()
    return "hmac-sha256:" + base64.b64encode(digest).decode("ascii")


def safe_mkdir(path, mode=0o755):
    if path:
        try:
            os.makedirs(path, mode=mode, exist_ok=True)
        except OSError:
            pass


def redact_dict(d):
    out = {}
    for k, v in d.items():
        if any(s in k.upper() for s in SECRET_KEYS):
            out[k] = "<redacted>"
        else:
            out[k] = v
    return out


class RemoteQueueListener(object):
    def __init__(self, cfg):
        self.cfg = cfg
        self.endpoint = cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_ENDPOINT", DEFAULT_ENDPOINT)
        if not self.endpoint.startswith("/"):
            self.endpoint = "/" + self.endpoint
        self.source = cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_QUEUEBASH_SOURCE", "/usr/local/share/bashqueues/queuebash.sh")
        self.queue_root = cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_QUEUE_ROOT", "/var/lib/queuebash/remote-queue-root")
        self.clients_file = cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_CLIENTS_FILE", DEFAULT_CLIENTS_FILE)
        self.acl_file = cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_ACL_FILE", DEFAULT_ACL_FILE)
        self.audit_log = cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_AUDIT_LOG", DEFAULT_AUDIT_LOG)
        self.state_dir = cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_STATE_DIR", DEFAULT_STATE_DIR)
        self.default_timeout = int(cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_MAX_RUNTIME_SECONDS", "20"))
        self.max_body = int(cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_MAX_BODY_BYTES", "65536"))
        self.max_stdout = int(cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_MAX_STDOUT_BYTES", "65536"))
        self.max_stderr = int(cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_MAX_STDERR_BYTES", "32768"))
        self.allow_loopback_only = truthy(cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_LOOPBACK_ONLY", "1"))
        self.replay_dir = os.path.join(self.state_dir, "nonces")
        safe_mkdir(os.path.dirname(self.audit_log))
        safe_mkdir(self.state_dir)
        safe_mkdir(self.replay_dir, 0o700)

    def response(self, req, status, decision, reason="", result=None, subject="", http_status=200):
        return http_status, {
            "schema": RESP_SCHEMA,
            "provider": "remote-queue-management-listener",
            "operation": req.get("operation", "") if isinstance(req, dict) else "",
            "target": req.get("target", "") if isinstance(req, dict) else "",
            "status": status,
            "decision": decision,
            "subject": subject,
            "reason": reason,
            "audit_event_id": self.audit(req, status, decision, reason, subject),
            "result": result or {},
        }

    def audit(self, req, status, decision, reason, subject):
        event_id = "RQ-%s-%s" % (utc_now().strftime("%Y%m%d%H%M%S"), hashlib.sha256((str(time.time()) + str(os.getpid()) + repr(req)).encode("utf-8")).hexdigest()[:12])
        event = {
            "schema": "queuebash.remote_queue_audit.v1",
            "event_id": event_id,
            "ts": iso_z(utc_now()),
            "provider": "remote-queue-management-listener",
            "client_id": req.get("client_id", "") if isinstance(req, dict) else "",
            "key_id": req.get("key_id", "") if isinstance(req, dict) else "",
            "subject": subject,
            "operation": req.get("operation", "") if isinstance(req, dict) else "",
            "target": req.get("target", "") if isinstance(req, dict) else "",
            "status": status,
            "decision": decision,
            "reason": reason,
        }
        try:
            with open(self.audit_log, "a") as f:
                f.write(json.dumps(event, sort_keys=True, separators=(",", ":")) + "\n")
        except Exception:
            pass
        return event_id

    def load_clients(self):
        clients = {}
        with open(self.clients_file, "r") as f:
            for lineno, raw in enumerate(f, 1):
                line = raw.rstrip("\n")
                if not line or line.lstrip().startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) < 5:
                    raise ValueError("client registry malformed at line %d" % lineno)
                client_id, key_id, subject, secret_file, status = [p.strip() for p in parts[:5]]
                if status not in ("active", "disabled"):
                    raise ValueError("client registry invalid status at line %d" % lineno)
                clients[(client_id, key_id)] = {"subject": subject, "secret_file": secret_file, "status": status, "line": lineno}
        return clients

    def read_secret_file(self, path):
        if not path or not os.path.exists(path):
            raise ValueError("secret file missing")
        st = os.stat(path)
        # World-readable HMAC secrets are a configuration error.  Group-readable
        # files are accepted so an operator can run the listener as a service user.
        if st.st_mode & 0o004:
            raise ValueError("secret file is world-readable")
        with open(path, "r") as f:
            return f.read().strip()

    def validate_request_shape(self, req):
        if not isinstance(req, dict):
            raise ValueError("request is not a JSON object")
        if req.get("schema") != REQ_SCHEMA:
            raise ValueError("bad schema")
        for key, rgx in (("client_id", CLIENT_ID_RE), ("key_id", KEY_ID_RE), ("operation", OP_RE)):
            value = req.get(key, "")
            if not isinstance(value, str) or not rgx.match(value):
                raise ValueError("invalid %s" % key)
        target = req.get("target", "")
        if not isinstance(target, str) or not TARGET_RE.match(target) or ".." in target:
            raise ValueError("invalid target")
        op = req.get("operation", "")
        if op.split(".")[0] in DENIED_OPERATION_PREFIXES:
            raise ValueError("operation denied by listener guard")
        if op not in READONLY_OPERATIONS:
            raise ValueError("operation not in listener allowlist")
        if not isinstance(req.get("nonce", ""), str) or len(req.get("nonce", "")) < 12:
            raise ValueError("invalid nonce")
        sig = req.get("signature", "")
        if not isinstance(sig, str) or not sig.startswith("hmac-sha256:"):
            raise ValueError("missing hmac signature")
        issued = parse_time_z(req.get("issued_at", ""))
        expires = parse_time_z(req.get("expires_at", ""))
        now = utc_now()
        if issued > now + datetime.timedelta(minutes=2):
            raise ValueError("request issued in the future")
        if expires < now:
            raise ValueError("request expired")
        if expires > issued + datetime.timedelta(minutes=10):
            raise ValueError("request ttl too long")

    def check_replay(self, req):
        key = hashlib.sha256((req.get("client_id", "") + "\n" + req.get("key_id", "") + "\n" + req.get("nonce", "")).encode("utf-8")).hexdigest()
        path = os.path.join(self.replay_dir, key)
        # Opportunistic cleanup of stale nonce markers.
        now = time.time()
        try:
            for name in os.listdir(self.replay_dir)[:200]:
                p = os.path.join(self.replay_dir, name)
                try:
                    if now - os.path.getmtime(p) > 900:
                        os.unlink(p)
                except OSError:
                    pass
        except OSError:
            pass
        flags = os.O_CREAT | os.O_EXCL | os.O_WRONLY
        try:
            fd = os.open(path, flags, 0o600)
            os.write(fd, b"seen\n")
            os.close(fd)
        except FileExistsError:
            raise ValueError("replay detected")

    def authenticate(self, req):
        clients = self.load_clients()
        row = clients.get((req.get("client_id", ""), req.get("key_id", "")))
        if not row:
            raise ValueError("client/key not registered")
        if row.get("status") != "active":
            raise ValueError("client/key disabled")
        secret = self.read_secret_file(row.get("secret_file"))
        expected = compute_signature(req, secret)
        if not hmac.compare_digest(expected, req.get("signature", "")):
            raise ValueError("bad signature")
        self.check_replay(req)
        return row.get("subject", req.get("client_id", ""))

    def acl_matches(self, pattern, value):
        return pattern == "*" or pattern == value

    def acl_check(self, subject, operation, target):
        if not os.path.exists(self.acl_file):
            return False, "acl_file_missing"
        best = None
        with open(self.acl_file, "r") as f:
            for lineno, raw in enumerate(f, 1):
                line = raw.rstrip("\n")
                if not line or line.lstrip().startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) < 5:
                    return False, "acl_file_malformed_line_%d" % lineno
                sub, op, resource, decision, reason = [p.strip() for p in parts[:5]]
                if decision not in ("allow", "deny"):
                    return False, "acl_file_malformed_line_%d" % lineno
                if self.acl_matches(sub, subject) and self.acl_matches(op, operation) and self.acl_matches(resource, target or "*"):
                    best = (decision, reason or ("matched line %d" % lineno))
        if not best:
            return False, "no_matching_remote_queue_acl_rule"
        return best[0] == "allow", best[1]

    def run_queue(self, args):
        if not os.path.exists(self.source):
            return {"exit_code": 127, "stdout": "", "stderr": "queuebash source not found: %s\n" % self.source, "duration_ms": 0}
        script = "set -euo pipefail; export QUEUEBASH_ALLOW_NONINTERACTIVE=1; export QUEUEBASH_ROOT=%s; source %s; queue \"$@\"" % (json.dumps(self.queue_root), json.dumps(self.source))
        start = time.time()
        proc = subprocess.Popen(["bash", "-lc", script, "queue"] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            out, err = proc.communicate(timeout=self.default_timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            out, err = proc.communicate()
            return {"exit_code": 124, "stdout": out.decode("utf-8", "replace")[-self.max_stdout:], "stderr": (err.decode("utf-8", "replace") + "\nremote queue operation timed out\n")[-self.max_stderr:], "duration_ms": int((time.time() - start) * 1000)}
        return {"exit_code": proc.returncode, "stdout": out.decode("utf-8", "replace")[-self.max_stdout:], "stderr": err.decode("utf-8", "replace")[-self.max_stderr:], "duration_ms": int((time.time() - start) * 1000)}

    def execute(self, req):
        op = req.get("operation", "")
        target = req.get("target", "")
        if op == "health":
            return {"exit_code": 0, "stdout": "", "stderr": "", "health": "ok", "listener_schema": LISTENER_SCHEMA}
        if op == "version":
            version = "unknown"
            try:
                with open(self.source, "r") as f:
                    for line in f:
                        if line.startswith("QUEUEBASH_VERSION="):
                            version = line.strip().split("=", 1)[1].strip('"')
                            break
            except Exception:
                pass
            return {"exit_code": 0, "stdout": version + "\n", "stderr": "", "version": version}
        if op == "capabilities":
            return {"exit_code": 0, "stdout": "", "stderr": "", "operations": sorted(READONLY_OPERATIONS), "mutating_operations_enabled": False}
        if op == "queue.status":
            return self.run_queue(["status"])
        if op == "queue.list":
            return self.run_queue(["list"])
        if op == "job.explain":
            if not target:
                return {"exit_code": 2, "stdout": "", "stderr": "job id required\n"}
            return self.run_queue(["explain", target])
        if op == "job.tail":
            if not target:
                return {"exit_code": 2, "stdout": "", "stderr": "job id required\n"}
            # ``tail`` is intentionally target-only; shell globbing/flags are not accepted.
            return self.run_queue(["tail", target])
        if op == "worker.status":
            return self.run_queue(["workers"])
        if op == "service.ps":
            # Bounded service status, not host-wide ps.  This uses the queue-owned worker view.
            return self.run_queue(["workers"])
        return {"exit_code": 2, "stdout": "", "stderr": "operation not implemented\n"}

    def handle_json(self, req):
        subject = ""
        try:
            self.validate_request_shape(req)
            subject = self.authenticate(req)
            allowed, reason = self.acl_check(subject, req.get("operation", ""), req.get("target", "") or "*")
            if not allowed:
                return self.response(req, "forbidden", "deny", reason, subject=subject, http_status=403)
            result = self.execute(req)
            status = "ok" if int(result.get("exit_code", 1)) == 0 else "error"
            return self.response(req, status, "allow", reason, result=result, subject=subject, http_status=200 if status == "ok" else 500)
        except Exception as exc:
            return self.response(req if isinstance(req, dict) else {}, "error", "deny", str(exc), subject=subject, http_status=403)


def make_handler(listener):
    class Handler(BaseHTTPRequestHandler):
        server_version = "bashqueues-remote-management/1"

        def log_message(self, fmt, *args):
            if truthy(listener.cfg.get("QUEUE_REMOTE_MANAGEMENT_ACCESS_LOG", "0")):
                BaseHTTPRequestHandler.log_message(self, fmt, *args)

        def send_json(self, code, obj):
            body = json.dumps(obj, sort_keys=True, separators=(",", ":")).encode("utf-8")
            self.close_connection = True
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)
            try:
                self.wfile.flush()
            except Exception:
                pass

        def do_GET(self):
            if self.path == "/healthz":
                self.send_json(200, {"schema": LISTENER_SCHEMA, "status": "ok", "endpoint": listener.endpoint})
                return
            self.send_json(404, {"schema": RESP_SCHEMA, "status": "error", "decision": "deny", "reason": "not_found"})

        def do_POST(self):
            if listener.allow_loopback_only and self.client_address[0] not in ("127.0.0.1", "::1"):
                self.send_json(403, {"schema": RESP_SCHEMA, "status": "forbidden", "decision": "deny", "reason": "loopback_only"})
                return
            if self.path != listener.endpoint:
                self.send_json(404, {"schema": RESP_SCHEMA, "status": "error", "decision": "deny", "reason": "not_found"})
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                length = 0
            if length <= 0 or length > listener.max_body:
                self.send_json(413, {"schema": RESP_SCHEMA, "status": "error", "decision": "deny", "reason": "invalid_body_length"})
                return
            raw = self.rfile.read(length)
            try:
                req = json.loads(raw.decode("utf-8"))
            except Exception:
                self.send_json(400, {"schema": RESP_SCHEMA, "status": "error", "decision": "deny", "reason": "invalid_json"})
                return
            code, obj = listener.handle_json(req)
            self.send_json(code, obj)
    return Handler


def main(argv):
    p = argparse.ArgumentParser(description="bashqueues remote queue management listener")
    p.add_argument("--config", default=os.environ.get("QUEUE_REMOTE_MANAGEMENT_POLICY", DEFAULT_POLICY_FILE))
    p.add_argument("--host", default=None)
    p.add_argument("--port", type=int, default=None)
    p.add_argument("--print-config", action="store_true")
    args = p.parse_args(argv)
    cfg = load_env_file(args.config)
    host = args.host or cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_HOST", "127.0.0.1")
    port = args.port or int(cfg_get(cfg, "QUEUE_REMOTE_MANAGEMENT_PORT", "8765"))
    listener = RemoteQueueListener(cfg)
    if args.print_config:
        print(json.dumps({"schema": LISTENER_SCHEMA, "config": redact_dict(cfg), "host": host, "port": port, "endpoint": listener.endpoint}, sort_keys=True))
        return 0
    # Ensure denial-path worker threads never keep the listener process alive
    # after tests/service managers ask it to stop, and allow immediate restart
    # during repeated smoke runs.
    try:
        ThreadingHTTPServer.daemon_threads = True
        ThreadingHTTPServer.allow_reuse_address = True
    except Exception:
        pass
    httpd = ThreadingHTTPServer((host, port), make_handler(listener))
    print("bashqueues remote queue management listener on %s:%s%s" % (host, port, listener.endpoint), file=sys.stderr)
    httpd.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
