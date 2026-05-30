#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bin/queue-dev-timeout --timeout 5 --stdout "$tmp/out" --stderr "$tmp/err" -- bash -c 'printf "%s" "$QUEUEBASH_ALLOW_NONINTERACTIVE:$CI:$TERM:$GIT_TERMINAL_PROMPT"'
grep -Eq '^1:(1|true):dumb:0$' "$tmp/out"

if bin/queue-dev-timeout --timeout 1 -- bash -c 'sleep 5' >"$tmp/timeout.out" 2>"$tmp/timeout.err"; then
  echo 'expected timeout helper to return non-zero for a timed-out command' >&2
  exit 1
fi

bin/queue-dev-timeout --timeout 5 --xtrace --stderr "$tmp/x.err" -- bash -c 'echo traced-ok' >"$tmp/x.out"
grep -q 'traced-ok' "$tmp/x.out"
grep -q '+ echo traced-ok' "$tmp/x.err"

echo "PASS dev_timeout_helper_smoke"
