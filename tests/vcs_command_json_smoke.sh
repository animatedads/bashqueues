#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT" "$tmp"' EXIT
source ./queuebash.sh

types_json="$(queue vcs types --json)"
printf '%s\n' "$types_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.vcs.types.v1"; assert o["read_only"] is True; assert {s["type"] for s in o["systems"]} >= {"git","svn","cvs","hg","p4"}; assert "VCS_LEGACY_SERIAL" in o["classes"]'

tmp="$(mktemp -d)"
mkdir -p "$tmp/CVS"
detect_json="$(queue vcs detect "$tmp" --json)"
printf '%s\n' "$detect_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.vcs.detect.v1"; assert o["type"]=="cvs"; assert o["marker"]=="CVS"'

echo "[PASS] queue vcs command JSON smoke passed"
