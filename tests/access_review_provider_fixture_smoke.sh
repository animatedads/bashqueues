#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/access_review/access_review_provider.sh"
QUEUEBASH_ACCESS_REVIEW_FIXTURE_DIR="$PWD/tests/fixtures/access_review" "$helper" detect > /tmp/access_review_detect.json
python3 -m json.tool /tmp/access_review_detect.json >/dev/null
QUEUEBASH_ACCESS_REVIEW_FIXTURE_DIR="$PWD/tests/fixtures/access_review" "$helper" scope explain > /tmp/access_review_scope.json
python3 -m json.tool /tmp/access_review_scope.json >/dev/null
QUEUEBASH_ACCESS_REVIEW_FIXTURE_DIR="$PWD/tests/fixtures/access_review" "$helper" entitlement explain > /tmp/access_review_entitlement.json
python3 -m json.tool /tmp/access_review_entitlement.json >/dev/null
QUEUEBASH_ACCESS_REVIEW_FIXTURE_DIR="$PWD/tests/fixtures/access_review" "$helper" reviewer explain > /tmp/access_review_reviewer.json
python3 -m json.tool /tmp/access_review_reviewer.json >/dev/null
QUEUEBASH_ACCESS_REVIEW_FIXTURE_DIR="$PWD/tests/fixtures/access_review" "$helper" exception explain > /tmp/access_review_exception.json
python3 -m json.tool /tmp/access_review_exception.json >/dev/null
printf 'PASS access_review_provider_fixture_smoke
'
