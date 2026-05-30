#!/usr/bin/env python3
"""Capability-scoped remote queue service client for `queue remote`.

This client signs named remote queue operations and posts them to a configured
remote queue provider endpoint. It is deliberately not a shell client and it
must never route unknown commands to local or remote shell execution.
"""
from __future__ import print_function

import base64
import datetime
import hashlib
import hmac
import json
import os
import re
import secrets
import sys
import http.client
import socket
import urllib.error
import urllib.parse
import urllib.request

REQ_SCHEMA = "queuebash.remote_queue_request.v1"
CLIENT_SCHEMA = "queuebash.remote_queue_client.v1"
DEFAULT_ENDPOINT = "/remote-queue"

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

MUTATING_OR_SHELL_ALIASES = {
    "run", "exec", "shell", "command", "cmd", "bash", "sh", "kill", "cancel",
}

SECRET_KEYS = ("SECRET", "TOKEN", "AUTH", "KEY", "PASSWORD", "PASS", "PRIVATE")


def eprint(*args):
    print(*args, file=sys.stderr)


def utc_now():
    # Python 3.6-compatible UTC clock without datetime.utcnow() deprecation noise.
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None, microsecond=0)


def iso_z(dt):
    return dt.isoformat() + "Z"


def load_env_file(path):
    data = {}
    with open(path, "r") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
                value = value[1:-1]
            data[key] = value
    return data


def queue_root():
    return os.environ.get("QUEUEBASH_ROOT") or os.path.join(os.path.expanduser("~"), ".queuebash")


def service_dirs():
    dirs = []
    for key in ("QUEUE_REMOTE_CONFIG_DIR", "QUEUEBASH_REMOTE_CONFIG_DIR"):
        val = os.environ.get(key)
        if val:
            dirs.append(val)
    dirs.extend([
        os.path.join(queue_root(), "remote.d"),
        os.path.join(os.getcwd(), "remote.d"),
        "/etc/queuebash/policy/remote.d",
        "/etc/queuebash/policy/providers.d/remote.d",
        "/etc/queuebash/policy/providers.d",
    ])
    seen = []
    for d in dirs:
        if d and d not in seen:
            seen.append(d)
    return seen


def valid_service_name(name):
    return bool(re.match(r"^[A-Za-z0-9_.-]+$", name or ""))


def find_service_file(name):
    if not valid_service_name(name):
        raise SystemExit("queue remote: invalid service name: %s" % name)
    candidates = []
    for d in service_dirs():
        candidates.append(os.path.join(d, name + ".env"))
        candidates.append(os.path.join(d, "remote-" + name + ".env"))
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise SystemExit("queue remote: service config not found for %s; searched %s" % (name, ", ".join(service_dirs())))


def list_services(json_out):
    found = []
    for d in service_dirs():
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".env"):
                continue
            path = os.path.join(d, fn)
            try:
                cfg = load_env_file(path)
            except Exception:
                continue
            if cfg.get("QUEUE_REMOTE_URL") or cfg.get("REMOTE_QUEUE_URL") or cfg.get("QUEUE_REMOTE_SERVICE_URL"):
                name = cfg.get("QUEUE_REMOTE_SERVICE") or cfg.get("QUEUE_REMOTE_SERVICE_NAME") or fn[:-4]
                if name.startswith("remote-"):
                    name = name[len("remote-"):]
                found.append({"name": name, "path": path, "url": cfg.get("QUEUE_REMOTE_URL") or cfg.get("REMOTE_QUEUE_URL") or cfg.get("QUEUE_REMOTE_SERVICE_URL")})
    if json_out:
        print(json.dumps({"schema": CLIENT_SCHEMA, "operation": "list", "services": found}, sort_keys=True))
    else:
        if not found:
            print("No remote queue services configured.")
        for item in found:
            print("%s\t%s\t%s" % (item["name"], item["url"], item["path"]))


def redact_config(cfg):
    out = {}
    for k, v in sorted(cfg.items()):
        if any(s in k.upper() for s in SECRET_KEYS):
            out[k] = "<redacted>" if v else ""
        else:
            out[k] = v
    return out


def show_service(name, json_out):
    path = find_service_file(name)
    cfg = load_env_file(path)
    if json_out:
        print(json.dumps({"schema": CLIENT_SCHEMA, "operation": "show", "service": name, "path": path, "config": redact_config(cfg)}, sort_keys=True))
    else:
        print("service: %s" % name)
        print("path: %s" % path)
        for k, v in redact_config(cfg).items():
            print("%s=%s" % (k, v))


def cfg_get(cfg, *names):
    for name in names:
        if cfg.get(name):
            return cfg.get(name)
    return ""


def read_secret(cfg):
    direct = cfg_get(cfg, "QUEUE_REMOTE_SHARED_SECRET", "REMOTE_QUEUE_TEST_SECRET", "QUEUE_REMOTE_SECRET")
    if direct:
        return direct
    path = cfg_get(cfg, "QUEUE_REMOTE_SECRET_FILE", "REMOTE_QUEUE_SECRET_FILE")
    if path:
        with open(os.path.expanduser(path), "r") as f:
            return f.read().strip()
    env_name = cfg_get(cfg, "QUEUE_REMOTE_SECRET_ENV", "REMOTE_QUEUE_SECRET_ENV")
    if env_name:
        value = os.environ.get(env_name, "")
        if value:
            return value
    value = os.environ.get("REMOTE_QUEUE_TEST_SECRET", "")
    if value:
        return value
    raise SystemExit("queue remote: missing secret; set QUEUE_REMOTE_SECRET_FILE or QUEUE_REMOTE_SECRET_ENV in service config")


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


def sign_request(req, secret):
    digest = hmac.new(secret.encode("utf-8"), canonical(req), hashlib.sha256).digest()
    req["signature"] = "hmac-sha256:" + base64.b64encode(digest).decode("ascii")
    return req


def build_request(cfg, operation, target):
    now = utc_now()
    ttl = int(cfg_get(cfg, "QUEUE_REMOTE_REQUEST_TTL_SECONDS", "REMOTE_QUEUE_REQUEST_TTL_SECONDS") or "60")
    req = {
        "schema": REQ_SCHEMA,
        "client_id": cfg_get(cfg, "QUEUE_REMOTE_CLIENT_ID", "REMOTE_QUEUE_CLIENT_ID") or os.environ.get("USER", "queue-remote-client"),
        "key_id": cfg_get(cfg, "QUEUE_REMOTE_KEY_ID", "REMOTE_QUEUE_KEY_ID") or "default",
        "operation": operation,
        "target": target or "",
        "nonce": secrets.token_urlsafe(18),
        "issued_at": iso_z(now),
        "expires_at": iso_z(now + datetime.timedelta(seconds=ttl)),
    }
    return sign_request(req, read_secret(cfg))


def read_response_body(resp, limit=1048576):
    try:
        length = resp.headers.get("Content-Length")
    except Exception:
        length = None
    if length:
        try:
            size = max(0, min(int(length), limit))
            return resp.read(size).decode("utf-8", "replace")
        except Exception:
            pass
    return resp.read(limit).decode("utf-8", "replace")


def client_error_response(obj, reason):
    err = {
        "schema": CLIENT_SCHEMA,
        "operation": obj.get("operation", "") if isinstance(obj, dict) else "",
        "status": "error",
        "decision": "deny",
        "reason": "remote_http_request_failed: %s" % reason,
    }
    return 599, json.dumps(err, sort_keys=True)


def read_http_client_body(resp, limit=1048576):
    length = resp.getheader("Content-Length")
    if length:
        try:
            size = max(0, min(int(length), limit))
            return resp.read(size).decode("utf-8", "replace")
        except Exception:
            return ""
    chunks = []
    remaining = limit
    while remaining > 0:
        chunk = resp.read(min(65536, remaining))
        if not chunk:
            break
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks).decode("utf-8", "replace")


def post_json(url, obj, timeout):
    # Use http.client rather than urllib.urlopen so HTTP denial responses are
    # read with an explicit close and bounded body.  urllib's HTTPError body
    # handling has proven too easy to wedge in denial-path smoke tests.
    body = json.dumps(obj, separators=(",", ":")).encode("utf-8")
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        return client_error_response(obj, "invalid remote URL")
    path = urllib.parse.urlunparse(("", "", parsed.path or "/", parsed.params, parsed.query, ""))
    conn_cls = http.client.HTTPSConnection if parsed.scheme == "https" else http.client.HTTPConnection
    conn = None
    try:
        conn = conn_cls(parsed.netloc, timeout=timeout)
        conn.request("POST", path, body=body, headers={
            "Content-Type": "application/json",
            "Content-Length": str(len(body)),
            "Connection": "close",
        })
        resp = conn.getresponse()
        data = read_http_client_body(resp)
        return resp.status, data
    except Exception as e:
        return client_error_response(obj, e)
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass


def operation_from_args(args):
    if not args:
        raise SystemExit("queue remote: missing remote command; try queue remote help")
    a0 = args[0]
    rest = args[1:]
    if a0 in MUTATING_OR_SHELL_ALIASES:
        raise SystemExit("queue remote: operation is not exposed by the read-only client surface: %s" % a0)
    if a0 in ("health", "version", "capabilities"):
        return a0, ""
    if a0 == "queue":
        if not rest:
            raise SystemExit("queue remote: queue requires status|list")
        sub = rest[0]
        if sub in ("status", "list"):
            return "queue." + sub, ""
        raise SystemExit("queue remote: unsupported queue operation: %s" % sub)
    if a0 == "job":
        if len(rest) < 2 or rest[0] not in ("explain", "tail"):
            raise SystemExit("queue remote: usage: queue remote SERVICE job explain|tail JOBID")
        return "job." + rest[0], rest[1]
    if a0 == "worker":
        if rest and rest[0] == "status":
            return "worker.status", ""
        raise SystemExit("queue remote: usage: queue remote SERVICE worker status")
    if a0 == "service":
        if rest and rest[0] == "ps":
            return "service.ps", ""
        raise SystemExit("queue remote: usage: queue remote SERVICE service ps")
    if a0 == "raw":
        if not rest:
            raise SystemExit("queue remote: raw requires an operation name")
        op = rest[0]
        if op.split(".")[0] in MUTATING_OR_SHELL_ALIASES:
            raise SystemExit("queue remote: raw operation denied by client guard: %s" % op)
        target = rest[1] if len(rest) > 1 else ""
        return op, target
    if a0 in READONLY_OPERATIONS:
        target = rest[0] if rest else ""
        return a0, target
    raise SystemExit("queue remote: unknown operation: %s" % a0)


def format_response(data, json_out):
    if json_out:
        print(json.dumps(data, sort_keys=True))
        return
    print("remote operation: %s" % data.get("operation", ""))
    print("status: %s" % data.get("status", ""))
    if data.get("decision"):
        print("decision: %s" % data.get("decision"))
    if data.get("reason"):
        print("reason: %s" % data.get("reason"))
    result = data.get("result")
    if isinstance(result, dict):
        if "stdout" in result and result.get("stdout"):
            print("\n--- stdout ---")
            print(result.get("stdout"), end="" if result.get("stdout", "").endswith("\n") else "\n")
        if "stderr" in result and result.get("stderr"):
            print("\n--- stderr ---")
            print(result.get("stderr"), end="" if result.get("stderr", "").endswith("\n") else "\n")
        other = dict((k, v) for k, v in result.items() if k not in ("stdout", "stderr"))
        if other:
            print("\n--- result ---")
            print(json.dumps(other, sort_keys=True, indent=2))
    else:
        print(json.dumps(data, sort_keys=True, indent=2))


def usage():
    print("""Usage:
  queue remote list [--json]
  queue remote show SERVICE [--json]
  queue remote SERVICE health [--json]
  queue remote SERVICE version [--json]
  queue remote SERVICE capabilities [--json]
  queue remote SERVICE queue status|list [--json]
  queue remote SERVICE job explain|tail JOBID [--json]
  queue remote SERVICE worker status [--json]
  queue remote SERVICE service ps [--json]
  queue remote SERVICE raw OPERATION [TARGET] [--json]

Configuration:
  SERVICE is loaded from remote.d/SERVICE.env under QUEUE_REMOTE_CONFIG_DIR,
  QUEUEBASH_ROOT, the current tree, or /etc/queuebash/policy/remote.d.

This client sends signed named operations only. It does not expose a shell.
""")


def main(argv):
    json_out = False
    args = []
    for a in argv:
        if a in ("--json", "-j"):
            json_out = True
        elif a in ("--help", "-h", "help") and not args:
            usage()
            return 0
        else:
            args.append(a)
    if not args:
        usage()
        return 2
    if args[0] == "list":
        list_services(json_out)
        return 0
    if args[0] == "show":
        if len(args) < 2:
            raise SystemExit("queue remote show: missing service name")
        show_service(args[1], json_out)
        return 0

    service = args[0]
    cfg_path = find_service_file(service)
    cfg = load_env_file(cfg_path)
    url = cfg_get(cfg, "QUEUE_REMOTE_URL", "REMOTE_QUEUE_URL", "QUEUE_REMOTE_SERVICE_URL")
    if not url:
        raise SystemExit("queue remote: service %s missing QUEUE_REMOTE_URL" % service)
    endpoint = cfg_get(cfg, "QUEUE_REMOTE_ENDPOINT", "QUEUE_REMOTE_ENDPOINT_PATH") or DEFAULT_ENDPOINT
    if not endpoint.startswith("/"):
        endpoint = "/" + endpoint
    full_url = url.rstrip("/") + endpoint
    timeout = int(cfg_get(cfg, "QUEUE_REMOTE_HTTP_TIMEOUT_SECONDS", "REMOTE_QUEUE_HTTP_TIMEOUT_SECONDS") or "30")

    operation, target = operation_from_args(args[1:])
    if operation not in READONLY_OPERATIONS and not cfg_get(cfg, "QUEUE_REMOTE_ALLOW_RAW_OPERATIONS") == "1":
        raise SystemExit("queue remote: operation not in client allowlist: %s" % operation)
    req = build_request(cfg, operation, target)
    code, text = post_json(full_url, req, timeout)
    try:
        data = json.loads(text)
    except Exception:
        data = {"schema": CLIENT_SCHEMA, "operation": operation, "status": "error", "http_status": code, "body_tail": text[-4096:]}
    format_response(data, json_out)
    status = data.get("status")
    if code >= 400 or status in ("forbidden", "error"):
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except SystemExit:
        raise
    except Exception as exc:
        eprint("queue remote: %s" % exc)
        sys.exit(1)
