#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/resources.d"
cp -a resources.d/display "$tmpdir/resources.d/display"
cp -a resources.d/xml "$tmpdir/resources.d/xml"
out="$tmpdir/install-audit-ok.json"
python3 bin/queue-display-resource-install-audit.py --source-root . --installed-root "$tmpdir" --json > "$out"
python3 - "$out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.display_resource_install_audit.v1"
assert payload["status"] == "ok", payload.get("findings")
assert payload["redacted"] is True
assert payload["read_only"] is True
assert payload["installer"] is False
assert payload["signing_mutation"] is False
assert payload["renderer"] == "none-install-audit-only"
assert payload["source"] == "manifest-metadata-and-file-hash-presence-only"
assert payload["json_contract_source"] is False
assert payload["secret_rendering_allowed"] is False
assert payload["token_value_substitution"] is False
assert payload["stats"]["resources_declared"] >= 1
assert payload["stats"]["resources_installed_ok"] == payload["stats"]["resources_declared"]
assert any(r["name"] == "queue-version.txt" and r["sha256_match"] for r in payload["resources"])
for text in json.dumps(payload).splitlines():
    assert "actual-secret" not in text.lower()
    assert "secret-value" not in text.lower()
PY
rm -f "$tmpdir/resources.d/display/fallback/queue-version.txt"
if python3 bin/queue-display-resource-install-audit.py --source-root . --installed-root "$tmpdir" --json > "$tmpdir/install-audit-missing.json"; then
  echo "expected missing installed resource to fail" >&2
  exit 1
fi
python3 - "$tmpdir/install-audit-missing.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.display_resource_install_audit.v1"
assert payload["status"] == "error"
assert any(f["code"] == "installed_resource_missing" for f in payload["findings"])
PY
