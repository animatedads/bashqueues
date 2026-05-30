#!/usr/bin/env python3
# queue-dev-runner.py - capability-scoped bashqueues remote dev runner
# Python compatibility target: 3.6+. Do not use future annotations/dataclasses.

import argparse
import base64
import datetime
import errno
import json
import os
import posixpath
import random
import re
import secrets
import shutil
import signal
import stat
import string
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn

SCHEMA = "queuebash.dev_remote_runner.v1"
DEFAULT_TTL_SECONDS = 1800
DEFAULT_BOOTSTRAP_TTL_SECONDS = 300
DEFAULT_MAX_UPLOAD_BYTES = 10 * 1024 * 1024
DEFAULT_MAX_LOG_BYTES = 8192
DEFAULT_RUNTIME_SECONDS = 120
SAFE_NAME_RE = re.compile(r"^[A-Za-z0-9._/@:+-]+$")
SECRET_PATTERNS = [
    re.compile(r"(Authorization:\s*Bearer\s+)[^\s]+", re.I),
    re.compile(r"(auth[_-]?code[\"'=:\s]+)[A-Za-z0-9._~+/=-]+", re.I),
    re.compile(r"(bootstrap[_-]?code[\"'=:\s]+)[A-Za-z0-9._~+/=-]+", re.I),
    re.compile(r"(token[\"'=:\s]+)[A-Za-z0-9._~+/=-]+", re.I),
    re.compile(r"(api[_-]?key[\"'=:\s]+)[A-Za-z0-9._~+/=-]+", re.I),
    re.compile(r"(private[_-]?key[\"'=:\s]+)[A-Za-z0-9._~+/=-]+", re.I),
]

APPROVED_TESTS = {
    "bash_n_queuebash": ["bash", "-n", "queuebash.sh"],
    "dev_remote_runner_static": ["bash", "tests/dev_remote_runner_static.sh"],
    "dev_remote_runner_json": ["python3", "tests/dev_remote_runner_json_contract_static.py"],
    "dev_remote_runner_smoke": ["python3", "tests/dev_remote_runner_smoke.py"],
    "dev_scratchpad_static": ["bash", "tests/dev_scratchpad_static.sh"],
    "dev_scratchpad_smoke": ["bash", "tests/dev_scratchpad_smoke.sh"],
    "dev_scratchpad_json": ["python3", "tests/dev_scratchpad_json_contract_static.py"],
    "dev_test_runner_static": ["bash", "tests/dev_test_runner_class_static.sh"],
    "dev_test_runner_smoke": ["bash", "tests/dev_test_runner_class_smoke.sh"],
    "dev_test_runner_json": ["python3", "tests/dev_test_runner_json_contract_static.py"],
    "sleepy": ["bash", "tests/sleepy.sh", "30"],
}


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def utc_from_epoch(epoch):
    return datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def make_code(prefix):
    alphabet = string.ascii_letters + string.digits
    return prefix + "_" + "".join(secrets.choice(alphabet) for _ in range(32))


def redact(text):
    if text is None:
        return ""
    if not isinstance(text, str):
        try:
            text = text.decode("utf-8", "replace")
        except Exception:
            text = str(text)
    for pat in SECRET_PATTERNS:
        text = pat.sub(lambda m: m.group(1) + "[REDACTED]", text)
    return text


def tail_text(text, limit):
    text = redact(text)
    if len(text.encode("utf-8", "replace")) <= limit:
        return text
    encoded = text.encode("utf-8", "replace")[-limit:]
    return "[tail-truncated]\n" + encoded.decode("utf-8", "replace")


def json_response(handler, code, payload):
    body = json.dumps(payload, sort_keys=True).encode("utf-8")
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def error_payload(operation, error, message):
    return {
        "schema": SCHEMA,
        "operation": operation,
        "status": "error",
        "error": error,
        "message": message,
        "generated_at": utc_now(),
    }


def ok_payload(operation, **extra):
    payload = {
        "schema": SCHEMA,
        "operation": operation,
        "status": "ok",
        "generated_at": utc_now(),
    }
    payload.update(extra)
    return payload


def safe_join(root, relpath):
    if relpath is None or relpath == "":
        raise ValueError("missing path")
    if "\x00" in relpath:
        raise ValueError("path contains NUL")
    relpath = relpath.replace("\\", "/")
    if relpath.startswith("/"):
        raise ValueError("absolute paths are not allowed")
    norm = posixpath.normpath(relpath)
    if norm == "." or norm.startswith("../") or norm == "..":
        raise ValueError("path traversal is not allowed")
    parts = norm.split("/")
    for part in parts:
        if part in ("", ".", ".."):
            raise ValueError("unsafe path component")
    dest = os.path.realpath(os.path.join(root, *parts))
    real_root = os.path.realpath(root)
    if dest != real_root and not dest.startswith(real_root + os.sep):
        raise ValueError("path escapes workspace")
    return dest


def ensure_parent_no_symlink_escape(root, path):
    real_root = os.path.realpath(root)
    cur = real_root
    rel = os.path.relpath(os.path.dirname(path), real_root)
    if rel == ".":
        return
    for part in rel.split(os.sep):
        cur = os.path.join(cur, part)
        if os.path.lexists(cur) and os.path.islink(cur):
            raise ValueError("symlink escape is not allowed")
    real_parent = os.path.realpath(os.path.dirname(path))
    if real_parent != real_root and not real_parent.startswith(real_root + os.sep):
        raise ValueError("parent escapes workspace")


class SessionStore(object):
    def __init__(self, repo, work_root, ttl_seconds, bootstrap_ttl_seconds, execution_user,
                 create_execution_user, visible_console, max_log_bytes, runtime_seconds):
        self.repo = os.path.realpath(repo)
        self.work_root = os.path.realpath(work_root)
        self.ttl_seconds = int(ttl_seconds)
        self.bootstrap_ttl_seconds = int(bootstrap_ttl_seconds)
        self.execution_user = execution_user
        self.create_execution_user = bool(create_execution_user)
        self.visible_console = bool(visible_console)
        self.max_log_bytes = int(max_log_bytes)
        self.runtime_seconds = int(runtime_seconds)
        self.bootstrap = {}
        self.sessions = {}
        self.lock = threading.RLock()
        if not os.path.isdir(self.repo):
            raise RuntimeError("repo directory does not exist: %s" % self.repo)
        if not os.path.isdir(self.work_root):
            os.makedirs(self.work_root)

    def console(self, message):
        if self.visible_console:
            sys.stdout.write("%s %s\n" % (utc_now(), message))
            sys.stdout.flush()

    def mint_bootstrap(self, reason):
        code = make_code("BQBOOT")
        expires_at = time.time() + self.bootstrap_ttl_seconds
        with self.lock:
            self.bootstrap[code] = {"expires_at": expires_at, "created_at": time.time(), "used": False}
        self.console("BOOTSTRAP_CODE=%s EXPIRES_AT=%s REASON=%s" % (
            code,
            utc_from_epoch(expires_at),
            reason,
        ))
        return code

    def consume_bootstrap(self, code):
        now = time.time()
        with self.lock:
            row = self.bootstrap.get(code)
            if not row:
                return False, "invalid bootstrap code"
            if row.get("used"):
                return False, "bootstrap code already used"
            if row.get("expires_at", 0) < now:
                return False, "bootstrap code expired"
            row["used"] = True
            return True, "ok"

    def create_session(self, bootstrap_code, client_addr):
        valid, reason = self.consume_bootstrap(bootstrap_code)
        if not valid:
            self.console("SESSION_CREATE_REJECT client=%s reason=%s" % (client_addr, reason))
            return None, reason
        sid = make_code("BQSID")
        auth = make_code("BQAUTH")
        workspace = os.path.join(self.work_root, sid)
        os.makedirs(workspace)
        os.makedirs(os.path.join(workspace, "uploads"))
        os.makedirs(os.path.join(workspace, "logs"))
        os.makedirs(os.path.join(workspace, "results"))
        expires_at = time.time() + self.ttl_seconds
        session = {
            "session_id": sid,
            "auth_code": auth,
            "workspace": workspace,
            "created_at": time.time(),
            "expires_at": expires_at,
            "closed": False,
            "client_addr": client_addr,
            "results": {},
            "processes": {},
            "next_process_seq": 1,
        }
        with self.lock:
            self.sessions[sid] = session
        self._prepare_workspace_for_execution_user(workspace)
        self.console("SESSION_CREATED session=%s client=%s workspace=%s expires_at=%s" % (
            sid, client_addr, workspace,
            utc_from_epoch(expires_at)
        ))
        return session, "ok"

    def _prepare_workspace_for_execution_user(self, workspace):
        if not self.execution_user:
            return
        if self.create_execution_user:
            self._ensure_execution_user()
        if os.geteuid() == 0:
            try:
                import pwd
                pw = pwd.getpwnam(self.execution_user)
                for dirpath, dirnames, filenames in os.walk(workspace):
                    os.chown(dirpath, pw.pw_uid, pw.pw_gid)
                    for name in filenames:
                        try:
                            os.chown(os.path.join(dirpath, name), pw.pw_uid, pw.pw_gid)
                        except OSError:
                            pass
            except Exception as exc:
                self.console("WARN workspace chown failed: %s" % exc)

    def _ensure_execution_user(self):
        if not self.execution_user:
            return
        try:
            subprocess.check_call(["id", "-u", self.execution_user], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            if os.geteuid() != 0:
                raise RuntimeError("execution user %s missing and runner is not root" % self.execution_user)
            shell = "/usr/sbin/nologin" if os.path.exists("/usr/sbin/nologin") else "/sbin/nologin"
            subprocess.check_call(["useradd", "--create-home", "--shell", shell, self.execution_user])
            subprocess.call(["passwd", "-l", self.execution_user], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            groups = subprocess.check_output(["id", "-nG", self.execution_user], stderr=subprocess.DEVNULL).decode("utf-8", "replace").split()
            for bad in ("sudo", "wheel", "admin"):
                if bad in groups:
                    raise RuntimeError("execution user %s is in privileged group %s" % (self.execution_user, bad))
        except subprocess.CalledProcessError:
            raise RuntimeError("cannot inspect execution user groups")

    def get_session(self, sid, auth):
        now = time.time()
        with self.lock:
            session = self.sessions.get(sid)
            if not session:
                return None, "missing or invalid session id"
            if session.get("closed"):
                return None, "session is closed"
            if session.get("expires_at", 0) < now:
                session["closed"] = True
                return None, "session expired"
            if not auth or auth != session.get("auth_code"):
                return None, "missing or invalid auth code"
            return session, "ok"

    def close_session(self, session, cleanup):
        with self.lock:
            session["closed"] = True
        workspace = session["workspace"]
        if cleanup:
            try:
                shutil.rmtree(workspace)
            except Exception as exc:
                self.console("WARN cleanup failed session=%s error=%s" % (session["session_id"], exc))
        self.console("SESSION_CLOSED session=%s cleanup=%s" % (session["session_id"], str(bool(cleanup)).lower()))

    def _next_process_id(self, session):
        with self.lock:
            seq = int(session.get("next_process_seq", 1))
            session["next_process_seq"] = seq + 1
        return "BQPROC_%s_%06d" % (session["session_id"].split("_", 1)[-1][:8], seq)

    def _register_process(self, session, operation, popen_obj, stdout_path, stderr_path, cmd, started_at):
        process_id = self._next_process_id(session)
        row = {
            "process_id": process_id,
            "operation": operation,
            "pid": int(popen_obj.pid),
            "pgid": None,
            "command": list(cmd),
            "stdout_path": stdout_path,
            "stderr_path": stderr_path,
            "started_at": started_at,
            "finished_at": None,
            "exit_code": None,
            "status": "running",
        }
        try:
            row["pgid"] = int(os.getpgid(popen_obj.pid))
        except Exception:
            row["pgid"] = int(popen_obj.pid)
        with self.lock:
            session.setdefault("processes", {})[process_id] = row
        self.console("PROCESS_REGISTER session=%s process_id=%s pid=%s pgid=%s operation=%s" % (
            session["session_id"], process_id, row["pid"], row["pgid"], operation
        ))
        return process_id

    def _finish_process(self, session, process_id, exit_code, status):
        with self.lock:
            row = session.setdefault("processes", {}).get(process_id)
            if row:
                row["finished_at"] = utc_now()
                row["exit_code"] = exit_code
                row["status"] = status

    def list_session_processes(self, session):
        with self.lock:
            rows = [dict(v) for v in session.setdefault("processes", {}).values()]
        out = []
        for row in rows:
            alive = False
            pid = row.get("pid")
            if row.get("status") == "running" and pid:
                try:
                    os.kill(int(pid), 0)
                    alive = True
                except OSError as exc:
                    if exc.errno == errno.EPERM:
                        alive = True
                    else:
                        alive = False
                except Exception:
                    alive = False
                if not alive:
                    row["status"] = "finished_or_missing"
            safe = {
                "process_id": row.get("process_id"),
                "operation": row.get("operation"),
                "pid": row.get("pid"),
                "pgid": row.get("pgid"),
                "status": row.get("status"),
                "alive": bool(alive),
                "started_at": row.get("started_at"),
                "finished_at": row.get("finished_at"),
                "exit_code": row.get("exit_code"),
            }
            out.append(safe)
        return out

    def kill_session_process(self, session, process_id=None, pid=None, signal_name="TERM"):
        if not process_id and not pid:
            return False, "missing_process", "process_id is required; raw pid is accepted only when it matches this session registry"
        with self.lock:
            rows = session.setdefault("processes", {})
            row = None
            if process_id:
                row = rows.get(process_id)
            elif pid is not None:
                for candidate in rows.values():
                    if int(candidate.get("pid", -1)) == int(pid):
                        row = candidate
                        break
        if not row:
            return False, "not_session_process", "process does not belong to this session registry"
        if row.get("status") not in ("running", "timeout"):
            return False, "not_running", "process is not running"
        sig = signal.SIGTERM
        if str(signal_name).upper() in ("KILL", "SIGKILL", "9"):
            sig = signal.SIGKILL
        elif str(signal_name).upper() not in ("TERM", "SIGTERM", "15"):
            return False, "bad_signal", "only TERM or KILL are allowed"
        target_pgid = row.get("pgid") or row.get("pid")
        try:
            os.killpg(int(target_pgid), sig)
        except ProcessLookupError:
            with self.lock:
                row["status"] = "finished_or_missing"
                row["finished_at"] = utc_now()
            return False, "not_running", "process group no longer exists"
        except Exception as exc:
            return False, "kill_failed", str(exc)
        with self.lock:
            row["status"] = "killed"
            row["finished_at"] = utc_now()
        self.console("PROCESS_KILL session=%s process_id=%s pid=%s pgid=%s signal=%s" % (
            session["session_id"], row.get("process_id"), row.get("pid"), row.get("pgid"), sig
        ))
        return True, "ok", "killed"

    def run_approved(self, session, operation, args, runtime_seconds=None, wait=True):
        if runtime_seconds is None:
            runtime_seconds = self.runtime_seconds
        runtime_seconds = int(runtime_seconds)
        if runtime_seconds <= 0 or runtime_seconds > 3600:
            raise ValueError("runtime_seconds out of range")
        workspace = session["workspace"]
        log_id = "%s_%s" % (operation, str(int(time.time() * 1000)))
        stdout_path = os.path.join(workspace, "logs", log_id + ".stdout")
        stderr_path = os.path.join(workspace, "logs", log_id + ".stderr")
        env = {
            "PATH": "/usr/local/bin:/usr/bin:/bin",
            "HOME": workspace,
            "QUEUEBASH_ALLOW_NONINTERACTIVE": "1",
            "QUEUEBASH_ROOT": os.path.join(workspace, ".queuebash"),
            "LC_ALL": "C",
        }
        cmd = list(args)
        display_cmd = " ".join(cmd)
        self.console("API_COMMAND_START session=%s operation=%s cwd=%s user=%s command=%s" % (
            session["session_id"], operation, self.repo, self.execution_user or os.environ.get("USER", "current"), display_cmd
        ))
        start = time.time()
        exit_code = None
        timed_out = False
        with open(stdout_path, "wb") as out, open(stderr_path, "wb") as err:
            try:
                run_args = self._wrap_for_execution_user(cmd, env)
                proc = subprocess.Popen(run_args, cwd=self.repo, env=env if not self._needs_privilege_wrapper() else None,
                                        stdout=out, stderr=err, preexec_fn=os.setsid)
                process_id = self._register_process(session, operation, proc, stdout_path, stderr_path, cmd, utc_now())
                if not wait:
                    result = {
                        "schema": SCHEMA,
                        "operation": operation,
                        "status": "started",
                        "session_id": session["session_id"],
                        "process_id": process_id,
                        "pid": int(proc.pid),
                        "pgid": int(os.getpgid(proc.pid)),
                        "duration_seconds": round(time.time() - start, 3),
                        "artifact_paths": [
                            os.path.relpath(stdout_path, workspace),
                            os.path.relpath(stderr_path, workspace),
                        ],
                        "generated_at": utc_now(),
                    }
                    with self.lock:
                        session["results"][log_id] = result
                    self.console("API_COMMAND_STARTED session=%s operation=%s process_id=%s pid=%s" % (
                        session["session_id"], operation, process_id, proc.pid
                    ))
                    return result
                try:
                    exit_code = proc.wait(timeout=runtime_seconds)
                except subprocess.TimeoutExpired:
                    timed_out = True
                    try:
                        os.killpg(proc.pid, signal.SIGTERM)
                    except Exception:
                        proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except Exception:
                        try:
                            os.killpg(proc.pid, signal.SIGKILL)
                        except Exception:
                            proc.kill()
                        proc.wait()
                    exit_code = 124
                try:
                    self._finish_process(session, process_id, exit_code, "timeout" if timed_out else ("pass" if exit_code == 0 else "fail"))
                except Exception:
                    pass
            except Exception as exc:
                err.write(("runner execution error: %s\n" % exc).encode("utf-8", "replace"))
                exit_code = 126
        duration = time.time() - start
        stdout_tail = self._read_tail(stdout_path)
        stderr_tail = self._read_tail(stderr_path)
        status = "timeout" if timed_out else ("pass" if exit_code == 0 else "fail")
        result = {
            "schema": SCHEMA,
            "operation": operation,
            "status": status,
            "session_id": session["session_id"],
            "exit_code": exit_code,
            "duration_seconds": round(duration, 3),
            "stdout_tail": stdout_tail,
            "stderr_tail": stderr_tail,
            "artifact_paths": [
                os.path.relpath(stdout_path, workspace),
                os.path.relpath(stderr_path, workspace),
            ],
            "generated_at": utc_now(),
        }
        with self.lock:
            session["results"][log_id] = result
        self.console("API_COMMAND_END session=%s operation=%s status=%s exit_code=%s duration=%.3f" % (
            session["session_id"], operation, status, exit_code, duration
        ))
        if stdout_tail.strip():
            self.console("API_COMMAND_STDOUT_TAIL session=%s operation=%s\n%s" % (session["session_id"], operation, stdout_tail))
        if stderr_tail.strip():
            self.console("API_COMMAND_STDERR_TAIL session=%s operation=%s\n%s" % (session["session_id"], operation, stderr_tail))
        return result

    def _needs_privilege_wrapper(self):
        return bool(self.execution_user and self.execution_user != self._current_user())

    def _current_user(self):
        try:
            import pwd
            return pwd.getpwuid(os.geteuid()).pw_name
        except Exception:
            return None

    def _wrap_for_execution_user(self, cmd, env):
        if not self._needs_privilege_wrapper():
            return cmd
        env_args = []
        for key in sorted(env.keys()):
            env_args.append("%s=%s" % (key, env[key]))
        if os.geteuid() == 0 and shutil.which("runuser"):
            return ["runuser", "-u", self.execution_user, "--", "env", "-i"] + env_args + cmd
        if shutil.which("sudo"):
            return ["sudo", "-n", "-u", self.execution_user, "env", "-i"] + env_args + cmd
        raise RuntimeError("cannot drop to execution user %s: need root/runuser or sudo -n" % self.execution_user)

    def _read_tail(self, path):
        try:
            with open(path, "rb") as f:
                f.seek(0, os.SEEK_END)
                size = f.tell()
                f.seek(max(0, size - self.max_log_bytes), os.SEEK_SET)
                data = f.read()
            return tail_text(data.decode("utf-8", "replace"), self.max_log_bytes)
        except Exception:
            return ""


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


class RunnerHandler(BaseHTTPRequestHandler):
    server_version = "queue-dev-runner/0.18.27"

    def log_message(self, fmt, *args):
        # Keep HTTP access visible on the server console, but never log auth headers/body.
        sys.stdout.write("%s %s\n" % (utc_now(), fmt % args))
        sys.stdout.flush()

    def do_GET(self):
        if self.path == "/healthz":
            return json_response(self, 200, ok_payload(
                "healthz",
                host=self.server.server_address[0],
                port=self.server.server_address[1],
                visible_console=self.server.store.visible_console,
                execution_user=self.server.store.execution_user or self.server.store._current_user(),
                work_root=self.server.store.work_root,
            ))
        return json_response(self, 404, error_payload("get", "not_found", "only /healthz is available via GET"))

    def do_POST(self):
        try:
            return self._do_POST()
        except Exception as exc:
            return json_response(self, 500, error_payload("post", "internal_error", str(exc)))

    def _do_POST(self):
        path = self.path.split("?", 1)[0]
        if path == "/session/create":
            data = self._read_json_or_form(max_bytes=16384)
            bootstrap_code = self.headers.get("X-Bootstrap-Code") or data.get("bootstrap_code") or data.get("code")
            if not bootstrap_code:
                return json_response(self, 401, error_payload("create", "bootstrap_required", "missing server-issued bootstrap code"))
            session, reason = self.server.store.create_session(bootstrap_code, self.client_address[0])
            if not session:
                return json_response(self, 403, error_payload("create", "bootstrap_rejected", reason))
            return json_response(self, 200, ok_payload(
                "create",
                session_id=session["session_id"],
                auth_code=session["auth_code"],
                expires_at=utc_from_epoch(session["expires_at"]),
                workspace=os.path.basename(session["workspace"]),
            ))

        direct_ops = {
            "/upload": "upload",
            "/test": "test",
            "/dev-test": "dev-test",
            "/patch-function": "patch-function",
            "/splice": "splice",
            "/ps": "ps",
            "/kill": "kill",
            "/session/close": "close",
        }
        if path in direct_ops:
            op = direct_ops[path]
            ctype = self.headers.get("Content-Type", "")
            # JSON/form protected endpoints may carry session_id/auth_code in the
            # body. Multipart uploads are the exception: do not consume their
            # stream during authentication; require header auth for multipart.
            if op == "upload" and "multipart/form-data" in ctype:
                data = None
                sid = self.headers.get("X-Session-Id") or self.headers.get("X-Session-ID")
                auth = self._auth_code()
            else:
                max_bytes = self.server.max_upload_bytes if op == "upload" else 65536
                data = self._read_json_or_form(max_bytes=max_bytes)
                sid = self.headers.get("X-Session-Id") or self.headers.get("X-Session-ID") or data.get("session_id")
                auth = self._auth_code() or data.get("auth_code")
            session, reason = self.server.store.get_session(sid, auth)
            if not session:
                return json_response(self, 401, error_payload(op, "auth_required", reason))
            return self._dispatch_session_operation(session, sid, op, data)

        m = re.match(r"^/session/([^/]+)/([^/]+)$", path)
        if not m:
            return json_response(self, 404, error_payload("post", "not_found", "unknown endpoint"))
        sid, op = m.group(1), m.group(2)
        auth = self._auth_code()
        session, reason = self.server.store.get_session(sid, auth)
        if not session:
            return json_response(self, 401, error_payload(op, "auth_required", reason))
        return self._dispatch_session_operation(session, sid, op)

    def _dispatch_session_operation(self, session, sid, op, data=None):
        if data is None and op != "upload":
            data = self._read_json_or_form(max_bytes=65536)
        if op == "upload":
            return self._handle_upload(session, data)
        if op == "test":
            return self._handle_test(session, data)
        if op == "dev-test":
            return self._handle_dev_test(session, data)
        if op == "patch-function":
            return self._handle_patch_function(session, data)
        if op == "splice":
            return self._handle_splice(session, data)
        if op == "ps":
            return self._handle_ps(session)
        if op == "kill":
            return self._handle_kill(session, data)
        if op == "close":
            cleanup = str(data.get("cleanup", "true")).lower() not in ("0", "false", "no")
            self.server.store.close_session(session, cleanup)
            return json_response(self, 200, ok_payload("close", session_id=sid, cleanup=cleanup))
        return json_response(self, 404, error_payload(op, "not_found", "unknown session operation"))

    def _auth_code(self):
        auth = self.headers.get("Authorization", "")
        if auth.lower().startswith("bearer "):
            return auth.split(None, 1)[1].strip()
        return self.headers.get("X-Auth-Code")

    def _content_length(self):
        try:
            return int(self.headers.get("Content-Length", "0"))
        except Exception:
            return 0

    def _read_raw(self, max_bytes):
        length = self._content_length()
        if length > max_bytes:
            raise ValueError("request too large")
        return self.rfile.read(length)

    def _read_json_or_form(self, max_bytes):
        ctype = self.headers.get("Content-Type", "")
        raw = self._read_raw(max_bytes)
        if not raw:
            return {}
        if "application/json" in ctype:
            return json.loads(raw.decode("utf-8"))
        if "application/x-www-form-urlencoded" in ctype:
            result = {}
            for pair in raw.decode("utf-8", "replace").split("&"):
                if not pair:
                    continue
                if "=" in pair:
                    k, v = pair.split("=", 1)
                else:
                    k, v = pair, ""
                from urllib.parse import unquote_plus
                result[unquote_plus(k)] = unquote_plus(v)
            return result
        try:
            return json.loads(raw.decode("utf-8"))
        except Exception:
            return {"raw": raw.decode("utf-8", "replace")}

    def _handle_upload(self, session, data=None):
        store = self.server.store
        length = self._content_length()
        if length > self.server.max_upload_bytes:
            return json_response(self, 413, error_payload("upload", "too_large", "upload exceeds configured limit"))
        ctype = self.headers.get("Content-Type", "")
        upload_root = os.path.join(session["workspace"], "uploads")
        relpath = self.headers.get("X-Upload-Path") or self.headers.get("X-Path") or "upload.bin"
        content = None
        if "multipart/form-data" in ctype:
            try:
                import cgi
            except Exception:
                return json_response(self, 415, error_payload("upload", "multipart_unavailable", "multipart upload requires Python cgi module; use JSON content_b64 upload"))
            fs = cgi.FieldStorage(fp=self.rfile, headers=self.headers, environ={"REQUEST_METHOD": "POST", "CONTENT_TYPE": ctype})
            if "path" in fs:
                relpath = fs["path"].value
            fileitem = fs["file"] if "file" in fs else None
            if fileitem is None or not getattr(fileitem, "file", None):
                return json_response(self, 400, error_payload("upload", "missing_file", "multipart field 'file' required"))
            content = fileitem.file.read(self.server.max_upload_bytes + 1)
            if len(content) > self.server.max_upload_bytes:
                return json_response(self, 413, error_payload("upload", "too_large", "upload exceeds configured limit"))
            if getattr(fileitem, "filename", None) and relpath == "upload.bin":
                relpath = fileitem.filename
        else:
            if data is None:
                data = self._read_json_or_form(max_bytes=self.server.max_upload_bytes)
            if "path" in data:
                relpath = data["path"]
            if "content_b64" in data:
                content = base64.b64decode(data["content_b64"])
            elif "content" in data:
                content = data["content"].encode("utf-8")
            elif "raw" in data:
                content = data["raw"].encode("utf-8")
            else:
                content = b""
        try:
            dest = safe_join(upload_root, relpath)
            ensure_parent_no_symlink_escape(upload_root, dest)
        except ValueError as exc:
            return json_response(self, 400, error_payload("upload", "unsafe_path", str(exc)))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if os.path.lexists(dest) and os.path.islink(dest):
            return json_response(self, 400, error_payload("upload", "symlink_rejected", "destination is a symlink"))
        with open(dest, "wb") as f:
            f.write(content)
        store.console("UPLOAD session=%s path=%s bytes=%d" % (session["session_id"], os.path.relpath(dest, session["workspace"]), len(content)))
        return json_response(self, 200, ok_payload("upload", session_id=session["session_id"], path=os.path.relpath(dest, session["workspace"]), bytes=len(content)))

    def _handle_test(self, session, data=None):
        if data is None:
            data = self._read_json_or_form(max_bytes=65536)
        test_name = data.get("test") or data.get("name")
        timeout = int(data.get("timeout", self.server.store.runtime_seconds))
        wait = str(data.get("wait", data.get("sync", "true"))).lower() not in ("0", "false", "no", "async")
        if not test_name:
            return json_response(self, 400, error_payload("test", "missing_test", "test name required"))
        if test_name in APPROVED_TESTS:
            args = APPROVED_TESTS[test_name]
        elif str(test_name).startswith("tests/") and test_name in ["tests/dev_remote_runner_static.sh", "tests/dev_remote_runner_smoke.py", "tests/dev_remote_runner_json_contract_static.py"]:
            args = ["python3", test_name] if test_name.endswith(".py") else ["bash", test_name]
        else:
            return json_response(self, 403, error_payload("test", "unapproved_test", "test is not in runner allowlist"))
        result = self.server.store.run_approved(session, "test", args, runtime_seconds=timeout, wait=wait)
        return json_response(self, 200, result)

    def _handle_dev_test(self, session, data=None):
        if data is None:
            data = self._read_json_or_form(max_bytes=65536)
        approved = data.get("approved_test") or data.get("name") or "bash_n_queuebash"
        timeout = int(data.get("timeout", self.server.store.runtime_seconds))
        wait = str(data.get("wait", data.get("sync", "true"))).lower() not in ("0", "false", "no", "async")
        if approved != "bash_n_queuebash":
            return json_response(self, 403, error_payload("dev-test", "unapproved_test", "dev-test v1 allows only bash_n_queuebash"))
        args = ["bash", "-lc", "set -e; export QUEUEBASH_ALLOW_NONINTERACTIVE=1; source ./queuebash.sh; queue dev test --run --json -- bash -n queuebash.sh"]
        result = self.server.store.run_approved(session, "dev-test", args, runtime_seconds=timeout, wait=wait)
        return json_response(self, 200, result)

    def _handle_ps(self, session):
        processes = self.server.store.list_session_processes(session)
        return json_response(self, 200, ok_payload(
            "ps",
            session_id=session["session_id"],
            scope="session",
            processes=processes,
        ))

    def _handle_kill(self, session, data=None):
        if data is None:
            data = self._read_json_or_form(max_bytes=16384)
        process_id = data.get("process_id")
        pid = data.get("pid")
        signal_name = data.get("signal", "TERM")
        ok, code, message = self.server.store.kill_session_process(session, process_id=process_id, pid=pid, signal_name=signal_name)
        if not ok:
            http_code = 403 if code == "not_session_process" else 400
            return json_response(self, http_code, error_payload("kill", code, message))
        return json_response(self, 200, ok_payload("kill", session_id=session["session_id"], process_id=process_id, pid=pid, result=message))

    def _handle_patch_function(self, session, data=None):
        if data is None:
            data = self._read_json_or_form(max_bytes=65536)
        target_file = data.get("file", "queuebash.sh")
        function = data.get("function")
        source = data.get("source")
        timeout = int(data.get("timeout", self.server.store.runtime_seconds))
        if not function or not source:
            return json_response(self, 400, error_payload("patch-function", "missing_argument", "function and source are required"))
        if target_file != "queuebash.sh" and not target_file.startswith("bin/") and not target_file.startswith("tests/"):
            return json_response(self, 403, error_payload("patch-function", "unapproved_target", "target file not approved"))
        if not SAFE_NAME_RE.match(target_file) or not SAFE_NAME_RE.match(function) or not SAFE_NAME_RE.match(source):
            return json_response(self, 400, error_payload("patch-function", "unsafe_argument", "argument contains unsafe characters"))
        upload_source = safe_join(os.path.join(session["workspace"], "uploads"), source)
        if not os.path.exists(upload_source):
            return json_response(self, 404, error_payload("patch-function", "missing_source", "uploaded source not found"))
        args = ["bash", "-lc", "set -e; export QUEUEBASH_ALLOW_NONINTERACTIVE=1; source ./queuebash.sh; queue dev patch --file %s --function %s --source %s --json" % (
            sh_quote(target_file), sh_quote(function), sh_quote(upload_source))]
        result = self.server.store.run_approved(session, "patch-function", args, runtime_seconds=timeout)
        return json_response(self, 200, result)

    def _handle_splice(self, session, data=None):
        if data is None:
            data = self._read_json_or_form(max_bytes=65536)
        target_file = data.get("file")
        after = data.get("after")
        insert_file = data.get("insert_file")
        timeout = int(data.get("timeout", self.server.store.runtime_seconds))
        if not target_file or not after or not insert_file:
            return json_response(self, 400, error_payload("splice", "missing_argument", "file, after, and insert_file are required"))
        if not (target_file.startswith("docs/") or target_file.startswith("tests/") or target_file in ("README.md", "CHANGELOG.md", "queuebash.sh")):
            return json_response(self, 403, error_payload("splice", "unapproved_target", "target file not approved"))
        if not SAFE_NAME_RE.match(target_file) or not SAFE_NAME_RE.match(insert_file):
            return json_response(self, 400, error_payload("splice", "unsafe_argument", "argument contains unsafe characters"))
        upload_source = safe_join(os.path.join(session["workspace"], "uploads"), insert_file)
        if not os.path.exists(upload_source):
            return json_response(self, 404, error_payload("splice", "missing_source", "uploaded insert file not found"))
        args = ["bash", "-lc", "set -e; export QUEUEBASH_ALLOW_NONINTERACTIVE=1; source ./queuebash.sh; queue dev splice --file %s --after %s --insert-file %s --json" % (
            sh_quote(target_file), sh_quote(after), sh_quote(upload_source))]
        result = self.server.store.run_approved(session, "splice", args, runtime_seconds=timeout)
        return json_response(self, 200, result)


def sh_quote(s):
    return "'" + str(s).replace("'", "'\"'\"'") + "'"


def console_input_thread(store):
    store.console("Press Enter in this terminal to issue a one-use /session/create bootstrap code.")
    while True:
        try:
            line = sys.stdin.readline()
            if line == "":
                time.sleep(0.5)
                continue
            store.mint_bootstrap("console-enter")
        except Exception as exc:
            store.console("WARN console input failed: %s" % exc)
            time.sleep(1)


def parse_args(argv):
    p = argparse.ArgumentParser(description="Capability-scoped bashqueues remote dev runner")
    p.add_argument("--repo", default=os.getcwd(), help="bashqueues repository root")
    p.add_argument("--work-root", default=None, help="runner session workspace root")
    p.add_argument("--host", default="127.0.0.1", help="bind host; default 127.0.0.1")
    p.add_argument("--port", type=int, default=8765, help="bind port")
    p.add_argument("--ttl", type=int, default=DEFAULT_TTL_SECONDS, help="session TTL seconds")
    p.add_argument("--bootstrap-ttl", type=int, default=DEFAULT_BOOTSTRAP_TTL_SECONDS, help="bootstrap code TTL seconds")
    p.add_argument("--max-upload-bytes", type=int, default=DEFAULT_MAX_UPLOAD_BYTES)
    p.add_argument("--max-log-bytes", type=int, default=DEFAULT_MAX_LOG_BYTES)
    p.add_argument("--runtime-seconds", type=int, default=DEFAULT_RUNTIME_SECONDS)
    p.add_argument("--execution-user", default="lockeduser", help="user for queue-dev operations; default lockeduser")
    p.add_argument("--create-execution-user", action="store_true", help="create/lock execution user if missing")
    p.add_argument("--no-create-execution-user", action="store_true", help="do not create execution user")
    p.add_argument("--public", action="store_true", help="allow non-local bind with warning")
    p.add_argument("--no-console-tokens", action="store_true", help="disable Enter-to-mint bootstrap codes")
    p.add_argument("--mint-on-start", action="store_true", help="mint one bootstrap code at server start")
    return p.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    if args.host not in ("127.0.0.1", "localhost", "::1") and not args.public:
        sys.stderr.write("ERROR: non-local bind requires --public\n")
        return 2
    if args.public:
        sys.stderr.write("WARNING: public bind requested. Use firewall, SSH tunnel preference, session id, bootstrap code, auth code, TTL, and workspace confinement.\n")
    work_root = args.work_root or tempfile.mkdtemp(prefix="queue-dev-runner-")
    create_user = bool(args.create_execution_user and not args.no_create_execution_user)
    store = SessionStore(
        repo=args.repo,
        work_root=work_root,
        ttl_seconds=args.ttl,
        bootstrap_ttl_seconds=args.bootstrap_ttl,
        execution_user=args.execution_user,
        create_execution_user=create_user,
        visible_console=True,
        max_log_bytes=args.max_log_bytes,
        runtime_seconds=args.runtime_seconds,
    )
    httpd = ThreadedHTTPServer((args.host, args.port), RunnerHandler)
    httpd.store = store
    httpd.max_upload_bytes = args.max_upload_bytes
    start_payload = ok_payload(
        "server_start",
        host=args.host,
        port=args.port,
        work_root=work_root,
        visible_console=True,
        execution_user=args.execution_user,
    )
    print(json.dumps(start_payload, sort_keys=True))
    sys.stdout.flush()
    if not args.no_console_tokens:
        t = threading.Thread(target=console_input_thread, args=(store,))
        t.daemon = True
        t.start()
    if args.mint_on_start:
        store.mint_bootstrap("startup")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        store.console("SERVER_STOP keyboard_interrupt")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
