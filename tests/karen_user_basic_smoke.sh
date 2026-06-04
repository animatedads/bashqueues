#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh

_karen_assert_no_job_named() {
    local wanted="$1"
    local f name
    while IFS= read -r -d '' f; do
        name="$(grep '^JOB_NAME=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | sed "s/^'//;s/'$//")"
        if [[ "$name" == "$wanted" ]]; then
            echo "dry-run unexpectedly created job: $wanted ($f)" >&2
            return 1
        fi
    done < <(find "$QUEUEBASH_ROOT/pending" "$QUEUEBASH_ROOT/running" "$QUEUEBASH_ROOT/done" "$QUEUEBASH_ROOT/failed" "$QUEUEBASH_ROOT/pol_blocked" -type f -name '*.job' -print0 2>/dev/null)
}

queue version >/tmp/karen-version.out
queue version --json >/tmp/karen-version.json
python3 -m json.tool /tmp/karen-version.json >/dev/null

queue submit hello -- echo hello-from-queue >/tmp/karen-submit.out
queue run --workers 1 >/tmp/karen-run.out
queue list --state done --json >/tmp/karen-done.json
grep -Fq 'hello' /tmp/karen-done.json
queue show hello --tail 30 >/tmp/karen-show.out
grep -Fq 'hello-from-queue' /tmp/karen-show.out

queue submit dry-one --dryrun -- echo should-not-run >/tmp/karen-dry-one.out
grep -Fq 'DRYRUN: would submit job:' /tmp/karen-dry-one.out
_karen_assert_no_job_named dry-one
queue --dryrun submit dry-two -- echo should-not-run >/tmp/karen-dry-two.out
grep -Fq 'DRYRUN: would submit job:' /tmp/karen-dry-two.out
_karen_assert_no_job_named dry-two

if queue submit badprio -p abc -- echo nope >/tmp/karen-badprio.out 2>/tmp/karen-badprio.err; then
    echo 'bad priority unexpectedly accepted' >&2
    exit 1
fi
grep -Fq 'priority must be numeric' /tmp/karen-badprio.err

queue submit default-priority -- echo default-priority >/tmp/karen-default-priority.out
grep -Fq 'priority=10' /tmp/karen-default-priority.out

if queue submit missingdash echo hi >/tmp/karen-missingdash.out 2>/tmp/karen-missingdash.err; then
    echo 'missing -- unexpectedly accepted' >&2
    exit 1
fi
grep -Fq 'unexpected argument before --' /tmp/karen-missingdash.err

queue submit "name with spaces" -- echo spaces >/tmp/karen-spaces.out
queue list --state all --json >/tmp/karen-all.json
python3 -m json.tool /tmp/karen-all.json >/dev/null

if queue frobnicate >/tmp/karen-frob.out 2>/tmp/karen-frob.err; then
    echo 'unknown command unexpectedly accepted' >&2
    exit 1
fi
grep -Fq 'Unknown queue command' /tmp/karen-frob.err

echo "PASS karen_user_basic_smoke"
