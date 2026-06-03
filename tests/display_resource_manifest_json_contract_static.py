#!/usr/bin/env python3
import csv
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]

manifest = json.loads((root / "schemas/display_resource/resource_manifest.example.json").read_text())
assert manifest["schema"] == "queuebash.display_resource_manifest.v1"
assert manifest["execution"] == "never"
assert manifest["renderer"] == "controlled_token_replacement_only"
assert manifest["json_contract_source"] is False
assert manifest["secret_rendering_allowed"] is False
assert manifest["shell_expansion_allowed"] is False
assert manifest["command_substitution_allowed"] is False
assert manifest["fallback_required"] is True
assert "QID" in manifest["tokens"]

catalog = json.loads((root / "schemas/display_resource/resource_catalog.example.json").read_text())
assert catalog["schema"] == "queuebash.display_resource_catalog.v1"
assert catalog["owner_lane"] == "bob18-display-resources"
assert catalog["json_contract_source"] is False
assert catalog["secret_rendering_allowed"] is False
assert {"eval", "source", "secret_values", "json_generation_from_template"}.issubset(set(catalog["forbidden"]))
assert any(r["type"] == "xml" and r["name"] == "job-card.example.xml" for r in catalog["resources"])

for rel in ("resources.d/display/manifest.example.tsv", "resources.d/xml/manifest.example.tsv"):
    rows = []
    with (root / rel).open(newline="") as fh:
        for line in fh:
            if not line.strip() or line.startswith("#"):
                continue
            rows.append(next(csv.reader([line], delimiter="\t")))
    assert rows, rel
    for row in rows:
        assert len(row) == 9, (rel, row)
        resource_type, name, language, fallback_required, tokens, surface, json_source, secret_allowed, notes = row
        assert resource_type in {"display", "xml"}, row
        assert language == "fallback" or language.startswith("lang_"), row
        assert fallback_required in {"yes", "no"}, row
        assert tokens == "none" or all(token.replace("_", "").isalnum() for token in tokens.split(",")), row
        assert json_source == "false", row
        assert secret_allowed == "false", row
        lowered = "\t".join(row).lower()
        for forbidden in ("$(`", "$(", "${", "<!entity", "<!doctype", "secret_value", "provider_credentials"):
            assert forbidden not in lowered, (rel, forbidden, row)

print("PASS display_resource_manifest_json_contract_static")
