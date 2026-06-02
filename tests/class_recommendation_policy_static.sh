#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d "${TMPDIR:-/tmp}/class-recommend.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

bin/queue-class-infer.py recommend --json \
  --history tests/fixtures/class_inference/history.jsonl \
  --policy policies.d/class-inference/default.json \
  --class DEFAULT \
  -- ffmpeg -i input999.mp4 -vf scale=1280:720 output999.mp4 > "$tmp/recommend.json"

bin/queue-class-infer.py recommend --json \
  --history tests/fixtures/class_inference/history.jsonl \
  --pins tests/fixtures/class_inference/pins.jsonl \
  --policy policies.d/class-inference/default.json \
  --class DEFAULT \
  -- ffmpeg -i input999.mp4 -vf scale=1280:720 output999.mp4 > "$tmp/pinned.json"

/usr/bin/python3 - "$tmp/recommend.json" "$tmp/pinned.json" <<'PY'
import json, sys
rec=json.load(open(sys.argv[1])); pin=json.load(open(sys.argv[2]))
assert rec['schema']=='queuebash.class_inference.recommendation.v1'
assert rec['recommended_class']=='VIDEO_ENCODE'
assert rec['recommendation_source']=='history'
assert rec['mismatch']=='class_mismatch'
assert rec['policy_linkage']['corporate_policy_refs']
assert rec['policy_linkage']['regulatory_refs']
assert rec['policy_linkage']['validation_status']=='mapped_pending_validation'
assert rec['audit_event_preview']['policy_references']
assert pin['recommended_class']=='VIDEO_ENCODE_SECURE'
assert pin['recommendation_source']=='pin'
assert pin['confidence']==1.0
print('PASS class recommendation policy json')
PY

QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$tmp/root" bash -lc 'source ./queuebash.sh >/dev/null; queue class-infer recommend --json --history tests/fixtures/class_inference/history.jsonl --policy policies.d/class-inference/default.json --class DEFAULT -- ffmpeg -i input111.mp4 -vf scale=640:360 output111.mp4' > "$tmp/via-queue.json"
grep -q 'queuebash.class_inference.recommendation.v1' "$tmp/via-queue.json"

echo 'PASS class_recommendation_policy_static'
