#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/secrets_scanner/secrets_scanner_provider.sh"
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" detect > /tmp/secrets_scanner_detect.json
python3 -m json.tool /tmp/secrets_scanner_detect.json >/dev/null
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" source explain > /tmp/secrets_scanner_source.json
python3 -m json.tool /tmp/secrets_scanner_source.json >/dev/null
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" signal explain > /tmp/secrets_scanner_signal.json
python3 -m json.tool /tmp/secrets_scanner_signal.json >/dev/null
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" redaction explain > /tmp/secrets_scanner_redaction.json
python3 -m json.tool /tmp/secrets_scanner_redaction.json >/dev/null
QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR="$PWD/tests/fixtures/secrets_scanner" bash "$helper" policy explain > /tmp/secrets_scanner_policy.json
python3 -m json.tool /tmp/secrets_scanner_policy.json >/dev/null
printf 'PASS secrets_scanner_provider_fixture_smoke
'
