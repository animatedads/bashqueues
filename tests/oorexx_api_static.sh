#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
api_dir="$repo_root/api/oorexx"
cls="$api_dir/BashQueues.cls"

fail() { echo "oorexx_api_static: FAIL: $*" >&2; exit 1; }

[[ -d "$api_dir" ]] || fail "api/oorexx missing"
[[ -f "$cls" ]] || fail "BashQueues.cls missing"

if find "$api_dir" -iname 'json.cls' -print -quit | grep -q .; then
  fail "vendored json.cls must not be included"
fi

if find "$api_dir" -path '*/vendor/*' -print -quit | grep -q .; then
  fail "vendor tree must not be included"
fi

grep -Fq '::requires "json.cls"' "$cls" || fail "BashQueues.cls must require platform json.cls"
grep -Fq 'json = .json~new' "$cls" || fail "JSON parser must be instantiated"
grep -Fq 'json~fromJson(text)' "$cls" || fail "fromJson call missing"
grep -Fq 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1' "$cls" || fail "noninteractive env export missing"
grep -Fq 'source ' "$cls" || fail "source of queuebash.sh missing"
grep -Fq '::method supplier' "$cls" || fail "BQCollection supplier missing"
grep -Fq '::method raw' "$cls" || fail "raw JSON helper missing"
grep -Fq 'BASHQUEUES_OOREXX_DISCOVER' "$cls" || fail "lazy/eager discovery switch missing"
grep -Fq '::method discover' "$cls" || fail "explicit discover method missing"

grep -Fq '::method lastError public' "$cls" || fail "lastError method missing"
grep -Fq '_normaliseOptional(root, "ROOT")' "$cls" || fail "ROOT symbolic optional normalisation missing"
grep -Fq '_normaliseOptional(binary, "BINARY")' "$cls" || fail "BINARY symbolic optional normalisation missing"
grep -Fq '_normaliseOptional(sourceFile, "SOURCEFILE")' "$cls" || fail "SOURCEFILE symbolic optional normalisation missing"
grep -Fq 'functionsData~hasIndex("functions")' "$cls" || fail "functions Directory hasIndex guard missing"
grep -Fq 'entry~hasIndex("function")' "$cls" || fail "function entry hasIndex guard missing"
grep -Fq 'opts~hasIndex("priority")' "$cls" || fail "submit priority hasIndex guard missing"

grep -Fq 'api bin systemd' "$repo_root/install-system.sh" || fail "install-system support dir list must include api"
grep -Fq 'for dir in assets.d caps.d reporters.d classes envs.d policies.d docs api bin' "$repo_root/install-system.sh" || fail "install-system copy loop must include api"

required=(
  README.md
  docs/OOREXX_API.md
  examples/bq_json_frontage_demo.rex
  examples/bq_status_panel.rex
  examples/bq_snapshot_export.rex
  examples/cancel_blocked.rex
  examples/list_by_state.rex
  examples/submit_and_watch.rex
  tests/test_connect.rex
  tests/test_data.rex
  tests/test_jobs.rex
  tests/test_namespace.rex
)
for rel in "${required[@]}"; do
  [[ -f "$api_dir/$rel" ]] || fail "missing $rel"
done

if command -v rexx >/dev/null 2>&1; then
  echo "oorexx_api_static: rexx available; syntax/runnable smoke can be run separately"
else
  echo "oorexx_api_static: rexx not available; static checks only"
fi

echo "oorexx_api_static: PASS"
