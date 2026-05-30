#!/usr/bin/env python3
import base64
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

repo = pathlib.Path(__file__).resolve().parents[1]
runner = repo / "bin" / "queue-dev-runner.py"


def post(url, path, body=None, headers=None, expect=200):
    data = json.dumps(body or {}).encode("utf-8")
    merged = {"Content-Type": "application/json"}
    if headers:
        merged.update(headers)
    req = urllib.request.Request(url + path, data=data, headers=merged, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            payload = json.loads(r.read().decode("utf-8"))
            assert r.status == expect, (path, r.status, payload)
            return payload
    except urllib.error.HTTPError as e:
        payload = json.loads(e.read().decode("utf-8"))
        assert e.code == expect, (path, e.code, payload)
        return payload


def get(url, path, expect=200):
    try:
        with urllib.request.urlopen(url + path, timeout=10) as r:
            payload = json.loads(r.read().decode("utf-8"))
            assert r.status == expect, (path, r.status, payload)
            return payload
    except urllib.error.HTTPError as e:
        payload = json.loads(e.read().decode("utf-8"))
        assert e.code == expect, (path, e.code, payload)
        return payload


def readline_text(proc, timeout=10):
    deadline = time.time() + timeout
    while time.time() < deadline:
        line = proc.stdout.readline()
        if line:
            return line.decode("utf-8", "replace").rstrip("\n")
        time.sleep(0.05)
    raise AssertionError("timed out waiting for runner stdout")


def mint_bootstrap(proc):
    proc.stdin.write(b"\n")
    proc.stdin.flush()
    for _ in range(40):
        line = readline_text(proc)
        m = re.search(r"BOOTSTRAP_CODE=(BQBOOT_[A-Za-z0-9]+)", line)
        if m:
            return m.group(1)
    raise AssertionError("bootstrap code not printed")


def start_runner(td, port, ttl="60"):
    work = pathlib.Path(td) / ("work-%s" % port)
    user = os.environ.get("USER") or "nobody"
    proc = subprocess.Popen(
        [sys.executable, str(runner), "--host", "127.0.0.1", "--port", str(port), "--work-root", str(work), "--ttl", ttl, "--max-log-bytes", "512", "--max-upload-bytes", "4096", "--runtime-seconds", "10", "--execution-user", user, "--no-create-execution-user"],
        cwd=str(repo), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    line = readline_text(proc)
    payload = json.loads(line)
    assert payload["schema"] == "queuebash.dev_remote_runner.v1"
    assert payload["operation"] == "server_start"
    # Skip the prompt line if it appears before the bootstrap line.
    return proc, "http://127.0.0.1:%s" % port


def main():
    with tempfile.TemporaryDirectory(prefix="bq-remote-runner-smoke-") as td:
        proc, url = start_runner(td, 18765)
        try:
            health = get(url, "/healthz")
            assert health["operation"] == "healthz" and health["status"] == "ok"
            get_create = get(url, "/session/create", expect=404)
            assert get_create["error"] == "not_found"

            unauth = post(url, "/upload", {}, expect=401)
            assert unauth["error"] == "auth_required"

            bootstrap = mint_bootstrap(proc)
            session = post(url, "/session/create", {"bootstrap_code": bootstrap})
            assert session["operation"] == "create" and session["status"] == "ok"
            sid = session["session_id"]
            code = session["auth_code"]
            headers = {"X-Session-Id": sid, "Authorization": "Bearer " + code}
            auth_body = {"session_id": sid, "auth_code": code}

            reused = post(url, "/session/create", {"bootstrap_code": bootstrap}, expect=403)
            assert reused["error"] == "bootstrap_rejected"

            traversal = post(url, "/upload", dict(auth_body, path="../escape.txt", content="bad"), expect=400)
            assert traversal["error"] == "unsafe_path"

            upload = post(url, "/upload", dict(auth_body, path="hello.txt", content="hello world"))
            assert upload["operation"] == "upload" and upload["bytes"] == 11

            bad_run = post(url, "/run", dict(auth_body, cmd="id"), expect=404)
            assert bad_run["error"] == "not_found"

            ps0 = post(url, "/ps", auth_body)
            assert ps0["operation"] == "ps" and ps0["scope"] == "session"

            kill_pid1 = post(url, "/kill", dict(auth_body, pid=1), expect=403)
            assert kill_pid1["error"] == "not_session_process"

            sleepy = post(url, "/test", dict(auth_body, name="sleepy", wait=False, timeout=30))
            assert sleepy["status"] == "started" and sleepy.get("process_id")
            process_id = sleepy["process_id"]
            ps1 = post(url, "/ps", auth_body)
            assert any(p.get("process_id") == process_id for p in ps1["processes"])
            killed = post(url, "/kill", dict(auth_body, process_id=process_id))
            assert killed["operation"] == "kill" and killed["status"] == "ok"

            focused = post(url, "/test", dict(auth_body, name="bash_n_queuebash", timeout=10))
            assert focused["operation"] == "test" and focused["exit_code"] == 0

            close = post(url, "/session/close", dict(auth_body, cleanup=True))
            assert close["operation"] == "close" and close["cleanup"] is True
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()

        proc2, url2 = start_runner(td, 18766, ttl="1")
        try:
            boot2 = mint_bootstrap(proc2)
            sess2 = post(url2, "/session/create", {"bootstrap_code": boot2})
            headers2 = {"X-Session-Id": sess2["session_id"], "Authorization": "Bearer " + sess2["auth_code"]}
            time.sleep(1.3)
            expired = post(url2, "/ps", {}, headers2, expect=401)
            assert expired["error"] == "auth_required" and "expired" in expired["message"]
        finally:
            proc2.terminate()
            try:
                proc2.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc2.kill()

    print("PASS dev_remote_runner_smoke")


if __name__ == "__main__":
    main()
