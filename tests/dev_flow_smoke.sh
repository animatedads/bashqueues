#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cat > "$tmpdir/flow_sample.sh" <<'EOS'
alpha() {
    if beta; then
        gamma
    else
        delta
    fi
    case "$1" in
        x) gamma ;;
        *) return 2 ;;
    esac
    cat <<'PY'
def fake_python():
    if this_were_scanned_it_would_be_noise:
        pass
PY
}
beta() { return 0; }
gamma() { echo gamma; }
delta() { echo delta; }
EOS

out="$(queue dev flow --file "$tmpdir/flow_sample.sh" --function alpha --json)"
python3 - "$out" <<'PY'
import json, sys
d=json.loads(sys.argv[1])
assert d["status"] == "ok"
assert d["function"] == "alpha"
assert d["summary"]["branches"] >= 3, d["summary"]
edges={(e["from"], e["to"], e["kind"]) for e in d["edges"]}
assert ("alpha", "beta", "call") in edges, edges
assert ("alpha", "gamma", "call") in edges, edges
assert ("alpha", "delta", "call") in edges, edges
# Heredoc Python body must not become branch noise.
assert not any("fake_python" in b.get("text", "") for b in d["branches"]), d["branches"]
node={n["id"]: n for n in d["nodes"]}["alpha"]
assert node["callees"] == ["beta", "delta", "gamma"], node
PY

echo '[PASS] queue dev flow emits function call/branch graph JSON'
