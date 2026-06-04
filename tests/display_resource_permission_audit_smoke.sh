#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/resources.d"
cp -a resources.d/display "$tmpdir/resources.d/display"
cp -a resources.d/xml "$tmpdir/resources.d/xml"
out="$tmpdir/permission-audit-ok.json"
python3 bin/queue-display-resource-permission-audit.py --root "$tmpdir" --json > "$out"
python3 - "$out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.display_resource_permission_audit.v1"
assert payload["status"] == "ok", payload.get("findings")
assert payload["redacted"] is True
assert payload["read_only"] is True
assert payload["installer"] is False
assert payload["signing_mutation"] is False
assert payload["permission_mutation"] is False
assert payload["renderer"] == "none-permission-audit-only"
assert payload["source"] == "manifest-metadata-and-filesystem-mode-only"
assert payload["json_contract_source"] is False
assert payload["secret_rendering_allowed"] is False
assert payload["token_value_substitution"] is False
assert payload["required_file_properties"]["executable_allowed"] is False
assert payload["stats"]["files_checked"] >= 2
assert payload["stats"]["executable_files"] == 0
assert payload["stats"]["world_writable_files"] == 0
assert payload["stats"]["symlink_files"] == 0
for text in json.dumps(payload).splitlines():
    assert "actual-secret" not in text.lower()
    assert "secret-value" not in text.lower()
PY
chmod +x "$tmpdir/resources.d/display/fallback/queue-version.txt"
if python3 bin/queue-display-resource-permission-audit.py --root "$tmpdir" --json > "$tmpdir/permission-audit-exec.json"; then
  echo "expected executable resource to fail" >&2
  exit 1
fi
python3 - "$tmpdir/permission-audit-exec.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.display_resource_permission_audit.v1"
assert payload["status"] == "error"
assert payload["stats"]["executable_files"] >= 1
assert any(f["code"] == "resource_executable" for f in payload["findings"])
PY
chmod -x "$tmpdir/resources.d/display/fallback/queue-version.txt"
chmod o+w "$tmpdir/resources.d/display/fallback/queue-version.txt"
if python3 bin/queue-display-resource-permission-audit.py --root "$tmpdir" --json > "$tmpdir/permission-audit-world.json"; then
  echo "expected world-writable resource to fail" >&2
  exit 1
fi
python3 - "$tmpdir/permission-audit-world.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.display_resource_permission_audit.v1"
assert payload["status"] == "error"
assert payload["stats"]["world_writable_files"] >= 1
assert any(f["code"] == "resource_world_writable" for f in payload["findings"])
PY
