#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
example = root / "examples/profiles/multisig/signatures.goodrexx.json.example"
doc = root / "docs/PROFILE_MULTISIGNATURE_CONTRACT.md"
q = root / "queuebash.sh"

data = json.loads(example.read_text())
assert data["schema"] == "queuebash.profile_signatures.v1"
assert isinstance(data["signatures"], list) and data["signatures"]
allowed_ns = {"self", "team", "org", "external", "trusted-ca"}
allowed_roles = {"author", "reviewer", "approver", "countersigner", "issuer", "auditor"}
for sig in data["signatures"]:
    assert sig["signer"].split(":", 1)[0] in allowed_ns
    assert sig["role"] in allowed_roles
    assert sig["alg"]
    assert len(sig["public_key_sha256"]) == 64
    assert sig["signature_b64"]
    assert "T" in sig["signed_at"]

text = q.read_text() + doc.read_text()
assert "queuebash.profile_signature_verification.v1" in text
assert "cryptographic_verification_performed" in text
assert "migration_required" in text
assert "/etc/bashqueues" not in doc.read_text()
print("PASS profile multi-signature JSON contract static")
