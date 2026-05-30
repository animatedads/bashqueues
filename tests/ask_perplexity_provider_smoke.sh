#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
python3 - <<'PY'
import json
import os
import subprocess
import sys

root = os.getcwd()
env = os.environ.copy()
env["QUEUEBASH_ALLOW_NONINTERACTIVE"] = "1"

def run_queue(args):
    script = "source ./queuebash.sh; " + " ".join(subprocess.list2cmdline([a]) for a in args)
    cp = subprocess.run(["bash", "-lc", script], cwd=root, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    if cp.returncode != 0:
        print(cp.stdout, end="")
        print(cp.stderr, end="", file=sys.stderr)
        raise SystemExit(cp.returncode)
    return json.loads(cp.stdout)

j = run_queue(["queue", "ask", "provider", "explain", "perplexity", "--json"])
assert j["schema"] == "queuebash.ask_provider.discovery.v1"
assert j["provider"] == "perplexity"
assert j["live_supported"] is True
assert j["supports_json"] is True

j = run_queue(["queue", "ask", "provider", "test", "perplexity", "--fixture", "--json"])
assert j["schema"] == "queuebash.ask_provider.fixture_test.v1"
assert j["provider"] == "perplexity"
assert j["status"] == "ok"
assert j["live_call_performed"] is False

cp = subprocess.run([sys.executable, "bin/queue-ai-ask-perplexity", "--describe"], cwd=root, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
if cp.returncode != 0:
    print(cp.stdout, end="")
    print(cp.stderr, end="", file=sys.stderr)
    raise SystemExit(cp.returncode)
j = json.loads(cp.stdout)
assert j["schema"] == "queuebash.ask_provider.contract.v1"
assert j["provider"] == "perplexity"
assert j["fixture_supported"] is True
assert j["advisory_only"] is True
PY
