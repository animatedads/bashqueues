#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT/docs/PLAN_SCRIPT_BEHAVIOUR_MODEL.md"
ADAPTER="$ROOT/docs/PLAN_ADAPTER_CONTRACT.md"
FIX="$ROOT/fixtures/plan/script/backup-and-upload.sh"
UNSAFE="$ROOT/fixtures/plan/script/unsafe-curl-pipe.sh"
EXPECTED="$ROOT/fixtures/plan/script/expected-script-behaviour-control-plan.json"

for f in "$DOC" "$ADAPTER" "$FIX" "$UNSAFE" "$EXPECTED"; do
  [[ -s "$f" ]] || { echo "missing script behaviour artifact: $f" >&2; exit 1; }
done

for token in \
  "script-behaviour" "must not" "execute the script" "pg_dump" "aws" "kubectl" \
  "terraform" "curl/wget piped to sh" "DATABASE_MIGRATION" "BACKUP_JOB" \
  "needs_review" "unsafe_refused"; do
  grep -q "$token" "$DOC" || { echo "script behaviour model missing token: $token" >&2; exit 1; }
done

grep -q "curl .*| sh" "$UNSAFE" || { echo "unsafe fixture missing curl pipe" >&2; exit 1; }
grep -q "sudo systemctl" "$UNSAFE" || { echo "unsafe fixture missing privilege/service mutation" >&2; exit 1; }
grep -q "pg_dump" "$FIX" || { echo "backup fixture missing database dump evidence" >&2; exit 1; }
grep -q "aws s3 cp" "$FIX" || { echo "backup fixture missing object-storage upload evidence" >&2; exit 1; }
grep -q '"adapter": "script-behaviour"' "$EXPECTED" || { echo "expected plan missing script adapter" >&2; exit 1; }
grep -q '"safe_to_apply": false' "$EXPECTED" || { echo "expected script plan must not be live-apply safe" >&2; exit 1; }
