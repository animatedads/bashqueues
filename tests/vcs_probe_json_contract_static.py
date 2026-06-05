#!/usr/bin/env python3
import json
import os
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
probe = root / "bin" / "queue-vcs-probe"
assert probe.exists(), "queue-vcs-probe missing"
subprocess.run(["bash", "-n", str(probe)], check=True)

with tempfile.TemporaryDirectory() as td:
    work = Path(td)
    cvs = work / "CVS"
    cvs.mkdir()
    (cvs / "Root").write_text("/legacy/cvsroot\n")
    (cvs / "Tag").write_text("TREL_2_0\n")
    raw = subprocess.check_output(["bash", str(probe), "--json", str(work)], text=True, cwd=root)
    data = json.loads(raw)

assert data["schema"] == "queuebash.vcs.probe.v1"
assert data["type"] == "cvs"
assert data["identity"] == "REL_2_0"
assert data["revision"] == "/legacy/cvsroot"
assert data["client"] == "cvs"
assert isinstance(data["client_available"], bool)
assert data["clean"] in (True, False, "unknown")
for key in ("path", "root", "marker", "status_summary"):
    assert key in data, f"missing {key}"

print("[PASS] VCS probe JSON contract is stable for legacy CVS metadata")
