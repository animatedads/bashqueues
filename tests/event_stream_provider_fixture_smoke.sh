#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/event_stream/event_stream_provider.sh"
QUEUEBASH_EVENT_STREAM_FIXTURE_DIR="$PWD/tests/fixtures/event_stream" "$helper" detect > /tmp/event_stream_detect.json
python3 -m json.tool /tmp/event_stream_detect.json >/dev/null
QUEUEBASH_EVENT_STREAM_FIXTURE_DIR="$PWD/tests/fixtures/event_stream" "$helper" topic explain > /tmp/event_stream_topic.json
python3 -m json.tool /tmp/event_stream_topic.json >/dev/null
QUEUEBASH_EVENT_STREAM_FIXTURE_DIR="$PWD/tests/fixtures/event_stream" "$helper" consumer explain > /tmp/event_stream_consumer.json
python3 -m json.tool /tmp/event_stream_consumer.json >/dev/null
QUEUEBASH_EVENT_STREAM_FIXTURE_DIR="$PWD/tests/fixtures/event_stream" "$helper" retention explain > /tmp/event_stream_retention.json
python3 -m json.tool /tmp/event_stream_retention.json >/dev/null
QUEUEBASH_EVENT_STREAM_FIXTURE_DIR="$PWD/tests/fixtures/event_stream" "$helper" governance explain > /tmp/event_stream_governance.json
python3 -m json.tool /tmp/event_stream_governance.json >/dev/null
printf 'PASS event_stream_provider_fixture_smoke
'
