#!/usr/bin/env python3
import json
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
for rel in ["schemas/secret_request.v1.example.json", "schemas/secret_provider_result.v1.example.json"]:
    payload = json.loads((root / rel).read_text())
    assert payload["schema"].startswith("queuebash.secret_")

with tempfile.TemporaryDirectory() as td:
    t = pathlib.Path(td)
    fixture = t / "fixtures"
    run = t / "run"
    fixture.mkdir()
    (fixture / "customer-db__prod__password.secret").write_text("not-a-secret-fixture-value")
    env = dict(**__import__("os").environ)
    env["QUEUEBASH_SECRETS_FILE_PROVIDER_DIR"] = str(fixture)
    env["QUEUEBASH_SECRET_RUN_DIR"] = str(run)
    env["QUEUEBASH_ROOT"] = str(t / "qroot")
    out = subprocess.check_output([
        "bash", str(root / "providers.d/secrets/secrets_provider.sh"),
        "request", "customer-db/prod/password", "--name", "db_password",
        "--class", "DB_MIGRATION", "--purpose", "approved test",
        "--qid", "jobjson", "--delivery", "file", "--json",
    ], env=env, text=True)
    data = json.loads(out)
    assert data["schema"] == "queuebash.secret_provider.result.v1"
    assert data["secret_value_included"] is False
    assert "not-a-secret-fixture-value" not in out

print("PASS secrets_provider_json_contract_static")
