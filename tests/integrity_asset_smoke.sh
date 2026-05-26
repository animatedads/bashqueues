#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
mkdir -p "$QUEUEBASH_ROOT/assets.d" "$tmp/tree"
cp "$ROOT/assets.d/integrity.sh" "$QUEUEBASH_ROOT/assets.d/integrity.sh"
source "$ROOT/queuebash.sh"

payload="$tmp/payload.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo approved' > "$payload"
sha="$(sha256sum "$payload" | awk '{print $1}')"

out="$(_queue_asset_implied_preflight_args integrity:file_sha256 integrity file_sha256 "$payload" sha256="$sha")"
grep -q 'asset_check_ok: integrity:file_sha256' <<<"$out" || fail "file_sha256 did not pass approved file: $out"

printf '%s\n' 'echo changed' >> "$payload"
if _queue_asset_implied_preflight_args integrity:file_sha256 integrity file_sha256 "$payload" sha256="$sha" >/dev/null 2>&1; then
    fail "file_sha256 unexpectedly passed changed file"
fi

printf '%s\n' 'alpha' > "$tmp/tree/a.txt"
printf '%s\n' 'beta' > "$tmp/tree/b.txt"
sha_a="$(sha256sum "$tmp/tree/a.txt" | awk '{print $1}')"
sha_b="$(sha256sum "$tmp/tree/b.txt" | awk '{print $1}')"
manifest="$tmp/manifest.txt"
{
    echo '# approved payload manifest'
    printf '%s %s\n' "$sha_a" "$tmp/tree/a.txt"
    printf 'sha256 %s %s\n' "$tmp/tree/b.txt" "$sha_b"
} > "$manifest"
chmod 0644 "$manifest"

out="$(_queue_asset_implied_preflight_args integrity:manifest_verified integrity manifest_verified "$manifest" allow_user_manifest=1)"
grep -q 'asset_check_ok: integrity:manifest_verified' <<<"$out" || fail "manifest_verified did not pass: $out"

printf '%s\n' 'tampered' >> "$tmp/tree/b.txt"
if _queue_asset_implied_preflight_args integrity:manifest_verified integrity manifest_verified "$manifest" allow_user_manifest=1 >/dev/null 2>&1; then
    fail "manifest_verified unexpectedly passed changed file"
fi

printf '%s\n' 'beta' > "$tmp/tree/b.txt"
sha_b="$(sha256sum "$tmp/tree/b.txt" | awk '{print $1}')"
tree_manifest="$tmp/tree.manifest"
{
    printf '%s %s\n' "$sha_a" 'a.txt'
    printf '%s %s\n' "$sha_b" 'b.txt'
} > "$tree_manifest"
chmod 0644 "$tree_manifest"

out="$(_queue_asset_implied_preflight_args integrity:tree_manifest_verified integrity tree_manifest_verified "$tmp/tree" manifest="$tree_manifest" allow_user_manifest=1)"
grep -q 'asset_check_ok: integrity:tree_manifest_verified' <<<"$out" || fail "tree_manifest_verified did not pass: $out"

outside="$tmp/outside.txt"
printf '%s\n' 'outside' > "$outside"
sha_out="$(sha256sum "$outside" | awk '{print $1}')"
printf '%s %s\n' "$sha_out" "$outside" > "$tree_manifest"
if _queue_asset_implied_preflight_args integrity:tree_manifest_verified integrity tree_manifest_verified "$tmp/tree" manifest="$tree_manifest" allow_user_manifest=1 >/dev/null 2>&1; then
    fail "tree_manifest_verified unexpectedly allowed outside-tree path"
fi

user_manifest="$QUEUEBASH_ROOT/user.manifest"
printf '%s %s\n' "$sha_a" "$tmp/tree/a.txt" > "$user_manifest"
chmod 0644 "$user_manifest"
if _queue_asset_implied_preflight_args integrity:manifest_verified integrity manifest_verified "$user_manifest" >/dev/null 2>&1; then
    fail "manifest_verified unexpectedly allowed queue-root manifest without opt-in"
fi

out="$(_queue_asset_implied_preflight_args integrity:manifest_verified integrity manifest_verified "$user_manifest" allow_user_manifest=1)"
grep -q 'asset_check_ok: integrity:manifest_verified' <<<"$out" || fail "queue-root manifest did not pass with explicit opt-in: $out"

echo '[PASS] integrity asset smoke checks pass'
