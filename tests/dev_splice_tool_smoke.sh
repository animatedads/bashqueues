#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
# Keep the dev splice smoke focused and fast; installer behaviour is covered elsewhere.
_queue_install_bundled_classes(){ :; }
_queue_install_bundled_env_profiles(){ :; }
_queue_install_bundled_asset_plugins(){ :; }
_queue_install_bundled_reporter_plugins(){ :; }
_queue_install_bundled_cap_plugins(){ :; }
_queue_install_bundled_policies(){ :; }

tmpdir="$(mktemp -d)"
export QUEUEBASH_ROOT="$tmpdir/root"
trap 'rm -rf "$tmpdir"' EXIT

json_has(){ case "$2" in *"\"$1\":$3"*) return 0 ;; *) return 1 ;; esac; }
json_reason_is(){ case "$2" in *"\"reason\":\"$1\""*) return 0 ;; *) return 1 ;; esac; }

# insert after anchor works
f="$tmpdir/after.txt"
printf 'alpha beta' > "$f"
chmod 755 "$f"
out="$(_queue_dev_splice --file "$f" --after 'alpha' --insert ' inserted' --json)"
json_has changed "$out" true || fail "after insert did not report changed: $out"
grep -q 'alpha inserted beta' "$f" || fail 'after insert content missing'
[[ "$(stat -c '%a' "$f")" == "755" ]] || fail 'permissions not preserved after splice'

# insert before anchor works
f="$tmpdir/before.txt"
printf 'alpha beta' > "$f"
out="$(_queue_dev_splice --file "$f" --before 'beta' --insert 'before-beta ' --json)"
json_has changed "$out" true || fail "before insert did not report changed: $out"
grep -q 'alpha before-beta beta' "$f" || fail 'before insert content missing'

# replace one block works
f="$tmpdir/replace.txt"
printf 'one old three' > "$f"
out="$(_queue_dev_splice --file "$f" --replace 'old' --with 'new' --json)"
json_has changed "$out" true || fail "replace did not report changed: $out"
grep -q 'one new three' "$f" || fail 'replace content missing'

# dry-run does not modify
f="$tmpdir/dry.txt"
printf 'anchor' > "$f"
out="$(_queue_dev_splice --file "$f" --after 'anchor' --insert 'dry' --dry-run --json)"
json_reason_is dry_run "$out" || fail "dry-run reason wrong: $out"
! grep -q 'dry' "$f" || fail 'dry-run modified file'

# missing anchor fails clearly
f="$tmpdir/missing.txt"
printf 'alpha\n' > "$f"
if out="$(_queue_dev_splice --file "$f" --after 'not-there' --insert 'x' --json)"; then
  fail 'missing anchor unexpectedly succeeded'
fi
json_reason_is anchor_missing "$out" || fail "missing anchor reason wrong: $out"

# duplicate replace fails unless --all is used
f="$tmpdir/dupe.txt"
printf 'x old old' > "$f"
if out="$(_queue_dev_splice --file "$f" --replace 'old' --with 'new' --json)"; then
  fail 'duplicate replace unexpectedly succeeded without --all'
fi
json_reason_is replace_text_not_unique "$out" || fail "duplicate replace reason wrong: $out"
out="$(_queue_dev_splice --file "$f" --replace 'old' --with 'new' --all --json)"
[[ "$(grep -o 'new' "$f" | wc -l | tr -d ' ')" -eq 2 ]] || fail '--all did not replace both occurrences'

# --if-missing prevents duplicate insertion
f="$tmpdir/idempotent.txt"
printf 'anchor already' > "$f"
out="$(_queue_dev_splice --file "$f" --after 'anchor' --insert ' already' --if-missing 'already' --json)"
json_has skipped "$out" true || fail "if-missing did not skip: $out"
[[ "$(grep -o 'already' "$f" | wc -l | tr -d ' ')" -eq 1 ]] || fail 'if-missing duplicated content'

# file-based insert preserves trailing newline exactly
needle="$tmpdir/needle_newline.txt"; insert="$tmpdir/insert_newline.txt"; f="$tmpdir/filemode_newline.txt"
printf 'A\n' > "$needle"
printf 'INSERT\n' > "$insert"
printf 'A\nB\n' > "$f"
out="$(_queue_dev_splice --file "$f" --after-file "$needle" --insert-file "$insert" --json)"
json_has changed "$out" true || fail "file-based newline insert failed: $out"
expected="$tmpdir/expected_insert_newline.txt"; printf 'A\nINSERT\nB\n' > "$expected"; cmp -s "$expected" "$f" || fail "insert-file trailing newline was not preserved exactly"

# replace-file preserves trailing newline in the replace needle
oldfile="$tmpdir/old_with_newline.txt"; newfile="$tmpdir/new_without_newline.txt"; f="$tmpdir/replace_file_newline.txt"
printf 'AA\n' > "$oldfile"
printf 'CC' > "$newfile"
printf 'AA\nBB' > "$f"
out="$(_queue_dev_splice --file "$f" --replace-file "$oldfile" --with-file "$newfile" --json)"
json_has changed "$out" true || fail "replace-file newline splice failed: $out"
expected="$tmpdir/expected_replace_file_newline.txt"; printf 'CCBB' > "$expected"; cmp -s "$expected" "$f" || fail "replace-file trailing newline in needle was not preserved exactly"

# with-file preserves trailing newline in replacement text
oldfile="$tmpdir/old_no_newline.txt"; newfile="$tmpdir/new_with_newline.txt"; f="$tmpdir/with_file_newline.txt"
printf 'OLD' > "$oldfile"
printf 'NEW\n' > "$newfile"
printf 'OLDTAIL' > "$f"
out="$(_queue_dev_splice --file "$f" --replace-file "$oldfile" --with-file "$newfile" --json)"
json_has changed "$out" true || fail "with-file newline splice failed: $out"
expected="$tmpdir/expected_with_file_newline.txt"; printf 'NEW\nTAIL' > "$expected"; cmp -s "$expected" "$f" || fail "with-file trailing newline was not preserved exactly"

# replace without --with/--with-file fails clearly and does not delete text
f="$tmpdir/replace_without_with.txt"
printf 'keep old keep' > "$f"
if err="$(_queue_dev_splice --file "$f" --replace 'old' --json 2>&1)"; then
  fail 'replace without --with unexpectedly succeeded'
fi
case "$err" in *'requires explicit --with/--with-file'*) : ;; *) fail "replace without with error not clear: $err" ;; esac
grep -q 'keep old keep' "$f" || fail 'replace without with modified the file'

# file-based variant works
needle="$tmpdir/needle.txt"; insert="$tmpdir/insert.txt"; f="$tmpdir/filemode.txt"
printf 'ANCHOR' > "$needle"
printf '_VIA_FILE_' > "$insert"
printf 'ANCHOR\n' > "$f"
out="$(_queue_dev_splice --file "$f" --after-file "$needle" --insert-file "$insert" --json)"
json_has changed "$out" true || fail "file-based splice failed: $out"
grep -q 'ANCHOR_VIA_FILE_' "$f" || fail 'file-based insertion missing'

echo 'PASS dev_splice_tool_smoke'
