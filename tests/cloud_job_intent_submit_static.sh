#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }
grep -q 'QUEUEBASH_VERSION="0.18.84"' queuebash.sh || fail 'version not bumped to 0.18.84'
grep -q -- '--uses-cloud' queuebash.sh || fail 'submit --uses-cloud flag missing'
grep -q 'CLOUD_PROFILE' queuebash.sh || fail 'CLOUD_PROFILE persistence missing'
grep -q 'CLOUD_BROKER_BINDING' queuebash.sh || fail 'CLOUD_BROKER_BINDING persistence missing'
grep -q 'not-bound-to-dispatch' queuebash.sh || fail 'advisory-only binding note missing'
grep -q 'CLOUD_JOB_INTENT' docs/CLOUD_JOB_INTENT.md || true
[[ -f docs/CLOUD_JOB_INTENT.md ]] || fail 'cloud job intent docs missing'
echo PASS
