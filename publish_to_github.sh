#!/usr/bin/env bash
set -euo pipefail

repo_url="${1:-git@github.com:animatedads/bashqueues.git}"
workdir="${2:-/tmp/bashqueues_publish}"

rm -rf "$workdir"
git clone "$repo_url" "$workdir"

# Core project files
cp queuebash.sh queuemgr.sh README.md CHANGELOG.md COPYING_NOTE.md install.sh uninstall.sh "$workdir/"

# Documentation
rm -rf "$workdir/docs"
mkdir -p "$workdir/docs"
cp -a docs/. "$workdir/docs/"

# Bundled asset plugins
rm -rf "$workdir/assets.d"
mkdir -p "$workdir/assets.d"
cp -a assets.d/. "$workdir/assets.d/"
chmod +x "$workdir"/assets.d/*.sh 2>/dev/null || true

# Bundled classes
rm -rf "$workdir/classes"
mkdir -p "$workdir/classes"
cp -a classes/. "$workdir/classes/"

# Tests and helper fixtures
rm -rf "$workdir/tests"
mkdir -p "$workdir/tests"
cp -a tests/. "$workdir/tests/"

# Preserve / restore executable bits for shell scripts.
chmod +x "$workdir"/tests/*.sh 2>/dev/null || true
chmod +x "$workdir"/install.sh "$workdir"/uninstall.sh 2>/dev/null || true

cd "$workdir"

bash -n queuebash.sh

# Mandatory smoke test. Broader tests can be run by the operator before publish;
# this publish job should stay fast and safe for noninteractive queued use.
QUEUEBASH_ALLOW_NONINTERACTIVE=1 \
QUEUEBASH_SUBMIT_REASON_DEFAULT="publish selftest temporary queue under site policy" \
bash tests/selftest.sh

# If these newer focused tests exist, run the quick non-destructive ones too.
quick_tests=(
  tests/ipc_checksum.sh
  tests/ipc_submit_bind_qid.sh
  tests/ipc_systemd_inherited_envkeys.sh
  tests/queue_output_helper.sh
  tests/tail_options.sh
  tests/targeted_compression.sh
)

for t in "${quick_tests[@]}"; do
    if [[ -x "$t" ]]; then
        echo "Running $t"
        QUEUEBASH_ALLOW_NONINTERACTIVE=1 \
        QUEUEBASH_SUBMIT_REASON_DEFAULT="publish quick test temporary queue under site policy" \
        bash "$t"
    fi
done

git status

git add \
  queuebash.sh \
  README.md \
  CHANGELOG.md \
  COPYING_NOTE.md \
  install.sh \
  uninstall.sh \
  docs \
  assets.d \
  classes \
  tests

if git diff --cached --quiet; then
    echo "No changes to commit."
    exit 0
fi

version="$(grep -E '^QUEUEBASH_VERSION=' queuebash.sh | head -1 | cut -d= -f2- | tr -d '"')"
git commit -m "Update bashqueues ${version:-release}"
git push origin main
