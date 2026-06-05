#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
tmp="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT" "$tmp"' EXIT
source ./queuebash.sh

mkdir -p "$tmp/CVS"
printf 'TREL_2_0\n' > "$tmp/CVS/Tag"
printf ':local:/legacy/cvsroot\n' > "$tmp/CVS/Root"
probe_json="$(queue vcs probe "$tmp" --json --type auto --timeout 1)"
printf '%s\n' "$probe_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.vcs.probe.v1"; assert o["type"]=="cvs"; assert o["identity"]=="REL_2_0"; assert o["revision"]==":local:/legacy/cvsroot"'

types_json="$(queue vcs types --json)"
printf '%s\n' "$types_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert "vcs:identity" in o["assets"]; assert "vcs:revision" in o["assets"]; assert "VCS_CHANGESET_AUDIT" in o["classes"]'

echo "[PASS] queue vcs probe JSON smoke passed"
