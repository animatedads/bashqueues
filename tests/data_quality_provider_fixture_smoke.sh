#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/data_quality/data_quality_provider.sh"
QUEUEBASH_DATA_QUALITY_FIXTURE_DIR="$PWD/tests/fixtures/data_quality" "$helper" detect > /tmp/data_quality_detect.json
python3 -m json.tool /tmp/data_quality_detect.json >/dev/null
QUEUEBASH_DATA_QUALITY_FIXTURE_DIR="$PWD/tests/fixtures/data_quality" "$helper" ruleset explain > /tmp/data_quality_ruleset.json
python3 -m json.tool /tmp/data_quality_ruleset.json >/dev/null
QUEUEBASH_DATA_QUALITY_FIXTURE_DIR="$PWD/tests/fixtures/data_quality" "$helper" expectation explain > /tmp/data_quality_expectation.json
python3 -m json.tool /tmp/data_quality_expectation.json >/dev/null
QUEUEBASH_DATA_QUALITY_FIXTURE_DIR="$PWD/tests/fixtures/data_quality" "$helper" profile explain > /tmp/data_quality_profile.json
python3 -m json.tool /tmp/data_quality_profile.json >/dev/null
QUEUEBASH_DATA_QUALITY_FIXTURE_DIR="$PWD/tests/fixtures/data_quality" "$helper" result explain > /tmp/data_quality_result.json
python3 -m json.tool /tmp/data_quality_result.json >/dev/null
printf 'PASS data_quality_provider_fixture_smoke
'
