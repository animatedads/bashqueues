#!/usr/bin/env bash
# qbtest_installer.sh — portable QBTEST block installer
# Contains 131 test blocks extracted from queuebash.sh
#
# Usage:
#   bash qbtest_installer.sh [--file QUEUEBASH_SH] [--force]
#
# Inserts each QBTEST block into the target file via:
#   queue dev test qbtest add --file FILE --function NAME --b64 PAYLOAD
# Skips blocks that already exist unless --force is given.
# Requires queuebash.sh to be sourced (done automatically from TARGET).

set -euo pipefail

TARGET="queuebash.sh"
FORCE_FLAG=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --file|-f) TARGET="${2:?--file requires a value}"; shift 2 ;;
        --force)   FORCE_FLAG="--force"; shift ;;
        --help|-h) echo "Usage: $0 [--file QUEUEBASH_SH] [--force]"; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

[[ -f "$TARGET" ]] || { echo "ERROR: file not found: $TARGET" >&2; exit 1; }
QUEUEBASH_ALLOW_NONINTERACTIVE=1 source "$TARGET" 2>/dev/null || {
    echo "ERROR: failed to source $TARGET" >&2; exit 1
}

echo "qbtest_installer: 131 blocks -> $TARGET"
_qi_pass=0; _qi_skip=0; _qi_fail=0

if queue dev test qbtest add --file "$TARGET" \
    --function _over_quote_cmd --name over-quote-cmd \
    --lang bash --b64 b3V0PSIkKF9vdmVyX3F1b3RlX2NtZCBoZWxsbyB3b3JsZCkiCltbICIkb3V0IiA9PSAiIGhlbGxvIHdvcmxkIiBdXQpvdXQyPSIkKF9vdmVyX3F1b3RlX2NtZCAiaGFzIHNwYWNlIiAiYSZiIikiCltbICIkb3V0MiIgPT0gKiJoYXNcIHNwYWNlIiogXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _over_quote_cmd"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _over_quote_cmd"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _over_quote_cmd rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_root --name queue-root \
    --lang bash --b64 cj0iJChfcXVldWVfcm9vdCkiCltbIC1uICIkciIgXV0KIyBFbnYgb3ZlcnJpZGUKUVVFVUVCQVNIX1NFTEVDVEVEX1JPT1Q9L3RtcC90ZXN0X3Jvb3QKcjI9IiQoX3F1ZXVlX3Jvb3QpIgpbWyAiJHIyIiA9PSAiL3RtcC90ZXN0X3Jvb3QiIF1dCnVuc2V0IFFVRVVFQkFTSF9TRUxFQ1RFRF9ST09U \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_root"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_root"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_root rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_bundled_script_dir --name bundled-script-dir \
    --lang bash --b64 ZD0iJChfcXVldWVfYnVuZGxlZF9zY3JpcHRfZGlyKSIKW1sgLW4gIiRkIiBdXQpbWyAtZCAiJGQiIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_bundled_script_dir"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_bundled_script_dir"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_bundled_script_dir rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_now --name queue-now-format \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9ub3cpIgpbWyAiJG91dCIgPX4gXlswLTldezh9X1swLTldezZ9JCBdXQo= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_now"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_now"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_now rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_now_nonce --name now-nonce \
    --lang bash --b64 bjE9IiQoX3F1ZXVlX25vd19ub25jZSkiCm4yPSIkKF9xdWV1ZV9ub3dfbm9uY2UpIgpbWyAtbiAiJG4xIiBdXQpbWyAiJG4xIiA9fiBeWzAtOV0rJCBdXQpbWyAkeyNuMX0gLWdlIDEwIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_now_nonce"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_now_nonce"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_now_nonce rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_id --name queue-id \
    --lang bash --b64 aWQ9IiQoX3F1ZXVlX2lkKSIKW1sgLW4gIiRpZCIgXV0KW1sgIiRpZCIgPX4gXlswLTldezh9X1swLTldezZ9XyBdXQppZDI9IiQoX3F1ZXVlX2lkKSIKW1sgIiRpZCIgIT0gIiRpZDIiIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_id"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_id"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_id rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_name --name job-name \
    --lang bash --b64 dG1wPSQobWt0ZW1wKQplY2hvICJKT0JfTkFNRT1teWpvYiIgPiAiJHRtcCIKW1sgIiQoX3F1ZXVlX2pvYl9uYW1lICIkdG1wIikiID09ICJteWpvYiIgXV0KIyBNaXNzaW5nIGZpZWxkIHJldHVybnMgZW1wdHkKZWNobyAiUFJJT1JJVFk9NSIgPiAiJHRtcCIKW1sgLXogIiQoX3F1ZXVlX2pvYl9uYW1lICIkdG1wIikiIF1dCnJtIC1mICIkdG1wIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_name"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_name"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_name rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_pri --name job-pri \
    --lang bash --b64 dG1wPSQobWt0ZW1wKQplY2hvICJQUklPUklUWT01IiA+ICIkdG1wIgpbWyAiJChfcXVldWVfam9iX3ByaSAiJHRtcCIpIiA9PSAiNSIgXV0KIyBEZWZhdWx0IDEwCmVjaG8gIkpPQl9OQU1FPXgiID4gIiR0bXAiCltbICIkKF9xdWV1ZV9qb2JfcHJpICIkdG1wIikiID09ICIxMCIgXV0KIyBOb24tbnVtZXJpYyBzdHJpcHBlZCwgZGVmYXVsdAplY2hvICJQUklPUklUWT1hYmMiID4gIiR0bXAiCltbICIkKF9xdWV1ZV9qb2JfcHJpICIkdG1wIikiID09ICIxMCIgXV0Kcm0gLWYgIiR0bXAi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_pri"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_pri"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_pri rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_pending_bucket_key --name pending-bucket-key \
    --lang bash --b64 az0iJChfcXVldWVfcGVuZGluZ19idWNrZXRfa2V5IDEwKSIKW1sgIiRrIiA9fiBecFswLTldezEwfSQgXV0KIyBIaWdoZXIgcHJpb3JpdHkgLT4gbG93ZXIgYnVja2V0IGtleSB2YWx1ZSAoc29ydGVkIGVhcmxpZXIpCmsxMD0iJChfcXVldWVfcGVuZGluZ19idWNrZXRfa2V5IDEwKSIKazIwPSIkKF9xdWV1ZV9wZW5kaW5nX2J1Y2tldF9rZXkgMjApIgpbWyAiJGsyMCIgPCAiJGsxMCIgXV0KIyBJbnZhbGlkIC0+IGRlZmF1bHRzIHRvIDEwCmtfaW52PSIkKF9xdWV1ZV9wZW5kaW5nX2J1Y2tldF9rZXkgbm90YW51bWJlcikiCltbICIka19pbnYiID09ICIkazEwIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_pending_bucket_key"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_pending_bucket_key"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_pending_bucket_key rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_pending_path_for_priority --name pending-path-for-priority \
    --lang bash --b64 cD0iJChfcXVldWVfcGVuZGluZ19wYXRoX2Zvcl9wcmlvcml0eSBteWpvYmlkIDEwKSIKW1sgIiRwIiA9PSAqL3BlbmRpbmcvKiBdXQpbWyAiJHAiID09ICpteWpvYmlkLmpvYiBdXQojIERpZmZlcmVudCBwcmlvcml0aWVzIHByb2R1Y2UgZGlmZmVyZW50IHBhdGhzCnAxMD0iJChfcXVldWVfcGVuZGluZ19wYXRoX2Zvcl9wcmlvcml0eSB4IDEwKSIKcDIwPSIkKF9xdWV1ZV9wZW5kaW5nX3BhdGhfZm9yX3ByaW9yaXR5IHggMjApIgpbWyAiJHAxMCIgIT0gIiRwMjAiIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_pending_path_for_priority"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_pending_path_for_priority"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_pending_path_for_priority rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_pending_path_by_id --name job-pending-path-by-id \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCm1rZGlyIC1wICIkcm9vdC9wZW5kaW5nIgojIENyZWF0ZSBhIGtub3duIGpvYiBmaWxlCmppZD0idGVzdGpvYl93YXZlNl94eXp6eSIKanBhdGg9IiRyb290L3BlbmRpbmcvJGppZC5qb2IiCmVjaG8gIkpPQl9OQU1FPSRqaWQiID4gIiRqcGF0aCIKZm91bmQ9IiQoX3F1ZXVlX2pvYl9wZW5kaW5nX3BhdGhfYnlfaWQgIiRqaWQiKSIKW1sgIiRmb3VuZCIgPT0gIiRqcGF0aCIgXV0Kcm0gLWYgIiRqcGF0aCIKIyBOb24tZXhpc3RlbnQgaWQgLT4gZW1wdHkvZmFpbAohIF9xdWV1ZV9qb2JfcGVuZGluZ19wYXRoX2J5X2lkICJub19zdWNoX2pvYl94eXp6eV85OSIgMj4vZGV2L251bGwKIyBFbXB0eSBpZCAtPiBmYWlsCiEgX3F1ZXVlX2pvYl9wZW5kaW5nX3BhdGhfYnlfaWQgIiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_pending_path_by_id"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_pending_path_by_id"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_pending_path_by_id rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_is_pending_path --name job-is-pending-path \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCl9xdWV1ZV9qb2JfaXNfcGVuZGluZ19wYXRoICIkcm9vdC9wZW5kaW5nL215am9iLmpvYiIKX3F1ZXVlX2pvYl9pc19wZW5kaW5nX3BhdGggIiRyb290L3BlbmRpbmcvcDA5OTk5OTk5OTAvbXlqb2Iuam9iIgohIF9xdWV1ZV9qb2JfaXNfcGVuZGluZ19wYXRoICIkcm9vdC9kb25lL215am9iLmpvYiIKISBfcXVldWVfam9iX2lzX3BlbmRpbmdfcGF0aCAiL3NvbWUvb3RoZXIvcGF0aC5qb2IiCiEgX3F1ZXVlX2pvYl9pc19wZW5kaW5nX3BhdGggIiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_is_pending_path"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_is_pending_path"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_is_pending_path rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_state_for_job_path --name state-for-job-path \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCltbICIkKF9xdWV1ZV9zdGF0ZV9mb3Jfam9iX3BhdGggIiRyb290L3BlbmRpbmcveC5qb2IiKSIgPT0gInBlbmRpbmciIF1dCltbICIkKF9xdWV1ZV9zdGF0ZV9mb3Jfam9iX3BhdGggIiRyb290L2RvbmUveC5qb2IiKSIgPT0gImRvbmUiIF1dCltbICIkKF9xdWV1ZV9zdGF0ZV9mb3Jfam9iX3BhdGggIiRyb290L2ZhaWxlZC94LmpvYiIpIiA9PSAiZmFpbGVkIiBdXQpbWyAiJChfcXVldWVfc3RhdGVfZm9yX2pvYl9wYXRoICIkcm9vdC9jYW5jZWxsZWQveC5qb2IiKSIgPT0gImNhbmNlbGxlZCIgXV0KW1sgIiQoX3F1ZXVlX3N0YXRlX2Zvcl9qb2JfcGF0aCAiL3Vua25vd24veC5qb2IiKSIgPT0gInVua25vd24iIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_state_for_job_path"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_state_for_job_path"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_state_for_job_path rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_field_fast --name job-field-fast \
    --lang bash --b64 dG1wPSQobWt0ZW1wKQpwcmludGYgJ0pPQl9OQU1FPWhlbGxvXG5QUklPUklUWT03XG4nID4gIiR0bXAiCltbICIkKF9xdWV1ZV9qb2JfZmllbGRfZmFzdCAiJHRtcCIgSk9CX05BTUUpIiA9PSAiaGVsbG8iIF1dCltbICIkKF9xdWV1ZV9qb2JfZmllbGRfZmFzdCAiJHRtcCIgUFJJT1JJVFkpIiA9PSAiNyIgXV0Kb3V0PSIkKF9xdWV1ZV9qb2JfZmllbGRfZmFzdCAiJHRtcCIgTk9TVUNIS0VZIHx8IHRydWUpIgpbWyAteiAiJG91dCIgXV0KISBfcXVldWVfam9iX2ZpZWxkX2Zhc3QgIi90bXAvbm9fc3VjaF9maWxlX3h5enp5LmpvYiIgSk9CX05BTUUKcm0gLWYgIiR0bXAi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_field_fast"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_field_fast"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_field_fast rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_exact_name_count --name exact-name-count \
    --lang bash --b64 dDE9JChta3RlbXApOyB0Mj0kKG1rdGVtcCk7IHQzPSQobWt0ZW1wKQplY2hvICJKT0JfTkFNRT1hbHBoYSIgPiAiJHQxIgplY2hvICJKT0JfTkFNRT1iZXRhIiAgPiAiJHQyIgplY2hvICJKT0JfTkFNRT1hbHBoYSIgPiAiJHQzIgpbWyAiJChfcXVldWVfZXhhY3RfbmFtZV9jb3VudCBhbHBoYSAiJHQxIiAiJHQyIiAiJHQzIikiID09ICIyIiBdXQpbWyAiJChfcXVldWVfZXhhY3RfbmFtZV9jb3VudCBiZXRhICIkdDEiICIkdDIiICIkdDMiKSIgPT0gIjEiIF1dCltbICIkKF9xdWV1ZV9leGFjdF9uYW1lX2NvdW50IGdhbW1hICIkdDEiICIkdDIiICIkdDMiKSIgPT0gIjAiIF1dCnJtIC1mICIkdDEiICIkdDIiICIkdDMi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_exact_name_count"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_exact_name_count"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_exact_name_count rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_has_array --name job-has-array \
    --lang bash --b64 dG1wPSQobWt0ZW1wIC0tc3VmZml4PS5qb2IpCiMgRmlsZSB3aXRoIHBvcHVsYXRlZCBhcnJheQpwcmludGYgJ01ZX0FSUkFZPShhIGIgYylcbicgPiAiJHRtcCIKX3F1ZXVlX2pvYl9oYXNfYXJyYXkgIiR0bXAiIE1ZX0FSUkFZCiMgRmlsZSB3aXRoIGVtcHR5IGFycmF5CnByaW50ZiAnTVlfQVJSQVk9KClcbicgPiAiJHRtcCIKISBfcXVldWVfam9iX2hhc19hcnJheSAiJHRtcCIgTVlfQVJSQVkKIyBNaXNzaW5nIGZpbGUKISBfcXVldWVfam9iX2hhc19hcnJheSAiL3RtcC9ub19zdWNoX2ZpbGVfeHl6enkuam9iIiBNWV9BUlJBWQpybSAtZiAiJHRtcCI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_has_array"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_has_array"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_has_array rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_dep_token_done --name dep-token-done \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCm1rZGlyIC1wICIkcm9vdC9kb25lIgp0bXA9IiRyb290L2RvbmUvdGVzdHRva2VuX3h5enp5X2RvbmUuam9iIgp0b3VjaCAiJHRtcCIKX3F1ZXVlX2RlcF90b2tlbl9kb25lICJ0ZXN0dG9rZW5feHl6enlfZG9uZSIKcm0gLWYgIiR0bXAiCiMgTm9uLWV4aXN0ZW50IHRva2VuIGZhaWxzCiEgX3F1ZXVlX2RlcF90b2tlbl9kb25lICJub19zdWNoX3Rva2VuX3h5enp5Xzk5IgojIEVtcHR5IHRva2VuIGZhaWxzCiEgX3F1ZXVlX2RlcF90b2tlbl9kb25lICIi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_dep_token_done"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_dep_token_done"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_dep_token_done rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_dep_token_failed_or_cancelled --name dep-token-failed-or-cancelled \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCm1rZGlyIC1wICIkcm9vdC9mYWlsZWQiCnRtcD0iJHJvb3QvZmFpbGVkL2ZhaWx0b2tlbl94eXp6eS5qb2IiCnRvdWNoICIkdG1wIgpfcXVldWVfZGVwX3Rva2VuX2ZhaWxlZF9vcl9jYW5jZWxsZWQgImZhaWx0b2tlbl94eXp6eSIKcm0gLWYgIiR0bXAiCiMgTm9uLWV4aXN0ZW50IC0+IGZhbHNlCiEgX3F1ZXVlX2RlcF90b2tlbl9mYWlsZWRfb3JfY2FuY2VsbGVkICJub19zdWNoX3Rva2VuX3h5enp5Xzk5Ig== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_dep_token_failed_or_cancelled"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_dep_token_failed_or_cancelled"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_dep_token_failed_or_cancelled rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_dependency_tokens --name job-dependency-tokens \
    --lang bash --b64 dG1wPSQobWt0ZW1wKQplY2hvICdERVBFTkRTX0FGVEVSX1NVQ0NFU1M9dG9rMSB0b2syJyA+ICIkdG1wIgpvdXQ9IiQoX3F1ZXVlX2pvYl9kZXBlbmRlbmN5X3Rva2VucyAiJHRtcCIpIgpbWyAiJG91dCIgPT0gInRvazEgdG9rMiIgXV0KIyBObyBkZXBzIC0+IGVtcHR5CmVjaG8gIkpPQl9OQU1FPXgiID4gIiR0bXAiCm91dD0iJChfcXVldWVfam9iX2RlcGVuZGVuY3lfdG9rZW5zICIkdG1wIiB8fCB0cnVlKSIKW1sgLXogIiRvdXQiIF1dCnJtIC1mICIkdG1wIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_dependency_tokens"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_dependency_tokens"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_dependency_tokens rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_dependencies_satisfied --name job-dependencies-satisfied \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCm1rZGlyIC1wICIkcm9vdC9kb25lIgojIE5vIGRlcHMgLT4gc2F0aXNmaWVkCnRtcD0kKG1rdGVtcCAtLXN1ZmZpeD0uam9iKQplY2hvICJKT0JfTkFNRT1ub2RlcHMiID4gIiR0bXAiCl9xdWV1ZV9qb2JfZGVwZW5kZW5jaWVzX3NhdGlzZmllZCAiJHRtcCIKIyBBbGwgZGVwcyBkb25lIC0+IHNhdGlzZmllZAplY2hvICJERVBFTkRTX0FGVEVSX1NVQ0NFU1M9ZG9uZV90b2tfeHl6enkiID4gIiR0bXAiCnRvdWNoICIkcm9vdC9kb25lL2RvbmVfdG9rX3h5enp5LmpvYiIKX3F1ZXVlX2pvYl9kZXBlbmRlbmNpZXNfc2F0aXNmaWVkICIkdG1wIgpybSAtZiAiJHJvb3QvZG9uZS9kb25lX3Rva194eXp6eS5qb2IiCiMgTWlzc2luZyBkZXAgLT4gbm90IHNhdGlzZmllZAplY2hvICJERVBFTkRTX0FGVEVSX1NVQ0NFU1M9bWlzc2luZ190b2tfeHl6enkiID4gIiR0bXAiCiEgX3F1ZXVlX2pvYl9kZXBlbmRlbmNpZXNfc2F0aXNmaWVkICIkdG1wIgpybSAtZiAiJHRtcCI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_dependencies_satisfied"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_dependencies_satisfied"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_dependencies_satisfied rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_dependencies_status --name job-dependencies-status \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCm1rZGlyIC1wICIkcm9vdC9kb25lIgp0bXA9JChta3RlbXAgLS1zdWZmaXg9LmpvYikKIyBObyBkZXBzIC0+IG5vbmUKZWNobyAiSk9CX05BTUU9bm9kZXBzIiA+ICIkdG1wIgpbWyAiJChfcXVldWVfam9iX2RlcGVuZGVuY2llc19zdGF0dXMgIiR0bXAiKSIgPT0gIm5vbmUiIF1dCiMgQWxsIGRvbmUgLT4gc2F0aXNmaWVkCmVjaG8gIkRFUEVORFNfQUZURVJfU1VDQ0VTUz1kb25lX3Rva193Nl94eXp6eSIgPiAiJHRtcCIKdG91Y2ggIiRyb290L2RvbmUvZG9uZV90b2tfdzZfeHl6enkuam9iIgpvdXQ9IiQoX3F1ZXVlX2pvYl9kZXBlbmRlbmNpZXNfc3RhdHVzICIkdG1wIikiCltbICIkb3V0IiA9PSAic2F0aXNmaWVkIiB8fCAiJG91dCIgPT0gKmRvbmUqIF1dCnJtIC1mICIkcm9vdC9kb25lL2RvbmVfdG9rX3c2X3h5enp5LmpvYiIKcm0gLWYgIiR0bXAi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_dependencies_status"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_dependencies_status"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_dependencies_status rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_dependencies_blocked --name job-dependencies-blocked \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCm1rZGlyIC1wICIkcm9vdC9kb25lIiAiJHJvb3QvZmFpbGVkIgp0bXA9JChta3RlbXAgLS1zdWZmaXg9LmpvYikKIyBObyBkZXBzIC0+IG5vdCBibG9ja2VkCmVjaG8gIkpPQl9OQU1FPW5vZGVwcyIgPiAiJHRtcCIKISBfcXVldWVfam9iX2RlcGVuZGVuY2llc19ibG9ja2VkICIkdG1wIgojIERlcCBmYWlsZWQgLT4gYmxvY2tlZAplY2hvICJERVBFTkRTX0FGVEVSX1NVQ0NFU1M9ZmFpbF90b2tfeHl6enkiID4gIiR0bXAiCnRvdWNoICIkcm9vdC9mYWlsZWQvZmFpbF90b2tfeHl6enkuam9iIgpfcXVldWVfam9iX2RlcGVuZGVuY2llc19ibG9ja2VkICIkdG1wIgpybSAtZiAiJHJvb3QvZmFpbGVkL2ZhaWxfdG9rX3h5enp5LmpvYiIKcm0gLWYgIiR0bXAi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_dependencies_blocked"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_dependencies_blocked"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_dependencies_blocked rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_now_epoch --name now-epoch \
    --lang bash --b64 ZT0iJChfcXVldWVfbm93X2Vwb2NoKSIKW1sgIiRlIiA9fiBeWzAtOV0rJCBdXQpbWyAiJGUiIC1ndCAxMDAwMDAwMDAwIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_now_epoch"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_now_epoch"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_now_epoch rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_now_iso --name now-iso \
    --lang bash --b64 dD0iJChfcXVldWVfbm93X2lzbykiCltbIC1uICIkdCIgXV0KW1sgIiR0IiA9fiBeWzAtOV17NH0tWzAtOV17Mn0tWzAtOV17Mn1UWzAtOV17Mn06WzAtOV17Mn06WzAtOV17Mn0gXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_now_iso"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_now_iso"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_now_iso rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_parse_delay_seconds --name parse-delay-seconds \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX3BhcnNlX2RlbGF5X3NlY29uZHMgMzApIiA9PSAiMzAiIF1dCltbICIkKF9xdWV1ZV9wYXJzZV9kZWxheV9zZWNvbmRzIDJtKSIgPT0gIjEyMCIgXV0KW1sgIiQoX3F1ZXVlX3BhcnNlX2RlbGF5X3NlY29uZHMgMCkiID09ICIwIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_parse_delay_seconds"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_parse_delay_seconds"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_parse_delay_seconds rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_parse_at_epoch --name parse-at-epoch \
    --lang bash --b64 IyBQbGFpbiBpbnRlZ2VyIHBhc3N0aHJvdWdoCmU9IiQoX3F1ZXVlX3BhcnNlX2F0X2Vwb2NoIDE3MDAwMDAwMDApIgpbWyAiJGUiID09ICIxNzAwMDAwMDAwIiBdXQojIEludmFsaWQgc3RyaW5nIHNob3VsZCBmYWlsCiEgX3F1ZXVlX3BhcnNlX2F0X2Vwb2NoICJub3RhZGF0ZSIgMj4vZGV2L251bGwgfHwgdHJ1ZQojIEVtcHR5IHNob3VsZCBmYWlsCiEgX3F1ZXVlX3BhcnNlX2F0X2Vwb2NoICIiIDI+L2Rldi9udWxs \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_parse_at_epoch"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_parse_at_epoch"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_parse_at_epoch rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_not_before_epoch --name job-not-before-epoch \
    --lang bash --b64 dG1wPSQobWt0ZW1wKQplY2hvICJOT1RfQkVGT1JFX0VQT0NIPTE3MDAwMDAwMDAiID4gIiR0bXAiCltbICIkKF9xdWV1ZV9qb2Jfbm90X2JlZm9yZV9lcG9jaCAiJHRtcCIpIiA9PSAiMTcwMDAwMDAwMCIgXV0KIyBSRVRSWV9OT1RfQkVGT1JFX0VQT0NIIHdpbnMgd2hlbiBsYXJnZXIKZWNobyAtZSAiTk9UX0JFRk9SRV9FUE9DSD0xMDBcblJFVFJZX05PVF9CRUZPUkVfRVBPQ0g9MjAwIiA+ICIkdG1wIgpbWyAiJChfcXVldWVfam9iX25vdF9iZWZvcmVfZXBvY2ggIiR0bXAiKSIgPT0gIjIwMCIgXV0KIyBEZWZhdWx0IDAgd2hlbiBtaXNzaW5nCmVjaG8gIkpPQl9OQU1FPXgiID4gIiR0bXAiCltbICIkKF9xdWV1ZV9qb2Jfbm90X2JlZm9yZV9lcG9jaCAiJHRtcCIpIiA9PSAiMCIgXV0Kcm0gLWYgIiR0bXAi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_not_before_epoch"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_not_before_epoch"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_not_before_epoch rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_schedule_due --name job-schedule-due \
    --lang bash --b64 dG1wPSQobWt0ZW1wKQojIER1ZSBpbiBwYXN0IC0+IHJldHVybnMgMCAoZHVlKQplY2hvICJOT1RfQkVGT1JFX0VQT0NIPTEiID4gIiR0bXAiCl9xdWV1ZV9qb2Jfc2NoZWR1bGVfZHVlICIkdG1wIgojIER1ZSBmYXIgaW4gZnV0dXJlIC0+IHJldHVybnMgMSAobm90IGR1ZSkKZWNobyAiTk9UX0JFRk9SRV9FUE9DSD05OTk5OTk5OTk5IiA+ICIkdG1wIgohIF9xdWV1ZV9qb2Jfc2NoZWR1bGVfZHVlICIkdG1wIgpybSAtZiAiJHRtcCI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_schedule_due"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_schedule_due"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_schedule_due rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_job_schedule_status --name job-schedule-status \
    --lang bash --b64 dG1wPSQobWt0ZW1wIC0tc3VmZml4PS5qb2IpCiMgUGFzdCBlcG9jaCAtPiBkdWUKZWNobyAiTk9UX0JFRk9SRV9FUE9DSD0xIiA+ICIkdG1wIgpbWyAiJChfcXVldWVfam9iX3NjaGVkdWxlX3N0YXR1cyAiJHRtcCIpIiA9PSAiZHVlIiBdXQojIEZhciBmdXR1cmUgLT4gb3ZlcmR1ZS93YWl0aW5nIHN0cmluZwplY2hvICJOT1RfQkVGT1JFX0VQT0NIPTk5OTk5OTk5OTkiID4gIiR0bXAiCm91dD0iJChfcXVldWVfam9iX3NjaGVkdWxlX3N0YXR1cyAiJHRtcCIpIgpbWyAiJG91dCIgIT0gImR1ZSIgXV0Kcm0gLWYgIiR0bXAi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_job_schedule_status"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_job_schedule_status"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_job_schedule_status rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_name_for_job --name class-name-for-job \
    --lang bash --b64 dG1wPSQobWt0ZW1wKQplY2hvICJKT0JfQ0xBU1M9TVlDTEFTUyIgPiAiJHRtcCIKW1sgIiQoX3F1ZXVlX2NsYXNzX25hbWVfZm9yX2pvYiAiJHRtcCIpIiA9PSAiTVlDTEFTUyIgXV0KIyBEZWZhdWx0IHdoZW4gbm8gY2xhc3Mgc2V0CmVjaG8gIkpPQl9OQU1FPXRlc3QiID4gIiR0bXAiCm91dD0iJChfcXVldWVfY2xhc3NfbmFtZV9mb3Jfam9iICIkdG1wIikiCltbICIkb3V0IiA9PSAiREVGQVVMVCIgfHwgLW4gIiRvdXQiIF1dCnJtIC1mICIkdG1wIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_name_for_job"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_name_for_job"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_name_for_job rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_safe_token --name class-safe-token \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2NsYXNzX3NhZmVfdG9rZW4gJ2hlbGxvJykiID09ICJoZWxsbyIgXV0KW1sgIiQoX3F1ZXVlX2NsYXNzX3NhZmVfdG9rZW4gJ2EgYicpIiA9PSAiYV9iIiBdXQpbWyAiJChfcXVldWVfY2xhc3Nfc2FmZV90b2tlbiAnZm9vL2JhcicpIiA9PSAiZm9vX2JhciIgXV0KW1sgIiQoX3F1ZXVlX2NsYXNzX3NhZmVfdG9rZW4gJ0E6Qi5DLUQnKSIgPT0gIkE6Qi5DLUQiIF1dCltbICIkKF9xdWV1ZV9jbGFzc19zYWZlX3Rva2VuICcnKSIgPT0gIiIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_safe_token"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_safe_token"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_safe_token rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_plugin_path --name class-plugin-path \
    --lang bash --b64 IyBGdWxsIHBhdGggcGFzc3Rocm91Z2ggd2hlbiBmaWxlIGV4aXN0cwp0bXA9JChta3RlbXAgLS1zdWZmaXg9LnNoKQpbWyAiJChfcXVldWVfY2xhc3NfcGx1Z2luX3BhdGggIiR0bXAiKSIgPT0gIiR0bXAiIF1dCnJtIC1mICIkdG1wIgojIFBsdWdpbiBuYW1lIC0+IGNvbnN0cnVjdHMgcGF0aCB1bmRlciBjbGFzcy5kCnA9IiQoX3F1ZXVlX2NsYXNzX3BsdWdpbl9wYXRoICJteXBsdWdpbiIpIgpbWyAiJHAiID09ICpjbGFzcy5kL215cGx1Z2luIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_plugin_path"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_plugin_path"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_plugin_path rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_check_function_name --name asset-check-function-name \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9hc3NldF9jaGVja19mdW5jdGlvbl9uYW1lIGF3cyBzM19hY2Nlc3MpIgpbWyAiJG91dCIgPT0gInF1ZXVlX2Fzc2V0X2NoZWNrX2F3c19zM19hY2Nlc3MiIF1dCiMgU2FuaXRpc2VzIHNwZWNpYWwgY2hhcnMKb3V0PSIkKF9xdWV1ZV9hc3NldF9jaGVja19mdW5jdGlvbl9uYW1lICJteS1mYW1pbHkiICJteS1jaGVjayIpIgpbWyAiJG91dCIgPT0gInF1ZXVlX2Fzc2V0X2NoZWNrX215X2ZhbWlseV9teV9jaGVjayIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_check_function_name"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_check_function_name"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_check_function_name rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_facility_valid_name --name asset-facility-valid-name \
    --lang bash --b64 X3F1ZXVlX2Fzc2V0X2ZhY2lsaXR5X3ZhbGlkX25hbWUgJ2F3czpzM19hY2Nlc3MnCl9xdWV1ZV9hc3NldF9mYWNpbGl0eV92YWxpZF9uYW1lICdteV9mYW1pbHk6bXlfY2hlY2snCl9xdWV1ZV9hc3NldF9mYWNpbGl0eV92YWxpZF9uYW1lICdBOkInCiEgX3F1ZXVlX2Fzc2V0X2ZhY2lsaXR5X3ZhbGlkX25hbWUgJ25vY29kb24nCiEgX3F1ZXVlX2Fzc2V0X2ZhY2lsaXR5X3ZhbGlkX25hbWUgJ2hhcy1oeXBoZW46Y2hlY2snCiEgX3F1ZXVlX2Fzc2V0X2ZhY2lsaXR5X3ZhbGlkX25hbWUgJycKISBfcXVldWVfYXNzZXRfZmFjaWxpdHlfdmFsaWRfbmFtZSAnOm5vcHJlZml4Jw== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_facility_valid_name"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_facility_valid_name"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_facility_valid_name rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_helper_path --name asset-helper-path \
    --lang bash --b64 IyBGdWxsIHBhdGggcGFzc3Rocm91Z2ggd2hlbiBmaWxlIGV4aXN0cwp0bXA9JChta3RlbXAgLS1zdWZmaXg9LnNoKQpbWyAiJChfcXVldWVfYXNzZXRfaGVscGVyX3BhdGggIiR0bXAiKSIgPT0gIiR0bXAiIF1dCnJtIC1mICIkdG1wIgojIE5vbi1wYXRoIGZhbWlseSAtPiBjb25zdHJ1Y3RzIHBhdGggdW5kZXIgYXNzZXRzLmQKcD0iJChfcXVldWVfYXNzZXRfaGVscGVyX3BhdGggImF3cyIpIgpbWyAiJHAiID09ICphc3NldHMuZC9hd3Muc2ggXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_helper_path"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_helper_path"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_helper_path rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_facility_is_published --name asset-facility-is-published \
    --lang bash --b64 IyBTb3VyY2UgYSBtaW5pbWFsIGhlbHBlciB0aGF0IHB1Ymxpc2hlcyBhIHRlc3QgZmFjaWxpdHkKdG1waGVscGVyPSQobWt0ZW1wIC0tc3VmZml4PS5zaCkKY2F0ID4gIiR0bXBoZWxwZXIiIDw8J0hFTFBFUkVPRicKcXVldWVfYXNzZXRfZmFjaWxpdGllcygpIHsgcHJpbnRmICd0ZXN0X2ZhbTp0ZXN0X2NoZWNrXHRUZXN0XG4nOyB9CkhFTFBFUkVPRgpzb3VyY2UgIiR0bXBoZWxwZXIiCl9xdWV1ZV9hc3NldF9mYWNpbGl0eV9pc19wdWJsaXNoZWQgInRlc3RfZmFtIiAidGVzdF9jaGVjayIKISBfcXVldWVfYXNzZXRfZmFjaWxpdHlfaXNfcHVibGlzaGVkICJ0ZXN0X2ZhbSIgIm5vX3N1Y2giCiEgX3F1ZXVlX2Fzc2V0X2ZhY2lsaXR5X2lzX3B1Ymxpc2hlZCAibm9fc3VjaCIgInRlc3RfY2hlY2siCnJtIC1mICIkdG1waGVscGVyIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_facility_is_published"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_facility_is_published"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_facility_is_published rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_family_valid_name --name asset-family-valid-name \
    --lang bash --b64 X3F1ZXVlX2Fzc2V0X2ZhbWlseV92YWxpZF9uYW1lICJhd3MiCl9xdWV1ZV9hc3NldF9mYW1pbHlfdmFsaWRfbmFtZSAibXlfZmFtaWx5IgpfcXVldWVfYXNzZXRfZmFtaWx5X3ZhbGlkX25hbWUgIl91bmRlciIKISBfcXVldWVfYXNzZXRfZmFtaWx5X3ZhbGlkX25hbWUgImhhcy1oeXBoZW4iCiEgX3F1ZXVlX2Fzc2V0X2ZhbWlseV92YWxpZF9uYW1lICIxYmFkIgohIF9xdWV1ZV9hc3NldF9mYW1pbHlfdmFsaWRfbmFtZSAiIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_family_valid_name"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_family_valid_name"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_family_valid_name rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_archive_dir --name class-archive-dir \
    --lang bash --b64 ZD0iJChfcXVldWVfY2xhc3NfYXJjaGl2ZV9kaXIpIgpbWyAtbiAiJGQiIF1dCltbICIkZCIgPT0gKmFyY2hpdmUqIF1dCltbICIkZCIgPT0gKmNsYXNzZXMqIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_archive_dir"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_archive_dir"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_archive_dir rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_backup_dir --name class-backup-dir \
    --lang bash --b64 ZD0iJChfcXVldWVfY2xhc3NfYmFja3VwX2RpcikiCltbIC1uICIkZCIgXV0KW1sgIiRkIiA9PSAqYmFja3VwKiBdXQpbWyAiJGQiID09ICpjbGFzc2VzKiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_backup_dir"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_backup_dir"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_backup_dir rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_valid_name --name class-valid-name \
    --lang bash --b64 X3F1ZXVlX2NsYXNzX3ZhbGlkX25hbWUgIkRFRkFVTFQiCl9xdWV1ZV9jbGFzc192YWxpZF9uYW1lICJteV9jbGFzcyIKX3F1ZXVlX2NsYXNzX3ZhbGlkX25hbWUgIkNsYXNzLTEiCl9xdWV1ZV9jbGFzc192YWxpZF9uYW1lICJfdW5kZXIiCiEgX3F1ZXVlX2NsYXNzX3ZhbGlkX25hbWUgIjFiYWQiCiEgX3F1ZXVlX2NsYXNzX3ZhbGlkX25hbWUgImhhcyBzcGFjZSIKISBfcXVldWVfY2xhc3NfdmFsaWRfbmFtZSAiIgohIF9xdWV1ZV9jbGFzc192YWxpZF9uYW1lICJoYXMvc2xhc2gi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_valid_name"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_valid_name"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_valid_name rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_latest_backup --name class-latest-backup \
    --lang bash --b64 ZGlyPSIkKF9xdWV1ZV9jbGFzc19iYWNrdXBfZGlyKSIKbWtkaXIgLXAgIiRkaXIiCm91dD0iJChfcXVldWVfY2xhc3NfbGF0ZXN0X2JhY2t1cCAibm9fc3VjaF9jbGFzc194eXp6eSIgfHwgdHJ1ZSkiCltbIC16ICIkb3V0IiBdXQp0b3VjaCAiJGRpci9URVNUQ0xBU1NfVzZELjIwMjYwMTAxMTIwMDAwLmVudiIKb3V0PSIkKF9xdWV1ZV9jbGFzc19sYXRlc3RfYmFja3VwICJURVNUQ0xBU1NfVzZEIikiCltbICIkb3V0IiA9PSAqVEVTVENMQVNTX1c2RCogXV0Kcm0gLWYgIiRkaXIvVEVTVENMQVNTX1c2RC4yMDI2MDEwMTEyMDAwMC5lbnYi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_latest_backup"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_latest_backup"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_latest_backup rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_latest_archive --name class-latest-archive \
    --lang bash --b64 ZGlyPSIkKF9xdWV1ZV9jbGFzc19hcmNoaXZlX2RpcikiCm1rZGlyIC1wICIkZGlyIgojIE5vIGFyY2hpdmVzIC0+IGVtcHR5Cm91dD0iJChfcXVldWVfY2xhc3NfbGF0ZXN0X2FyY2hpdmUgIm5vX3N1Y2hfY2xhc3NfeHl6enkiIHx8IHRydWUpIgpbWyAteiAiJG91dCIgXV0KIyBDcmVhdGUgYSBmYWtlIGFyY2hpdmUKdG91Y2ggIiRkaXIvVEVTVENMQVNTX1c2LjIwMjYwMTAxMTIwMDAwLmVudiIKb3V0PSIkKF9xdWV1ZV9jbGFzc19sYXRlc3RfYXJjaGl2ZSAiVEVTVENMQVNTX1c2IikiCltbICIkb3V0IiA9PSAqVEVTVENMQVNTX1c2KiBdXQpybSAtZiAiJGRpci9URVNUQ0xBU1NfVzYuMjAyNjAxMDExMjAwMDAuZW52Ig== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_latest_archive"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_latest_archive"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_latest_archive rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_backups --name class-backups \
    --lang bash --b64 ZGlyPSIkKF9xdWV1ZV9jbGFzc19iYWNrdXBfZGlyKSIKbWtkaXIgLXAgIiRkaXIiCiMgRW1wdHkgcmVzdWx0IGZvciB1bmtub3duIGNsYXNzCm91dD0iJChfcXVldWVfY2xhc3NfYmFja3VwcyAibm9fc3VjaF9jbGFzc194eXp6eSIgfHwgdHJ1ZSkiCltbIC16ICIkb3V0IiBdXQojIENyZWF0ZSBhIGZha2UgYmFja3VwCnRvdWNoICIkZGlyL1RFU1RDTEFTU19XNkIuMjAyNjAxMDExMjAwMDAuZW52IgpvdXQ9IiQoX3F1ZXVlX2NsYXNzX2JhY2t1cHMgIlRFU1RDTEFTU19XNkIiKSIKW1sgIiRvdXQiID09ICpURVNUQ0xBU1NfVzZCKiBdXQpybSAtZiAiJGRpci9URVNUQ0xBU1NfVzZCLjIwMjYwMTAxMTIwMDAwLmVudiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_backups"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_backups"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_backups rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_archives --name class-archives \
    --lang bash --b64 ZGlyPSIkKF9xdWV1ZV9jbGFzc19hcmNoaXZlX2RpcikiCm1rZGlyIC1wICIkZGlyIgpvdXQ9IiQoX3F1ZXVlX2NsYXNzX2FyY2hpdmVzICJub19zdWNoX2NsYXNzX3h5enp5IiB8fCB0cnVlKSIKW1sgLXogIiRvdXQiIF1dCnRvdWNoICIkZGlyL1RFU1RDTEFTU19XNkMuMjAyNjAxMDExMjAwMDAuZW52IgpvdXQ9IiQoX3F1ZXVlX2NsYXNzX2FyY2hpdmVzICJURVNUQ0xBU1NfVzZDIikiCltbICIkb3V0IiA9PSAqVEVTVENMQVNTX1c2QyogXV0Kcm0gLWYgIiRkaXIvVEVTVENMQVNTX1c2Qy4yMDI2MDEwMTEyMDAwMC5lbnYi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_archives"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_archives"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_archives rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_class_name_from_file --name class-name-from-file \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2NsYXNzX25hbWVfZnJvbV9maWxlICcvcGF0aC90by9ERUZBVUxULmVudicpIiA9PSAiREVGQVVMVCIgXV0KW1sgIiQoX3F1ZXVlX2NsYXNzX25hbWVfZnJvbV9maWxlICdNeUNsYXNzLmVudicpIiA9PSAiTXlDbGFzcyIgXV0KW1sgIiQoX3F1ZXVlX2NsYXNzX25hbWVfZnJvbV9maWxlICdfdW5kZXIuZW52JykiID09ICJfdW5kZXIiIF1dCiEgX3F1ZXVlX2NsYXNzX25hbWVfZnJvbV9maWxlICIxYmFkLmVudiIKISBfcXVldWVfY2xhc3NfbmFtZV9mcm9tX2ZpbGUgImhhcy1zcGFjZSAuZW52Ig== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_class_name_from_file"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_class_name_from_file"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_class_name_from_file rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_env_valid_name --name env-valid-name \
    --lang bash --b64 X3F1ZXVlX2Vudl92YWxpZF9uYW1lICJteWVudiIKX3F1ZXVlX2Vudl92YWxpZF9uYW1lICJteS5lbnYiCl9xdWV1ZV9lbnZfdmFsaWRfbmFtZSAibXktZW52X3YyIgpfcXVldWVfZW52X3ZhbGlkX25hbWUgIjEyM2FiYyIKISBfcXVldWVfZW52X3ZhbGlkX25hbWUgImhhcyBzcGFjZSIKISBfcXVldWVfZW52X3ZhbGlkX25hbWUgIiIKISBfcXVldWVfZW52X3ZhbGlkX25hbWUgImhhcy9zbGFzaCI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_env_valid_name"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_env_valid_name"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_env_valid_name rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_env_dir --name env-dir \
    --lang bash --b64 ZD0iJChfcXVldWVfZW52X2RpcikiCltbIC1uICIkZCIgXV0KW1sgIiRkIiA9PSAqZW52cy5kIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_env_dir"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_env_dir"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_env_dir rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_check_uses_legacy_token_target_contract --name asset-uses-legacy-contract \
    --lang bash --b64 IyBEZWZpbmUgYSBmdW5jdGlvbiB1c2luZyBsZWdhY3kgY29udHJhY3Q6IGxvY2FsIHRva2VuPSIkMSI7IHNoaWZ0IDIKX3Rlc3RfbGVnYWN5X2ZuKCkgeyBsb2NhbCB0b2tlbj0iJDEiOyBsb2NhbCB0YXJnZXQ9IiQyIjsgc2hpZnQgMiB8fCB0cnVlOyBlY2hvICIkdG9rZW4iOyB9Cl9xdWV1ZV9hc3NldF9jaGVja191c2VzX2xlZ2FjeV90b2tlbl90YXJnZXRfY29udHJhY3QgIl90ZXN0X2xlZ2FjeV9mbiIKIyBGdW5jdGlvbiB3aXRob3V0IGxlZ2FjeSBwYXR0ZXJuIGZhaWxzCl90ZXN0X21vZGVybl9mbigpIHsgbG9jYWwgY2hlY2s9IiQxIjsgZWNobyAiJGNoZWNrIjsgfQohIF9xdWV1ZV9hc3NldF9jaGVja191c2VzX2xlZ2FjeV90b2tlbl90YXJnZXRfY29udHJhY3QgIl90ZXN0X21vZGVybl9mbiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_check_uses_legacy_token_target_contract"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_check_uses_legacy_token_target_contract"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_check_uses_legacy_token_target_contract rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_archive_dir --name asset-archive-dir \
    --lang bash --b64 ZD0iJChfcXVldWVfYXNzZXRfYXJjaGl2ZV9kaXIpIgpbWyAtbiAiJGQiIF1dCltbICIkZCIgPT0gKmFzc2V0cy5kLy5hcmNoaXZlIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_archive_dir"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_archive_dir"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_archive_dir rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_latest_archive_for_family --name asset-latest-archive-for-family \
    --lang bash --b64 ZGlyPSIkKF9xdWV1ZV9hc3NldF9hcmNoaXZlX2RpcikiCm1rZGlyIC1wICIkZGlyIgpvdXQ9IiQoX3F1ZXVlX2Fzc2V0X2xhdGVzdF9hcmNoaXZlX2Zvcl9mYW1pbHkgIm5vX3N1Y2hfZmFtaWx5X3h5enp5IiB8fCB0cnVlKSIKW1sgLXogIiRvdXQiIF1dCnRvdWNoICIkZGlyL3Rlc3RmYW1fdzguMjAyNjAxMDExMjAwMDAuc2giCm91dD0iJChfcXVldWVfYXNzZXRfbGF0ZXN0X2FyY2hpdmVfZm9yX2ZhbWlseSAidGVzdGZhbV93OCIpIgpbWyAiJG91dCIgPT0gKnRlc3RmYW1fdzgqIF1dCnJtIC1mICIkZGlyL3Rlc3RmYW1fdzguMjAyNjAxMDExMjAwMDAuc2gi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_latest_archive_for_family"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_latest_archive_for_family"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_latest_archive_for_family rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_list_archives --name asset-list-archives \
    --lang bash --b64 ZGlyPSIkKF9xdWV1ZV9hc3NldF9hcmNoaXZlX2RpcikiCm1rZGlyIC1wICIkZGlyIgpvdXQ9IiQoX3F1ZXVlX2Fzc2V0X2xpc3RfYXJjaGl2ZXMgIm5vX3N1Y2hfZmFtaWx5X3h5enp5IiB8fCB0cnVlKSIKW1sgLXogIiRvdXQiIF1dCnRvdWNoICIkZGlyL2xpc3RmYW1fdzguMjAyNjAxMDExMjAwMDAuc2giCm91dD0iJChfcXVldWVfYXNzZXRfbGlzdF9hcmNoaXZlcyAibGlzdGZhbV93OCIpIgpbWyAiJG91dCIgPT0gKmxpc3RmYW1fdzgqIF1dCnJtIC1mICIkZGlyL2xpc3RmYW1fdzguMjAyNjAxMDExMjAwMDAuc2gi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_list_archives"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_list_archives"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_list_archives rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_replace_backup_dir --name asset-replace-backup-dir \
    --lang bash --b64 ZD0iJChfcXVldWVfYXNzZXRfcmVwbGFjZV9iYWNrdXBfZGlyKSIKW1sgLW4gIiRkIiBdXQpbWyAiJGQiID09ICphc3NldHMuZC8uYmFja3VwIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_replace_backup_dir"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_replace_backup_dir"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_replace_backup_dir rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_latest_backup_for_family --name asset-latest-backup-for-family \
    --lang bash --b64 ZGlyPSIkKF9xdWV1ZV9hc3NldF9yZXBsYWNlX2JhY2t1cF9kaXIpIgpta2RpciAtcCAiJGRpciIKb3V0PSIkKF9xdWV1ZV9hc3NldF9sYXRlc3RfYmFja3VwX2Zvcl9mYW1pbHkgIm5vX3N1Y2hfZmFtaWx5X3h5enp5IiB8fCB0cnVlKSIKW1sgLXogIiRvdXQiIF1dCnRvdWNoICIkZGlyL3Rlc3RmYW1fdzhiLjIwMjYwMTAxMTIwMDAwLnNoIgpvdXQ9IiQoX3F1ZXVlX2Fzc2V0X2xhdGVzdF9iYWNrdXBfZm9yX2ZhbWlseSAidGVzdGZhbV93OGIiIHx8IHRydWUpIgpbWyAiJG91dCIgPT0gKnRlc3RmYW1fdzhiKiBdXQpybSAtZiAiJGRpci90ZXN0ZmFtX3c4Yi4yMDI2MDEwMTEyMDAwMC5zaCI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_latest_backup_for_family"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_latest_backup_for_family"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_latest_backup_for_family rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_list_backups --name asset-list-backups \
    --lang bash --b64 ZGlyPSIkKF9xdWV1ZV9hc3NldF9yZXBsYWNlX2JhY2t1cF9kaXIpIgpta2RpciAtcCAiJGRpciIKb3V0PSIkKF9xdWV1ZV9hc3NldF9saXN0X2JhY2t1cHMgIm5vX3N1Y2hfZmFtaWx5X3h5enp5IiB8fCB0cnVlKSIKW1sgLXogIiRvdXQiIF1dCnRvdWNoICIkZGlyL2xpc3RmYW1fdzhiLjIwMjYwMTAxMTIwMDAwLnNoIgpvdXQ9IiQoX3F1ZXVlX2Fzc2V0X2xpc3RfYmFja3VwcyAibGlzdGZhbV93OGIiKSIKW1sgIiRvdXQiID09ICpsaXN0ZmFtX3c4YiogXV0Kcm0gLWYgIiRkaXIvbGlzdGZhbV93OGIuMjAyNjAxMDExMjAwMDAuc2gi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_list_backups"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_list_backups"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_list_backups rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_asset_plugin_looks_like_plugin --name asset-plugin-looks-like-plugin \
    --lang bash --b64 dG1wPSQobWt0ZW1wIC0tc3VmZml4PS5zaCkKY2F0ID4gIiR0bXAiIDw8J1BMVUdFT0YnCnF1ZXVlX2Fzc2V0X2ZhY2lsaXRpZXMoKSB7IGVjaG8gIm15ZmFtOm15Y2hlY2siOyB9CnF1ZXVlX2Fzc2V0X2NoZWNrX215ZmFtX215Y2hlY2soKSB7IGVjaG8gImFzc2V0X2NoZWNrX29rOiAkMSI7IH0KUExVR0VPRgpfcXVldWVfYXNzZXRfcGx1Z2luX2xvb2tzX2xpa2VfcGx1Z2luICIkdG1wIgpjYXQgPiAiJHRtcCIgPDwnUExVR0VPRicKcXVldWVfYXNzZXRfZmFjaWxpdGllcygpIHsgZWNobyAibXlmYW06bXljaGVjayI7IH0KUExVR0VPRgohIF9xdWV1ZV9hc3NldF9wbHVnaW5fbG9va3NfbGlrZV9wbHVnaW4gIiR0bXAiCiEgX3F1ZXVlX2Fzc2V0X3BsdWdpbl9sb29rc19saWtlX3BsdWdpbiAiL3RtcC9ub19zdWNoX3BsdWdpbl94eXp6eS5zaCIKcm0gLWYgIiR0bXAi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_asset_plugin_looks_like_plugin"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_asset_plugin_looks_like_plugin"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_asset_plugin_looks_like_plugin rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_global_root --name global-root \
    --lang bash --b64 cD0iJChfcXVldWVfZ2xvYmFsX3Jvb3QpIgpbWyAtbiAiJHAiIF1dCltbICIkcCIgPT0gKmJhc2hxdWV1ZXMqIHx8ICIkcCIgPT0gKmdsb2JhbCogXV0KZXhwb3J0IFFVRVVFQkFTSF9HTE9CQUxfUk9PVD0vdG1wL3Rlc3RfZ2xvYmFsX3Jvb3QKcDI9IiQoX3F1ZXVlX2dsb2JhbF9yb290KSIKW1sgIiRwMiIgPT0gIi90bXAvdGVzdF9nbG9iYWxfcm9vdCIgXV0KdW5zZXQgUVVFVUVCQVNIX0dMT0JBTF9ST09U \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_global_root"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_global_root"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_global_root rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_global_claim_policy --name global-claim-policy \
    --lang bash --b64 dW5zZXQgUVVFVUVCQVNIX0dMT0JBTF9DTEFJTV9QT0xJQ1kKcD0iJChfcXVldWVfZ2xvYmFsX2NsYWltX3BvbGljeSkiCltbIC1uICIkcCIgXV0KZXhwb3J0IFFVRVVFQkFTSF9HTE9CQUxfQ0xBSU1fUE9MSUNZPXBlcm1pc3NpdmUKW1sgIiQoX3F1ZXVlX2dsb2JhbF9jbGFpbV9wb2xpY3kpIiA9PSAicGVybWlzc2l2ZSIgXV0KdW5zZXQgUVVFVUVCQVNIX0dMT0JBTF9DTEFJTV9QT0xJQ1k= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_global_claim_policy"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_global_claim_policy"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_global_claim_policy rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_global_enabled --name global-enabled \
    --lang bash --b64 dW5zZXQgUVVFVUVCQVNIX0dMT0JBTF9DTEFJTVMKX3F1ZXVlX2dsb2JhbF9lbmFibGVkCmV4cG9ydCBRVUVVRUJBU0hfR0xPQkFMX0NMQUlNUz0xCl9xdWV1ZV9nbG9iYWxfZW5hYmxlZApleHBvcnQgUVVFVUVCQVNIX0dMT0JBTF9DTEFJTVM9MAohIF9xdWV1ZV9nbG9iYWxfZW5hYmxlZApleHBvcnQgUVVFVUVCQVNIX0dMT0JBTF9DTEFJTVM9b2ZmCiEgX3F1ZXVlX2dsb2JhbF9lbmFibGVkCnVuc2V0IFFVRVVFQkFTSF9HTE9CQUxfQ0xBSU1T \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_global_enabled"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_global_enabled"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_global_enabled rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_global_hash --name global-hash \
    --lang bash --b64 aD0iJChfcXVldWVfZ2xvYmFsX2hhc2ggInRlc3RrZXkiKSIKW1sgLW4gIiRoIiBdXQpbWyAiJHsjaH0iIC1nZSA4IF1dCmgyPSIkKF9xdWV1ZV9nbG9iYWxfaGFzaCAidGVzdGtleSIpIgpbWyAiJGgiID09ICIkaDIiIF1dCmgzPSIkKF9xdWV1ZV9nbG9iYWxfaGFzaCAiZGlmZmVyZW50IikiCltbICIkaCIgIT0gIiRoMyIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_global_hash"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_global_hash"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_global_hash rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_global_slots_from_args --name global-slots-from-args \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2dsb2JhbF9zbG90c19mcm9tX2FyZ3MgMykiID09ICIzIiBdXQpbWyAiJChfcXVldWVfZ2xvYmFsX3Nsb3RzX2Zyb21fYXJncyAzIHNsb3RzPTUpIiA9PSAiNSIgXV0KW1sgIiQoX3F1ZXVlX2dsb2JhbF9zbG90c19mcm9tX2FyZ3MgMyBvdGhlcj14IHNsb3RzPTIpIiA9PSAiMiIgXV0KW1sgIiQoX3F1ZXVlX2dsb2JhbF9zbG90c19mcm9tX2FyZ3MgMCkiID09ICIxIiBdXQpbWyAiJChfcXVldWVfZ2xvYmFsX3Nsb3RzX2Zyb21fYXJncyAiIikiID09ICIxIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_global_slots_from_args"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_global_slots_from_args"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_global_slots_from_args rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_global_claim_holder_state --name global-claim-holder-state \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCm1rZGlyIC1wICIkcm9vdC9kb25lIgp0b3VjaCAiJHJvb3QvZG9uZS90ZXN0cWlkX3c5LmpvYiIKW1sgIiQoX3F1ZXVlX2dsb2JhbF9jbGFpbV9ob2xkZXJfc3RhdGUgIiRyb290IiAidGVzdHFpZF93OSIpIiA9PSAiZG9uZSIgXV0Kcm0gLWYgIiRyb290L2RvbmUvdGVzdHFpZF93OS5qb2IiCltbICIkKF9xdWV1ZV9nbG9iYWxfY2xhaW1faG9sZGVyX3N0YXRlICIkcm9vdCIgIm5vX3N1Y2hfcWlkX3h5enp5X3c5IikiID09ICJtaXNzaW5nIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_global_claim_holder_state"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_global_claim_holder_state"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_global_claim_holder_state rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_global_claim_holder_count --name global-claim-holder-count \
    --lang bash --b64 dG1wPSQobWt0ZW1wKQpwcmludGYgJ0hPTERFUlx0cWlkMVx0cnVubmluZ1x0L3Jvb3QvLnF1ZXVlYmFzaFxuJyA+ICIkdG1wIgpwcmludGYgJ0hPTERFUlx0cWlkMlx0cnVubmluZ1x0L3Jvb3QvLnF1ZXVlYmFzaFxuJyA+PiAiJHRtcCIKcHJpbnRmICdNRVRBXHRjbGFpbVx0dmFsXG4nID4+ICIkdG1wIgpbWyAiJChfcXVldWVfZ2xvYmFsX2NsYWltX2hvbGRlcl9jb3VudCAiJHRtcCIpIiA9PSAiMiIgXV0KZWNobyAiIiA+ICIkdG1wIgpbWyAiJChfcXVldWVfZ2xvYmFsX2NsYWltX2hvbGRlcl9jb3VudCAiJHRtcCIpIiA9PSAiMCIgXV0Kcm0gLWYgIiR0bXAi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_global_claim_holder_count"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_global_claim_holder_count"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_global_claim_holder_count rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_normalize_systemd_cpu_quota --name normalize-cpu-quota \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX25vcm1hbGl6ZV9zeXN0ZW1kX2NwdV9xdW90YSAnNTAlJykiID09ICI1MCUiIF1dCltbICIkKF9xdWV1ZV9ub3JtYWxpemVfc3lzdGVtZF9jcHVfcXVvdGEgJzUwJykiID09ICI1MCUiIF1dCltbICIkKF9xdWV1ZV9ub3JtYWxpemVfc3lzdGVtZF9jcHVfcXVvdGEgJzEuNScpIiA9PSAiMS41JSIgXV0KW1sgIiQoX3F1ZXVlX25vcm1hbGl6ZV9zeXN0ZW1kX2NwdV9xdW90YSAnMS41JScpIiA9PSAiMS41JSIgXV0KX3F1ZXVlX25vcm1hbGl6ZV9zeXN0ZW1kX2NwdV9xdW90YSAiIiAmJiBlY2hvIG9rIHx8IGVjaG8gb2s= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_normalize_systemd_cpu_quota"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_normalize_systemd_cpu_quota"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_normalize_systemd_cpu_quota rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_json_escape --name json-escape-basic \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2pzb25fZXNjYXBlICdoZWxsbycpIiA9PSAnaGVsbG8nIF1dCltbICIkKF9xdWV1ZV9qc29uX2VzY2FwZSAnc2F5ICJoaSInKSIgPT0gJ3NheSBcImhpXCInIF1dCltbICIkKF9xdWV1ZV9qc29uX2VzY2FwZSAnYVxiJykiID09ICdhXFxiJyBdXQpvdXQ9IiQoX3F1ZXVlX2pzb25fZXNjYXBlICQnbGluZTFcbmxpbmUyJykiCltbICIkb3V0IiA9PSAkJ2xpbmUxXFxubGluZTInIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_json_escape"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_json_escape"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_json_escape rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_csv_contains_word --name csv-contains-word \
    --lang bash --b64 X3F1ZXVlX2Nzdl9jb250YWluc193b3JkICJhLGIsYyIgImIiCl9xdWV1ZV9jc3ZfY29udGFpbnNfd29yZCAiZm9vLGJhciIgImZvbyIKISBfcXVldWVfY3N2X2NvbnRhaW5zX3dvcmQgImEsYixjIiAiZCIKX3F1ZXVlX2Nzdl9jb250YWluc193b3JkICIqIiAiYW55dGhpbmciCiEgX3F1ZXVlX2Nzdl9jb250YWluc193b3JkICJhLGIiICIi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_csv_contains_word"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_csv_contains_word"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_csv_contains_word rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_epoch_now --name epoch-now \
    --lang bash --b64 ZT0iJChfcXVldWVfZXBvY2hfbm93KSIKW1sgIiRlIiA9fiBeWzAtOV0rJCBdXQpbWyAiJGUiIC1ndCAxMDAwMDAwMDAwIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_epoch_now"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_epoch_now"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_epoch_now rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_parse_size_to_bytes --name parse-size-to-bytes \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX3BhcnNlX3NpemVfdG9fYnl0ZXMgMUspIiA9PSAiMTAyNCIgXV0KW1sgIiQoX3F1ZXVlX3BhcnNlX3NpemVfdG9fYnl0ZXMgMk0pIiA9PSAiJCgoMioxMDI0KjEwMjQpKSIgXV0KW1sgIiQoX3F1ZXVlX3BhcnNlX3NpemVfdG9fYnl0ZXMgMUcpIiA9PSAiJCgoMTAyNCoxMDI0KjEwMjQpKSIgXV0KW1sgIiQoX3F1ZXVlX3BhcnNlX3NpemVfdG9fYnl0ZXMgNTEyKSIgPT0gIjUxMiIgXV0KW1sgIiQoX3F1ZXVlX3BhcnNlX3NpemVfdG9fYnl0ZXMgIiIpIiA9PSAiMCIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_parse_size_to_bytes"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_parse_size_to_bytes"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_parse_size_to_bytes rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_duration_to_seconds --name duration-to-seconds \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2R1cmF0aW9uX3RvX3NlY29uZHMgMTBzKSIgPT0gIjEwIiBdXQpbWyAiJChfcXVldWVfZHVyYXRpb25fdG9fc2Vjb25kcyAybSkiID09ICIxMjAiIF1dCltbICIkKF9xdWV1ZV9kdXJhdGlvbl90b19zZWNvbmRzIDFoKSIgPT0gIjM2MDAiIF1dCltbICIkKF9xdWV1ZV9kdXJhdGlvbl90b19zZWNvbmRzIDUwMG1zKSIgPT0gIjEiIF1dCltbICIkKF9xdWV1ZV9kdXJhdGlvbl90b19zZWNvbmRzIDEwMDBtcykiID09ICIxIiBdXQpbWyAiJChfcXVldWVfZHVyYXRpb25fdG9fc2Vjb25kcyAxNTAwbXMpIiA9PSAiMiIgXV0KISBfcXVldWVfZHVyYXRpb25fdG9fc2Vjb25kcyAiIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_duration_to_seconds"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_duration_to_seconds"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_duration_to_seconds rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_seconds_to_duration --name seconds-to-duration \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX3NlY29uZHNfdG9fZHVyYXRpb24gMTApIiA9PSAiMTBzIiBdXQpbWyAiJChfcXVldWVfc2Vjb25kc190b19kdXJhdGlvbiAwKSIgPT0gIjBzIiBdXQohIF9xdWV1ZV9zZWNvbmRzX3RvX2R1cmF0aW9uICJhYmMiCiEgX3F1ZXVlX3NlY29uZHNfdG9fZHVyYXRpb24gIiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_seconds_to_duration"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_seconds_to_duration"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_seconds_to_duration rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_cap_plugin_dirs --name cap-plugin-dirs \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9jYXBfcGx1Z2luX2RpcnMgfHwgdHJ1ZSkiCltbIC1uICIkb3V0IiBdXQplY2hvICIkb3V0IiB8IGdyZXAgLXEgImNhcHMuZCIKIyBFbnYgb3ZlcnJpZGUgYWRkcyBleHRyYSBkaXIKZXhwb3J0IFFVRVVFQkFTSF9DQVBfUExVR0lOX1NPVVJDRV9ESVI9L3RtcC90ZXN0X2NhcHMKb3V0Mj0iJChfcXVldWVfY2FwX3BsdWdpbl9kaXJzIHx8IHRydWUpIgplY2hvICIkb3V0MiIgfCBncmVwIC1xICIvdG1wL3Rlc3RfY2FwcyIKdW5zZXQgUVVFVUVCQVNIX0NBUF9QTFVHSU5fU09VUkNFX0RJUg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_cap_plugin_dirs"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_cap_plugin_dirs"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_cap_plugin_dirs rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_parse_bytes --name parse-bytes \
    --lang bash --b64 Yj0iJChfcXVldWVfcGFyc2VfYnl0ZXMgMTAyNCkiCltbICIkYiIgPX4gXlswLTldKyQgXV0KW1sgIiRiIiAtZ2UgMTAyNCBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_parse_bytes"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_parse_bytes"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_parse_bytes rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_policy_words_merge_unique --name policy-words-merge-unique \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9wb2xpY3lfd29yZHNfbWVyZ2VfdW5pcXVlICJhIGIgYyIgImIgYyBkIikiCltbICIkb3V0IiA9PSAiYSBiIGMgZCIgXV0Kb3V0Mj0iJChfcXVldWVfcG9saWN5X3dvcmRzX21lcmdlX3VuaXF1ZSAiIiAieCB5IikiCltbICIkb3V0MiIgPT0gInggeSIgXV0Kb3V0Mz0iJChfcXVldWVfcG9saWN5X3dvcmRzX21lcmdlX3VuaXF1ZSAiZm9vIiAiIikiCltbICIkb3V0MyIgPT0gImZvbyIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_policy_words_merge_unique"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_policy_words_merge_unique"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_policy_words_merge_unique rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_security_sandbox_rank --name security-sandbox-rank \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX3NlY3VyaXR5X3NhbmRib3hfcmFuayBvZmYpIiA9PSAiMCIgXV0KW1sgIiQoX3F1ZXVlX3NlY3VyaXR5X3NhbmRib3hfcmFuayBub25lKSIgPT0gIjAiIF1dCltbICIkKF9xdWV1ZV9zZWN1cml0eV9zYW5kYm94X3JhbmsgbmV0d29yay1ub25lKSIgPT0gIjIiIF1dCltbICIkKF9xdWV1ZV9zZWN1cml0eV9zYW5kYm94X3Jhbmsgc3RyaWN0KSIgPT0gIjMiIF1dCltbICIkKF9xdWV1ZV9zZWN1cml0eV9zYW5kYm94X3JhbmsgcXVldWUtZGVmYXVsdCkiID09ICIxIiBdXQpbWyAiJChfcXVldWVfc2VjdXJpdHlfc2FuZGJveF9yYW5rIHVua25vd25feHl6KSIgPT0gIjAiIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_security_sandbox_rank"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_security_sandbox_rank"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_security_sandbox_rank rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_security_seccomp_rank --name security-seccomp-rank \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX3NlY3VyaXR5X3NlY2NvbXBfcmFuayBvZmYpIiA9PSAiMCIgXV0KW1sgIiQoX3F1ZXVlX3NlY3VyaXR5X3NlY2NvbXBfcmFuayBzdHJpY3QpIiA9PSAiMiIgXV0KW1sgIiQoX3F1ZXVlX3NlY3VyaXR5X3NlY2NvbXBfcmFuayBkb2NrZXItZGVmYXVsdCkiID09ICIxIiBdXQpbWyAiJChfcXVldWVfc2VjdXJpdHlfc2VjY29tcF9yYW5rIHF1ZXVlLWRlZmF1bHQpIiA9PSAiMSIgXV0KW1sgIiQoX3F1ZXVlX3NlY3VyaXR5X3NlY2NvbXBfcmFuayB1bmtub3duX3h5eikiID09ICIwIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_security_seccomp_rank"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_security_seccomp_rank"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_security_seccomp_rank rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_authorisation_normalise_code --name authorisation-normalise-code \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2F1dGhvcmlzYXRpb25fbm9ybWFsaXNlX2NvZGUgImFiYyIpIiA9PSAiQUJDIiBdXQpbWyAiJChfcXVldWVfYXV0aG9yaXNhdGlvbl9ub3JtYWxpc2VfY29kZSAiQTFCMkMiKSIgPT0gIkExQjJDIiBdXQpbWyAiJChfcXVldWVfYXV0aG9yaXNhdGlvbl9ub3JtYWxpc2VfY29kZSAieHkiKSIgPT0gIlhZIiBdXQohIF9xdWV1ZV9hdXRob3Jpc2F0aW9uX25vcm1hbGlzZV9jb2RlICIiCiEgX3F1ZXVlX2F1dGhvcmlzYXRpb25fbm9ybWFsaXNlX2NvZGUgIlRPT0xPTkciCiEgX3F1ZXVlX2F1dGhvcmlzYXRpb25fbm9ybWFsaXNlX2NvZGUgImhhcy1kYXNoIgohIF9xdWV1ZV9hdXRob3Jpc2F0aW9uX25vcm1hbGlzZV9jb2RlICJoYXMgc3BhY2Ui \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_authorisation_normalise_code"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_authorisation_normalise_code"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_authorisation_normalise_code rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_command_shell_words_from_args --name command-shell-words-from-args \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9jb21tYW5kX3NoZWxsX3dvcmRzX2Zyb21fYXJncyBlY2hvICdhbHBoYSBiZXRhJyAnJEhPTUUnKSIKW1sgIiRvdXQiID09IGVjaG8qIF1dCltbICIkb3V0IiA9PSAqImFscGhhXCBiZXRhIiogXV0KW1sgIiRvdXQiID09ICoiXCRIT01FIiogXV0KZW1wdHk9IiQoX3F1ZXVlX2NvbW1hbmRfc2hlbGxfd29yZHNfZnJvbV9hcmdzKSIKW1sgLXogIiRlbXB0eSIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_command_shell_words_from_args"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_command_shell_words_from_args"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_command_shell_words_from_args rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_authorisation_key_name_ok --name authorisation-key-name-ok \
    --lang bash --b64 X3F1ZXVlX2F1dGhvcmlzYXRpb25fa2V5X25hbWVfb2sgIm15a2V5IgpfcXVldWVfYXV0aG9yaXNhdGlvbl9rZXlfbmFtZV9vayAibXkua2V5QGhvc3QiCl9xdWV1ZV9hdXRob3Jpc2F0aW9uX2tleV9uYW1lX29rICJrZXktMSsyIgpfcXVldWVfYXV0aG9yaXNhdGlvbl9rZXlfbmFtZV9vayAiQSIKISBfcXVldWVfYXV0aG9yaXNhdGlvbl9rZXlfbmFtZV9vayAiIgohIF9xdWV1ZV9hdXRob3Jpc2F0aW9uX2tleV9uYW1lX29rICJoYXMgc3BhY2UiCiEgX3F1ZXVlX2F1dGhvcmlzYXRpb25fa2V5X25hbWVfb2sgIiQocHl0aG9uMyAtYyAicHJpbnQoJ2EnKjY1KSIpIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_authorisation_key_name_ok"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_authorisation_key_name_ok"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_authorisation_key_name_ok rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_authorisation_key_suffix --name authorisation-key-suffix \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2F1dGhvcmlzYXRpb25fa2V5X3N1ZmZpeCAibXlrZXkiKSIgPT0gIk1ZS0VZIiBdXQpbWyAiJChfcXVldWVfYXV0aG9yaXNhdGlvbl9rZXlfc3VmZml4ICJteS1rZXkudjIiKSIgPT0gIk1ZX0tFWV9WMiIgXV0KW1sgIiQoX3F1ZXVlX2F1dGhvcmlzYXRpb25fa2V5X3N1ZmZpeCAiaGVsbG8gd29ybGQiKSIgPT0gIkhFTExPX1dPUkxEIiBdXQpbWyAiJChfcXVldWVfYXV0aG9yaXNhdGlvbl9rZXlfc3VmZml4ICIiKSIgPT0gIlVOS05PV04iIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_authorisation_key_suffix"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_authorisation_key_suffix"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_authorisation_key_suffix rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_authorisation_actor_user --name authorisation-actor-user \
    --lang bash --b64 dT0iJChfcXVldWVfYXV0aG9yaXNhdGlvbl9hY3Rvcl91c2VyKSIKW1sgLW4gIiR1IiBdXQpbWyAiJHUiID1+IF5bQS1aYS16MC05Xy4tXSskIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_authorisation_actor_user"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_authorisation_actor_user"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_authorisation_actor_user rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_authorisation_private_key_file --name authorisation-private-key-file \
    --lang bash --b64 cD0iJChfcXVldWVfYXV0aG9yaXNhdGlvbl9wcml2YXRlX2tleV9maWxlICJteWtleSIpIgpbWyAtbiAiJHAiIF1dCltbICIkcCIgPT0gKnByaXZhdGUvbXlrZXkuZWQyNTUxOS5wZW0gXV0KISBfcXVldWVfYXV0aG9yaXNhdGlvbl9wcml2YXRlX2tleV9maWxlICIiCiEgX3F1ZXVlX2F1dGhvcmlzYXRpb25fcHJpdmF0ZV9rZXlfZmlsZSAiaGFzIHNwYWNlIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_authorisation_private_key_file"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_authorisation_private_key_file"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_authorisation_private_key_file rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_authorisation_public_key_file --name authorisation-public-key-file \
    --lang bash --b64 cD0iJChfcXVldWVfYXV0aG9yaXNhdGlvbl9wdWJsaWNfa2V5X2ZpbGUgIm15a2V5IikiCltbIC1uICIkcCIgXV0KW1sgIiRwIiA9PSAqcHVibGljL215a2V5LmVkMjU1MTkucHViLnBlbSBdXQohIF9xdWV1ZV9hdXRob3Jpc2F0aW9uX3B1YmxpY19rZXlfZmlsZSAiIgohIF9xdWV1ZV9hdXRob3Jpc2F0aW9uX3B1YmxpY19rZXlfZmlsZSAiaGFzIHNwYWNlIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_authorisation_public_key_file"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_authorisation_public_key_file"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_authorisation_public_key_file rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_authorisation_key_meta_file --name authorisation-key-meta-file \
    --lang bash --b64 cD0iJChfcXVldWVfYXV0aG9yaXNhdGlvbl9rZXlfbWV0YV9maWxlICJteWtleSIpIgpbWyAtbiAiJHAiIF1dCltbICIkcCIgPT0gKm1ldGEvbXlrZXkuZW52IF1dCiMgSW52YWxpZCBuYW1lIGZhaWxzCiEgX3F1ZXVlX2F1dGhvcmlzYXRpb25fa2V5X21ldGFfZmlsZSAiaGFzIHNwYWNlIgohIF9xdWV1ZV9hdXRob3Jpc2F0aW9uX2tleV9tZXRhX2ZpbGUgIiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_authorisation_key_meta_file"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_authorisation_key_meta_file"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_authorisation_key_meta_file rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_base64_one_line --name base64-one-line \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9iYXNlNjRfb25lX2xpbmUgPDw8ICdoZWxsbycpIgpbWyAtbiAiJG91dCIgXV0KW1sgISAiJG91dCIgPX4gJCdcbicgXV0KZGVjb2RlZD0iJChlY2hvICIkb3V0IiB8IGJhc2U2NCAtZCAyPi9kZXYvbnVsbCkiCltbICIkZGVjb2RlZCIgPT0gImhlbGxvIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_base64_one_line"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_base64_one_line"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_base64_one_line rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_base64_decode --name base64-decode \
    --lang bash --b64 ZW5jb2RlZD0iJChlY2hvIC1uICd0ZXN0dmFsdWUnIHwgYmFzZTY0KSIKdG1wZj0iJChta3RlbXApIgpwcmludGYgJyVzJyAiJGVuY29kZWQiID4gIiR0bXBmIgpyZXN1bHQ9IiQoX3F1ZXVlX2Jhc2U2NF9kZWNvZGUgIiR0bXBmIikiCnJtIC1mICIkdG1wZiIKW1sgIiRyZXN1bHQiID09ICJ0ZXN0dmFsdWUiIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_base64_decode"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_base64_decode"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_base64_decode rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_authorisation_signature_requirement --name authorisation-signature-requirement \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9hdXRob3Jpc2F0aW9uX3NpZ25hdHVyZV9yZXF1aXJlbWVudCkiCltbIC1uICIkb3V0IiBdXQojIE11c3QgYmUgb25lIG9mIHRoZSBrbm93biB2YWx1ZXMKY2FzZSAiJG91dCIgaW4KICAgIG9mZnxub25lfGxlZ2FjeXxpZi10cnVzdGVkLWtleXxhbHdheXN8cmVxdWlyZWQpIDs7CiAgICAqKSBmYWxzZSA7Owplc2Fj \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_authorisation_signature_requirement"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_authorisation_signature_requirement"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_authorisation_signature_requirement rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_authorisation_dir --name authorisation-dir \
    --lang bash --b64 ZD0iJChfcXVldWVfYXV0aG9yaXNhdGlvbl9kaXIpIgpbWyAtbiAiJGQiIF1dCltbICIkZCIgPT0gKmF1dGhvcmlzYXRpb25zIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_authorisation_dir"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_authorisation_dir"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_authorisation_dir rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_policy_valid_name --name policy-valid-name \
    --lang bash --b64 X3F1ZXVlX3BvbGljeV92YWxpZF9uYW1lICJteW5hbWUiCl9xdWV1ZV9wb2xpY3lfdmFsaWRfbmFtZSAibXkubmFtZUBob3N0IgpfcXVldWVfcG9saWN5X3ZhbGlkX25hbWUgIkEtQitDIgohIF9xdWV1ZV9wb2xpY3lfdmFsaWRfbmFtZSAiIgohIF9xdWV1ZV9wb2xpY3lfdmFsaWRfbmFtZSAiaGFzIHNwYWNlIgohIF9xdWV1ZV9wb2xpY3lfdmFsaWRfbmFtZSAiaGFzL3NsYXNoIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_policy_valid_name"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_policy_valid_name"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_policy_valid_name rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_policy_shared_root --name policy-shared-root \
    --lang bash --b64 cD0iJChfcXVldWVfcG9saWN5X3NoYXJlZF9yb290KSIKW1sgLW4gIiRwIiBdXQpbWyAiJHAiID09ICpwb2xpY2llcy5kKiB8fCAiJHAiID09ICpiYXNocXVldWVzKiBdXQpleHBvcnQgUVVFVUVCQVNIX1NIQVJFRF9QT0xJQ1lfUk9PVD0vdG1wL3Rlc3Rfc2hhcmVkX3BvbGljaWVzCnAyPSIkKF9xdWV1ZV9wb2xpY3lfc2hhcmVkX3Jvb3QpIgpbWyAiJHAyIiA9PSAiL3RtcC90ZXN0X3NoYXJlZF9wb2xpY2llcyIgXV0KdW5zZXQgUVVFVUVCQVNIX1NIQVJFRF9QT0xJQ1lfUk9PVA== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_policy_shared_root"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_policy_shared_root"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_policy_shared_root rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_policy_exists --name policy-exists \
    --lang bash --b64 ISBfcXVldWVfcG9saWN5X2V4aXN0cyAiY2xhc3Mtc3RhdGVtZW50IiAibm9fc3VjaF9wb2xpY3lfeHl6enlfOTk5OSIKISBfcXVldWVfcG9saWN5X2V4aXN0cyAiIiAiYW55dGhpbmciCiEgX3F1ZXVlX3BvbGljeV9leGlzdHMgImNsYXNzLXN0YXRlbWVudCIgIiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_policy_exists"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_policy_exists"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_policy_exists rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_policy_origin --name policy-origin \
    --lang bash --b64 cm9vdD0iJChfcXVldWVfcm9vdCkiCnNoYXJlZD0iJChfcXVldWVfcG9saWN5X3NoYXJlZF9yb290KSIKc3JjPSIkKF9xdWV1ZV9wb2xpY3lfc291cmNlX3Jvb3QgfHwgdHJ1ZSkiCltbICIkKF9xdWV1ZV9wb2xpY3lfb3JpZ2luICIkcm9vdC9wb2xpY2llcy5kL2NsYXNzLXN0YXRlbWVudC9teXRlc3QuZW52IikiID09ICJwZXJzb25hbCIgXV0KW1sgIiQoX3F1ZXVlX3BvbGljeV9vcmlnaW4gIiRzaGFyZWQvY2xhc3Mtc3RhdGVtZW50L215dGVzdC5lbnYiKSIgPT0gInNoYXJlZCIgXV0KW1sgIiQoX3F1ZXVlX3BvbGljeV9vcmlnaW4gIi9zb21lL3JhbmRvbS9wYXRoLmVudiIpIiA9PSAidW5rbm93biIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_policy_origin"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_policy_origin"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_policy_origin rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_policy_sha256 --name policy-sha256 \
    --lang bash --b64 dG1wPSQobWt0ZW1wKQplY2hvICJIRUxMTz13b3JsZCIgPiAiJHRtcCIKaD0iJChfcXVldWVfcG9saWN5X3NoYTI1NiAiJHRtcCIpIgpbWyAtbiAiJGgiIF1dCltbICIkeyNofSIgLWdlIDggXV0KISBfcXVldWVfcG9saWN5X3NoYTI1NiAiL3RtcC9ub19zdWNoX2ZpbGVfeHl6enlfOTk5OS5lbnYiCnJtIC1mICIkdG1wIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_policy_sha256"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_policy_sha256"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_policy_sha256 rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_policy_quote_array_assignment --name policy-quote-array-assignment \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9wb2xpY3lfcXVvdGVfYXJyYXlfYXNzaWdubWVudCBNWVZBUiBhbHBoYSAiaGFzIHNwYWNlIiAiYSZiIikiCltbICIkb3V0IiA9PSAiTVlWQVI9KCIqIF1dCltbICIkb3V0IiA9PSAqImFscGhhIiogXV0KW1sgIiRvdXQiID09ICoiaGFzIiogXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_policy_quote_array_assignment"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_policy_quote_array_assignment"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_policy_quote_array_assignment rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_json_comma --name json-comma \
    --lang bash --b64 ZGVjbGFyZSBfX2pjX2ZsYWc9IiIKdG1wPSQobWt0ZW1wKQpfcXVldWVfanNvbl9jb21tYSBfX2pjX2ZsYWcgPiAiJHRtcCIKZmlyc3Q9IiQoY2F0ICIkdG1wIikiCltbIC16ICIkZmlyc3QiIF1dCl9xdWV1ZV9qc29uX2NvbW1hIF9famNfZmxhZyA+ICIkdG1wIgpzZWNvbmQ9IiQoY2F0ICIkdG1wIikiCltbICIkc2Vjb25kIiA9PSAiLCIgXV0Kcm0gLWYgIiR0bXAi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_json_comma"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_json_comma"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_json_comma rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_add_inherited_env_key --name add-inherited-env-key \
    --lang bash --b64 dW5zZXQgUVVFVUVCQVNIX0lOSEVSSVRFRF9FTlZfS0VZUwpfcXVldWVfYWRkX2luaGVyaXRlZF9lbnZfa2V5ICJNWV9LRVkiCltbICIkUVVFVUVCQVNIX0lOSEVSSVRFRF9FTlZfS0VZUyIgPT0gKk1ZX0tFWSogXV0KIyBBZGRpbmcgYWdhaW4gaXMgaWRlbXBvdGVudApfcXVldWVfYWRkX2luaGVyaXRlZF9lbnZfa2V5ICJNWV9LRVkiCmNvdW50PSQoZWNobyAiJFFVRVVFQkFTSF9JTkhFUklURURfRU5WX0tFWVMiIHwgdHIgJyAnICdcbicgfCBncmVwIC1jICdeTVlfS0VZJCcgfHwgdHJ1ZSkKW1sgIiRjb3VudCIgLWVxIDEgXV0KIyBJbnZhbGlkIG5hbWUgc2lsZW50bHkgaWdub3JlZApfcXVldWVfYWRkX2luaGVyaXRlZF9lbnZfa2V5ICIxYmFkLW5hbWUiCnVuc2V0IFFVRVVFQkFTSF9JTkhFUklURURfRU5WX0tFWVM= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_add_inherited_env_key"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_add_inherited_env_key"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_add_inherited_env_key rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_human_bytes --name human-bytes \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2h1bWFuX2J5dGVzIDUxMikiID09ICI1MTJCIiBdXQpbWyAiJChfcXVldWVfaHVtYW5fYnl0ZXMgMTAyNCkiID1+IEskIF1dCltbICIkKF9xdWV1ZV9odW1hbl9ieXRlcyAxMDQ4NTc2KSIgPX4gTSQgXV0KW1sgIiQoX3F1ZXVlX2h1bWFuX2J5dGVzIDEwNzM3NDE4MjQpIiA9fiBHJCBdXQpbWyAiJChfcXVldWVfaHVtYW5fYnl0ZXMgMCkiID09ICIwQiIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_human_bytes"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_human_bytes"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_human_bytes rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_parse_age_seconds --name parse-age-seconds \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX3BhcnNlX2FnZV9zZWNvbmRzIDMwKSIgPT0gIjMwIiBdXQpbWyAiJChfcXVldWVfcGFyc2VfYWdlX3NlY29uZHMgMm0pIiA9PSAiMTIwIiBdXQpbWyAiJChfcXVldWVfcGFyc2VfYWdlX3NlY29uZHMgMWgpIiA9PSAiMzYwMCIgXV0KW1sgIiQoX3F1ZXVlX3BhcnNlX2FnZV9zZWNvbmRzIDApIiA9PSAiMCIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_parse_age_seconds"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_parse_age_seconds"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_parse_age_seconds rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_cron_entry_hash --name cron-entry-hash \
    --lang bash --b64 aD0iJChfcXVldWVfY3Jvbl9lbnRyeV9oYXNoICJhbGljZSIgIi91c3IvYmluL3RydWUiKSIKW1sgLW4gIiRoIiBdXQpbWyAiJHsjaH0iIC1nZSAxNiBdXQpoMj0iJChfcXVldWVfY3Jvbl9lbnRyeV9oYXNoICJhbGljZSIgIi91c3IvYmluL3RydWUiKSIKW1sgIiRoIiA9PSAiJGgyIiBdXQpoMz0iJChfcXVldWVfY3Jvbl9lbnRyeV9oYXNoICJib2IiICIvdXNyL2Jpbi90cnVlIikiCltbICIkaCIgIT0gIiRoMyIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_cron_entry_hash"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_cron_entry_hash"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_cron_entry_hash rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_cron_stable_class --name cron-stable-class \
    --lang bash --b64 Yz0iJChfcXVldWVfY3Jvbl9zdGFibGVfY2xhc3MgImFsaWNlIiAiL3Vzci9iaW4vdHJ1ZSIpIgpbWyAiJGMiID09IGNyb25fKiBdXQpbWyAiJHsjY30iIC1nZSAxMCBdXQpjMj0iJChfcXVldWVfY3Jvbl9zdGFibGVfY2xhc3MgImFsaWNlIiAiL3Vzci9iaW4vdHJ1ZSIpIgpbWyAiJGMiID09ICIkYzIiIF1dCmMzPSIkKF9xdWV1ZV9jcm9uX3N0YWJsZV9jbGFzcyAiYm9iIiAiL3Vzci9iaW4vdHJ1ZSIpIgpbWyAiJGMiICE9ICIkYzMiIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_cron_stable_class"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_cron_stable_class"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_cron_stable_class rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_cron_trim --name cron-trim \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2Nyb25fdHJpbSAiICBoZWxsbyAgIikiID09ICJoZWxsbyIgXV0KW1sgIiQoX3F1ZXVlX2Nyb25fdHJpbSAibm8tc3BhY2VzIikiID09ICJuby1zcGFjZXMiIF1dCltbICIkKF9xdWV1ZV9jcm9uX3RyaW0gIgl0YWJiZWQJIikiID09ICJ0YWJiZWQiIF1dCltbICIkKF9xdWV1ZV9jcm9uX3RyaW0gIiIpIiA9PSAiIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_cron_trim"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_cron_trim"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_cron_trim rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_cron_is_assignment_line --name cron-is-assignment-line \
    --lang bash --b64 X3F1ZXVlX2Nyb25faXNfYXNzaWdubWVudF9saW5lICJTSEVMTD0vYmluL2Jhc2giCl9xdWV1ZV9jcm9uX2lzX2Fzc2lnbm1lbnRfbGluZSAiUEFUSD0vdXNyL2JpbiIKX3F1ZXVlX2Nyb25faXNfYXNzaWdubWVudF9saW5lICJNWV9WQVI9dmFsdWUiCiEgX3F1ZXVlX2Nyb25faXNfYXNzaWdubWVudF9saW5lICIqICogKiAqICogL3Vzci9iaW4vdHJ1ZSIKISBfcXVldWVfY3Jvbl9pc19hc3NpZ25tZW50X2xpbmUgIiMgY29tbWVudCIKISBfcXVldWVfY3Jvbl9pc19hc3NpZ25tZW50X2xpbmUgIiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_cron_is_assignment_line"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_cron_is_assignment_line"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_cron_is_assignment_line rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_cron_is_entry_line --name cron-is-entry-line \
    --lang bash --b64 X3F1ZXVlX2Nyb25faXNfZW50cnlfbGluZSAiMCAqICogKiAqIC91c3IvYmluL3RydWUiCl9xdWV1ZV9jcm9uX2lzX2VudHJ5X2xpbmUgIiovNSAqICogKiAqIGVjaG8gaGkiCl9xdWV1ZV9jcm9uX2lzX2VudHJ5X2xpbmUgIkByZWJvb3QgL3Vzci9iaW4vdHJ1ZSIKISBfcXVldWVfY3Jvbl9pc19lbnRyeV9saW5lICIjIGNvbW1lbnQiCiEgX3F1ZXVlX2Nyb25faXNfZW50cnlfbGluZSAiU0hFTEw9L2Jpbi9iYXNoIgohIF9xdWV1ZV9jcm9uX2lzX2VudHJ5X2xpbmUgIiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_cron_is_entry_line"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_cron_is_entry_line"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_cron_is_entry_line rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_context_allowed --name ai-context-allowed \
    --lang bash --b64 X3F1ZXVlX2FpX2NvbnRleHRfYWxsb3dlZCAiZG9jcyIKX3F1ZXVlX2FpX2NvbnRleHRfYWxsb3dlZCAiY29tbWFuZHMiCl9xdWV1ZV9haV9jb250ZXh0X2FsbG93ZWQgImNsYXNzZXMiCl9xdWV1ZV9haV9jb250ZXh0X2FsbG93ZWQgImFzc2V0cyIKX3F1ZXVlX2FpX2NvbnRleHRfYWxsb3dlZCAidGVzdHMiCiEgX3F1ZXVlX2FpX2NvbnRleHRfYWxsb3dlZCAidW5rbm93bl9jdHhfeHl6enki \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_context_allowed"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_context_allowed"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_context_allowed rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_audit_log_path --name ai-audit-log-path \
    --lang bash --b64 cD0iJChfcXVldWVfYWlfYXVkaXRfbG9nX3BhdGgpIgpbWyAtbiAiJHAiIF1dCltbICIkcCIgPT0gKi5qc29ubCBdXQpRVUVVRUJBU0hfQUlfQVVESVRfTE9HPS90bXAvdGVzdF9hdWRpdC5qc29ubApwMj0iJChfcXVldWVfYWlfYXVkaXRfbG9nX3BhdGgpIgpbWyAiJHAyIiA9PSAiL3RtcC90ZXN0X2F1ZGl0Lmpzb25sIiBdXQp1bnNldCBRVUVVRUJBU0hfQUlfQVVESVRfTE9H \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_audit_log_path"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_audit_log_path"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_audit_log_path rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_redact_question --name ai-redact-question \
    --lang bash --b64 IyBCYXNpYyBvdXRwdXQKb3V0PSIkKF9xdWV1ZV9haV9yZWRhY3RfcXVlc3Rpb24gJ2hlbGxvIHdvcmxkJykiCltbICIkb3V0IiA9PSAnaGVsbG8gd29ybGQnIF1dCiMgTmV3bGluZSByZXBsYWNlZCB3aXRoIHNwYWNlCm91dD0iJChfcXVldWVfYWlfcmVkYWN0X3F1ZXN0aW9uICQnbGluZTFcbmxpbmUyJykiCltbICIkb3V0IiA9PSAnbGluZTEgbGluZTInIF1dCiMgVGFiIHJlcGxhY2VkIHdpdGggc3BhY2UKb3V0PSIkKF9xdWV1ZV9haV9yZWRhY3RfcXVlc3Rpb24gJCdhXHRiJykiCltbICIkb3V0IiA9PSAnYSBiJyBdXQojIFRydW5jYXRpb24gYXQgMTgwIGNoYXJzCmxvbmc9IiQocHl0aG9uMyAtYyAicHJpbnQoJ3gnKjMwMCwgZW5kPScnKSIgKSIKb3V0PSIkKF9xdWV1ZV9haV9yZWRhY3RfcXVlc3Rpb24gIiRsb25nIikiCltbICIkeyNvdXR9IiAtbGUgMTg0IF1dCltbICIkb3V0IiA9PSAqJy4uLicgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_redact_question"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_redact_question"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_redact_question rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_list_contains --name ai-list-contains \
    --lang bash --b64 X3F1ZXVlX2FpX2xpc3RfY29udGFpbnMgImIiICJhIiAiYiIgImMiCl9xdWV1ZV9haV9saXN0X2NvbnRhaW5zICJmb28iICJmb28iCiEgX3F1ZXVlX2FpX2xpc3RfY29udGFpbnMgIngiICJhIiAiYiIgImMiCiEgX3F1ZXVlX2FpX2xpc3RfY29udGFpbnMgImIiCl9xdWV1ZV9haV9saXN0X2NvbnRhaW5zICJleGFjdCIgImV4YWN0IiAib3RoZXIi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_list_contains"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_list_contains"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_list_contains rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_detect_job_ids --name ai-detect-job-ids \
    --lang bash --b64 dGV4dD0iSm9iIDIwMjYwMTAxXzEyMDAwMF8xMjM0NTZfNjU0MzIxXzk5OSBjb21wbGV0ZWQiCm91dD0iJChfcXVldWVfYWlfZGV0ZWN0X2pvYl9pZHMgIiR0ZXh0IikiCltbICIkb3V0IiA9PSAiMjAyNjAxMDFfMTIwMDAwXzEyMzQ1Nl82NTQzMjFfOTk5IiBdXQojIE11bHRpcGxlIGlkZW50aWNhbCBJRHMgLT4gZGVkdXBlZCB0byAxIGxpbmUKdGV4dDI9IjIwMjYwMTAxXzEyMDAwMF8xMTExMTFfMjIyMjIyXzMzMyBhbmQgMjAyNjAxMDFfMTIwMDAwXzExMTExMV8yMjIyMjJfMzMzIGFnYWluIgpvdXQyPSIkKF9xdWV1ZV9haV9kZXRlY3Rfam9iX2lkcyAiJHRleHQyIikiCltbICIkKGVjaG8gIiRvdXQyIiB8IHdjIC1sIHwgdHIgLWQgJyAnKSIgPT0gIjEiIF1dCiMgTm8gSURzIC0+IGVtcHR5ICh1c2UgfHwgdHJ1ZSB0byBhYnNvcmIgZ3JlcCBub24temVybyBpbiBwaXBlZmFpbCBjb250ZXh0KQpvdXQzPSIkKF9xdWV1ZV9haV9kZXRlY3Rfam9iX2lkcyAibm8gaWRzIGhlcmUiIHx8IHRydWUpIgpbWyAteiAiJG91dDMiIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_detect_job_ids"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_detect_job_ids"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_detect_job_ids rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_source_dir --name ai-source-dir \
    --lang bash --b64 ZD0iJChfcXVldWVfYWlfc291cmNlX2RpcikiCltbIC1uICIkZCIgXV0KW1sgLWQgIiRkIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_source_dir"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_source_dir"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_source_dir rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_safety_log_path --name ai-safety-log-path \
    --lang bash --b64 cD0iJChfcXVldWVfYWlfc2FmZXR5X2xvZ19wYXRoKSIKW1sgLW4gIiRwIiBdXQpbWyAiJHAiID09ICpzYWZldHkqIHx8ICIkcCIgPT0gKmF1ZGl0KiBdXQpRVUVVRUJBU0hfQUlfU0FGRVRZX0xPRz0vdG1wL3Rlc3Rfc2FmZXR5Lmpzb25sCnAyPSIkKF9xdWV1ZV9haV9zYWZldHlfbG9nX3BhdGgpIgpbWyAiJHAyIiA9PSAiL3RtcC90ZXN0X3NhZmV0eS5qc29ubCIgXV0KdW5zZXQgUVVFVUVCQVNIX0FJX1NBRkVUWV9MT0c= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_safety_log_path"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_safety_log_path"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_safety_log_path rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_safety_response_text --name ai-safety-response-text \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9haV9zYWZldHlfcmVzcG9uc2VfdGV4dCAic3RlYWwgY3JlZGVudGlhbHMiICJzZWN1cml0eV9wcm9iZSIpIgpbWyAtbiAiJG91dCIgXV0KIyBNdXN0IGNvbnRhaW4gYSByZWZ1c2FsCltbICIkb3V0IiA9PSAqImNhbid0IiogfHwgIiRvdXQiID09ICoiY2Fubm90IiogfHwgIiRvdXQiID09ICoid29uJ3QiKiBdXQpvdXQyPSIkKF9xdWV1ZV9haV9zYWZldHlfcmVzcG9uc2VfdGV4dCAiYnlwYXNzIHBvbGljeSIgInBvbGljeV9ieXBhc3MiKSIKW1sgLW4gIiRvdXQyIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_safety_response_text"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_safety_response_text"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_safety_response_text rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_high_risk_operation_response_text --name ai-high-risk-response-text \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9haV9oaWdoX3Jpc2tfb3BlcmF0aW9uX3Jlc3BvbnNlX3RleHQgImRlbGV0ZSBhbGwgdGhlIHRoaW5ncyIpIgpbWyAtbiAiJG91dCIgXV0KW1sgIiRvdXQiID09ICpnb3Zlcm5lZCogfHwgIiRvdXQiID09ICpoaWdoLXJpc2sqIHx8ICIkb3V0IiA9PSAqYXV0aG9yaXR5KiB8fCAiJG91dCIgPT0gKmF1dGhvcmlzYXRpb24qIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_high_risk_operation_response_text"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_high_risk_operation_response_text"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_high_risk_operation_response_text rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_ask_provider_known --name ai-ask-provider-known \
    --lang bash --b64 X3F1ZXVlX2FpX2Fza19wcm92aWRlcl9rbm93biAib2xsYW1hIgpfcXVldWVfYWlfYXNrX3Byb3ZpZGVyX2tub3duICJnZW1pbmkiCl9xdWV1ZV9haV9hc2tfcHJvdmlkZXJfa25vd24gImFudGhyb3BpYyIKX3F1ZXVlX2FpX2Fza19wcm92aWRlcl9rbm93biAiY29udHJhY3QiCl9xdWV1ZV9haV9hc2tfcHJvdmlkZXJfa25vd24gImZpeHR1cmUiCiEgX3F1ZXVlX2FpX2Fza19wcm92aWRlcl9rbm93biAidW5rbm93bl94eXpfcHJvdmlkZXIiCiEgX3F1ZXVlX2FpX2Fza19wcm92aWRlcl9rbm93biAiIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_ask_provider_known"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_ask_provider_known"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_ask_provider_known rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_provider_requires_network --name ai-provider-requires-network \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2FpX3Byb3ZpZGVyX3JlcXVpcmVzX25ldHdvcmsgZ2VtaW5pKSIgPT0gInRydWUiIF1dCltbICIkKF9xdWV1ZV9haV9wcm92aWRlcl9yZXF1aXJlc19uZXR3b3JrIGFudGhyb3BpYykiID09ICJ0cnVlIiBdXQpbWyAiJChfcXVldWVfYWlfcHJvdmlkZXJfcmVxdWlyZXNfbmV0d29yayBvbGxhbWEpIiA9PSAiZmFsc2UiIF1dCltbICIkKF9xdWV1ZV9haV9wcm92aWRlcl9yZXF1aXJlc19uZXR3b3JrIGZpeHR1cmUpIiA9PSAiZmFsc2UiIF1dCltbICIkKF9xdWV1ZV9haV9wcm92aWRlcl9yZXF1aXJlc19uZXR3b3JrICIiKSIgPT0gImZhbHNlIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_provider_requires_network"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_provider_requires_network"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_provider_requires_network rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_provider_supports_json --name ai-provider-supports-json \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2FpX3Byb3ZpZGVyX3N1cHBvcnRzX2pzb24gb3BlbmFpKSIgPT0gInRydWUiIF1dCltbICIkKF9xdWV1ZV9haV9wcm92aWRlcl9zdXBwb3J0c19qc29uIGZpeHR1cmUpIiA9PSAidHJ1ZSIgXV0KW1sgIiQoX3F1ZXVlX2FpX3Byb3ZpZGVyX3N1cHBvcnRzX2pzb24gY29udHJhY3QpIiA9PSAidHJ1ZSIgXV0KW1sgIiQoX3F1ZXVlX2FpX3Byb3ZpZGVyX3N1cHBvcnRzX2pzb24gdW5rbm93bl94eXopIiA9PSAiZmFsc2UiIF1dCltbICIkKF9xdWV1ZV9haV9wcm92aWRlcl9zdXBwb3J0c19qc29uICIiKSIgPT0gImZhbHNlIiBdXQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_provider_supports_json"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_provider_supports_json"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_provider_supports_json rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_provider_live_supported --name ai-provider-live-supported \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2FpX3Byb3ZpZGVyX2xpdmVfc3VwcG9ydGVkIG9sbGFtYSkiID09ICJ0cnVlIiBdXQpbWyAiJChfcXVldWVfYWlfcHJvdmlkZXJfbGl2ZV9zdXBwb3J0ZWQgZ2VtaW5pKSIgPT0gInRydWUiIF1dCltbICIkKF9xdWV1ZV9haV9wcm92aWRlcl9saXZlX3N1cHBvcnRlZCBhbnRocm9waWMpIiA9PSAidHJ1ZSIgXV0KW1sgIiQoX3F1ZXVlX2FpX3Byb3ZpZGVyX2xpdmVfc3VwcG9ydGVkIHVua25vd25fcHJvdmlkZXIpIiA9PSAiZmFsc2UiIF1dCltbICIkKF9xdWV1ZV9haV9wcm92aWRlcl9saXZlX3N1cHBvcnRlZCAiIikiID09ICJmYWxzZSIgXV0= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_provider_live_supported"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_provider_live_supported"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_provider_live_supported rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_ai_provider_list --name ai-provider-list \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9haV9wcm92aWRlcl9saXN0KSIKW1sgLW4gIiRvdXQiIF1dCmVjaG8gIiRvdXQiIHwgZ3JlcCAtRnhxICJvbGxhbWEiCmVjaG8gIiRvdXQiIHwgZ3JlcCAtRnhxICJnZW1pbmkiCmVjaG8gIiRvdXQiIHwgZ3JlcCAtRnhxICJhbnRocm9waWMiCmVjaG8gIiRvdXQiIHwgZ3JlcCAtRnhxICJjb250cmFjdCIKZWNobyAiJG91dCIgfCBncmVwIC1GeHEgImZpeHR1cmUi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_ai_provider_list"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_ai_provider_list"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_ai_provider_list rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_array_contains --name array-contains \
    --lang bash --b64 X3F1ZXVlX2FycmF5X2NvbnRhaW5zICJiIiAiYSIgImIiICJjIgohIF9xdWV1ZV9hcnJheV9jb250YWlucyAieCIgImEiICJiIiAiYyIKX3F1ZXVlX2FycmF5X2NvbnRhaW5zICJvbmx5IiAib25seSIKISBfcXVldWVfYXJyYXlfY29udGFpbnMgInoi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_array_contains"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_array_contains"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_array_contains rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_module_valid_kind --name module-valid-kind \
    --lang bash --b64 X3F1ZXVlX21vZHVsZV92YWxpZF9raW5kICJjbGFzcyIKX3F1ZXVlX21vZHVsZV92YWxpZF9raW5kICJjbGFzc2VzIgpfcXVldWVfbW9kdWxlX3ZhbGlkX2tpbmQgImFzc2V0IgpfcXVldWVfbW9kdWxlX3ZhbGlkX2tpbmQgImNhcCIKX3F1ZXVlX21vZHVsZV92YWxpZF9raW5kICJwcm92aWRlciIKISBfcXVldWVfbW9kdWxlX3ZhbGlkX2tpbmQgInVua25vd24iCiEgX3F1ZXVlX21vZHVsZV92YWxpZF9raW5kICIi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_module_valid_kind"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_module_valid_kind"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_module_valid_kind rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_module_normal_kind --name module-normal-kind \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX21vZHVsZV9ub3JtYWxfa2luZCBjbGFzcykiID09ICJjbGFzcyIgXV0KW1sgIiQoX3F1ZXVlX21vZHVsZV9ub3JtYWxfa2luZCBjbGFzc2VzKSIgPT0gImNsYXNzIiBdXQpbWyAiJChfcXVldWVfbW9kdWxlX25vcm1hbF9raW5kIGFzc2V0cykiID09ICJhc3NldCIgXV0KW1sgIiQoX3F1ZXVlX21vZHVsZV9ub3JtYWxfa2luZCBjYXBzKSIgPT0gImNhcCIgXV0KW1sgIiQoX3F1ZXVlX21vZHVsZV9ub3JtYWxfa2luZCBwcm92aWRlcnMpIiA9PSAicHJvdmlkZXIiIF1dCiEgX3F1ZXVlX21vZHVsZV9ub3JtYWxfa2luZCAidW5rbm93biIKISBfcXVldWVfbW9kdWxlX25vcm1hbF9raW5kICIi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_module_normal_kind"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_module_normal_kind"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_module_normal_kind rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_module_paths --name module-paths \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9tb2R1bGVfcGF0aHMgY2xhc3MgbXljbGFzcykiCltbICIkb3V0IiA9PSAqY2xhc3Nlcy9teWNsYXNzLmVudiogXV0KW1sgIiRvdXQiID09ICpkaXNhYmxlZCogXV0Kb3V0Mj0iJChfcXVldWVfbW9kdWxlX3BhdGhzIGFzc2V0IG15YXNzZXQpIgpbWyAiJG91dDIiID09ICphc3NldHMuZC9teWFzc2V0LnNoKiBdXQohIF9xdWV1ZV9tb2R1bGVfcGF0aHMgdW5rbm93biBteW5hbWU= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_module_paths"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_module_paths"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_module_paths rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_acl_known_operations_text --name acl-known-operations-text \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9hY2xfa25vd25fb3BlcmF0aW9uc190ZXh0KSIKW1sgLW4gIiRvdXQiIF1dCmVjaG8gIiRvdXQiIHwgZ3JlcCAtRnhxICJqb2Iuc3VibWl0IgplY2hvICIkb3V0IiB8IGdyZXAgLUZ4cSAiam9iLmNhbmNlbCIKZWNobyAiJG91dCIgfCBncmVwIC1GeHEgInF1ZXVlLmNsZWFyIgplY2hvICIkb3V0IiB8IGdyZXAgLUZ4cSAiY2xhc3MubWFuYWdlIg== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_acl_known_operations_text"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_acl_known_operations_text"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_acl_known_operations_text rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_acl_operation_known --name acl-operation-known \
    --lang bash --b64 X3F1ZXVlX2FjbF9vcGVyYXRpb25fa25vd24gImpvYi5zdWJtaXQiCl9xdWV1ZV9hY2xfb3BlcmF0aW9uX2tub3duICJqb2IuY2FuY2VsIgpfcXVldWVfYWNsX29wZXJhdGlvbl9rbm93biAicXVldWUuY2xlYXIiCiEgX3F1ZXVlX2FjbF9vcGVyYXRpb25fa25vd24gIm5vdC5hLnJlYWwub3AiCiEgX3F1ZXVlX2FjbF9vcGVyYXRpb25fa25vd24gIiI= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_acl_operation_known"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_acl_operation_known"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_acl_operation_known rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_acl_decision_json --name acl-decision-json \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9hY2xfZGVjaXNpb25fanNvbiAiYWxpY2UiICJqb2Iuc3VibWl0IiAibXlxdWV1ZSIgImFsbG93IiAiYWNsX21hdGNoIikiCltbIC1uICIkb3V0IiBdXQpweXRob24zIC1jICJpbXBvcnQganNvbixzeXM7IGQ9anNvbi5sb2FkcyhzeXMuc3RkaW4ucmVhZCgpKTsgYXNzZXJ0IGRbJ3NjaGVtYSddPT0ncXVldWViYXNoLmFjbF9kZWNpc2lvbi52MSc7IGFzc2VydCBkWydzdWJqZWN0J109PSdhbGljZSc7IGFzc2VydCBkWydkZWNpc2lvbiddPT0nYWxsb3cnIiA8PDwgIiRvdXQiCiMgZGVueSBkZWNpc2lvbgpvdXQ9IiQoX3F1ZXVlX2FjbF9kZWNpc2lvbl9qc29uICJib2IiICJxdWV1ZS5jbGVhciIgIioiICJkZW55IiAibm9fcnVsZSIpIgpweXRob24zIC1jICJpbXBvcnQganNvbixzeXM7IGQ9anNvbi5sb2FkcyhzeXMuc3RkaW4ucmVhZCgpKTsgYXNzZXJ0IGRbJ2RlY2lzaW9uJ109PSdkZW55JyIgPDw8ICIkb3V0Ig== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_acl_decision_json"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_acl_decision_json"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_acl_decision_json rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_acl_file_policy_path --name acl-file-policy-path \
    --lang bash --b64 cD0iJChfcXVldWVfYWNsX2ZpbGVfcG9saWN5X3BhdGgpIgpbWyAtbiAiJHAiIF1dCltbICIkcCIgPT0gKmFjbCogfHwgIiRwIiA9PSAqcG9saWN5KiBdXQojIEVudiBvdmVycmlkZQpRVUVVRUJBU0hfRklMRV9BQ0xfUE9MSUNZPS90bXAvdGVzdF9hY2wudHN2CnAyPSIkKF9xdWV1ZV9hY2xfZmlsZV9wb2xpY3lfcGF0aCkiCltbICIkcDIiID09ICIvdG1wL3Rlc3RfYWNsLnRzdiIgXV0KdW5zZXQgUVVFVUVCQVNIX0ZJTEVfQUNMX1BPTElDWQ== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_acl_file_policy_path"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_acl_file_policy_path"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_acl_file_policy_path rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_acl_provider_active --name acl-provider-active \
    --lang bash --b64 IyBmaWxlIHByb3ZpZGVyIC0+IGFjdGl2ZQpRVUVVRUJBU0hfQUNMX1BST1ZJREVSPWZpbGUKX3F1ZXVlX2FjbF9wcm92aWRlcl9hY3RpdmUKUVVFVUVCQVNIX0FDTF9QUk9WSURFUj1maWxlX2FjbApfcXVldWVfYWNsX3Byb3ZpZGVyX2FjdGl2ZQojIHVua25vd24gLT4gaW5hY3RpdmUKUVVFVUVCQVNIX0FDTF9QUk9WSURFUj1ub25lCiEgX3F1ZXVlX2FjbF9wcm92aWRlcl9hY3RpdmUKdW5zZXQgUVVFVUVCQVNIX0FDTF9QUk9WSURFUgohIF9xdWV1ZV9hY2xfcHJvdmlkZXJfYWN0aXZl \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_acl_provider_active"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_acl_provider_active"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_acl_provider_active rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_acl_tsv_field_valid --name acl-tsv-field-valid \
    --lang bash --b64 X3F1ZXVlX2FjbF90c3ZfZmllbGRfdmFsaWQgImhlbGxvIgpfcXVldWVfYWNsX3Rzdl9maWVsZF92YWxpZCAiaGFzLmRvdCIKX3F1ZXVlX2FjbF90c3ZfZmllbGRfdmFsaWQgImpvYi5zdWJtaXQiCiEgX3F1ZXVlX2FjbF90c3ZfZmllbGRfdmFsaWQgIiIKISBfcXVldWVfYWNsX3Rzdl9maWVsZF92YWxpZCAkJ2hhc1x0dGFiJwohIF9xdWV1ZV9hY2xfdHN2X2ZpZWxkX3ZhbGlkICQnaGFzXG5uZXdsaW5lJw== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_acl_tsv_field_valid"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_acl_tsv_field_valid"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_acl_tsv_field_valid rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_acl_file_rule_json --name acl-file-rule-json \
    --lang bash --b64 b3V0PSIkKF9xdWV1ZV9hY2xfZmlsZV9ydWxlX2pzb24gIi9ldGMvcG9saWN5LnRzdiIgNDIpIgpbWyAiJG91dCIgPX4gZmlsZV9hY2wgXV0KW1sgIiRvdXQiID1+IDQyIF1dCltbICIkb3V0IiA9fiBwb2xpY3lcLnRzdiBdXQojIFZhbGlkIEpTT04gYXJyYXkKcHl0aG9uMyAtYyAiaW1wb3J0IGpzb24sc3lzOyBqc29uLmxvYWRzKHN5cy5zdGRpbi5yZWFkKCkpIiA8PDwgIiRvdXQi \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_acl_file_rule_json"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_acl_file_rule_json"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_acl_file_rule_json rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_dev_valid_function_name --name dev-valid-function-name \
    --lang bash --b64 X3F1ZXVlX2Rldl92YWxpZF9mdW5jdGlvbl9uYW1lICJfcXVldWVfZm9vIgpfcXVldWVfZGV2X3ZhbGlkX2Z1bmN0aW9uX25hbWUgIm15X2Z1bmMiCl9xdWV1ZV9kZXZfdmFsaWRfZnVuY3Rpb25fbmFtZSAiQUJDMTIzIgohIF9xdWV1ZV9kZXZfdmFsaWRfZnVuY3Rpb25fbmFtZSAiMWJhZCIKISBfcXVldWVfZGV2X3ZhbGlkX2Z1bmN0aW9uX25hbWUgImhhcy1oeXBoZW4iCiEgX3F1ZXVlX2Rldl92YWxpZF9mdW5jdGlvbl9uYW1lICIiCiEgX3F1ZXVlX2Rldl92YWxpZF9mdW5jdGlvbl9uYW1lICJoYXMgc3BhY2Ui \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_dev_valid_function_name"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_dev_valid_function_name"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_dev_valid_function_name rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_dev_json_bool --name dev-json-bool \
    --lang bash --b64 W1sgIiQoX3F1ZXVlX2Rldl9qc29uX2Jvb2wgMSkiID09ICJ0cnVlIiBdXQpbWyAiJChfcXVldWVfZGV2X2pzb25fYm9vbCB0cnVlKSIgPT0gInRydWUiIF1dCltbICIkKF9xdWV1ZV9kZXZfanNvbl9ib29sIHllcykiID09ICJ0cnVlIiBdXQpbWyAiJChfcXVldWVfZGV2X2pzb25fYm9vbCBvbikiID09ICJ0cnVlIiBdXQpbWyAiJChfcXVldWVfZGV2X2pzb25fYm9vbCAwKSIgPT0gImZhbHNlIiBdXQpbWyAiJChfcXVldWVfZGV2X2pzb25fYm9vbCBmYWxzZSkiID09ICJmYWxzZSIgXV0KW1sgIiQoX3F1ZXVlX2Rldl9qc29uX2Jvb2wgIiIpIiA9PSAiZmFsc2UiIF1d \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_dev_json_bool"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_dev_json_bool"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_dev_json_bool rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_dev_function_location --name dev-function-location \
    --lang bash --b64 IyBTaG91bGQgcmV0dXJuICJmdW5jbmFtZSBsaW5lIGZpbGUiIGZvciBhIGtub3duIGZ1bmN0aW9uCm91dD0iJChfcXVldWVfZGV2X2Z1bmN0aW9uX2xvY2F0aW9uIF9xdWV1ZV9pZCkiCltbIC1uICIkb3V0IiBdXQpbWyAiJG91dCIgPX4gX3F1ZXVlX2lkIF1dCiMgVW5rbm93biBmdW5jdGlvbgohIF9xdWV1ZV9kZXZfZnVuY3Rpb25fbG9jYXRpb24gIl9fbm9uZXhpc3RlbnRfZm5feHl6enlfXyIgMj4vZGV2L251bGw= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_dev_function_location"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_dev_function_location"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_dev_function_location rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_dev_scratchpad_path --name dev-scratchpad-path \
    --lang bash --b64 IyBEZWZhdWx0IHBhdGgKcD0iJChfcXVldWVfZGV2X3NjcmF0Y2hwYWRfcGF0aCkiCltbIC1uICIkcCIgXV0KW1sgIiRwIiA9PSAqc2NyYXRjaHBhZC5qc29uIF1dCiMgRW52IG92ZXJyaWRlClFVRVVFQkFTSF9ERVZfU0NSQVRDSFBBRD0vdG1wL3Rlc3Rfc2NyYXRjaC5qc29uCnAyPSIkKF9xdWV1ZV9kZXZfc2NyYXRjaHBhZF9wYXRoKSIKW1sgIiRwMiIgPT0gIi90bXAvdGVzdF9zY3JhdGNoLmpzb24iIF1dCnVuc2V0IFFVRVVFQkFTSF9ERVZfU0NSQVRDSFBBRA== \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_dev_scratchpad_path"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_dev_scratchpad_path"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_dev_scratchpad_path rc=$_rc" >&2; fi
fi

if queue dev test qbtest add --file "$TARGET" \
    --function _queue_dev_attempt_store_path --name dev-attempt-store-path \
    --lang bash --b64 IyBEZWZhdWx0IHBhdGgKcD0iJChfcXVldWVfZGV2X2F0dGVtcHRfc3RvcmVfcGF0aCkiCltbIC1uICIkcCIgXV0KW1sgIiRwIiA9PSAqYXR0ZW1wdCogfHwgIiRwIiA9PSAqYXR0ZW1wdHMqIF1dCiMgRW52IG92ZXJyaWRlClFVRVVFQkFTSF9ERVZfQVRURU1QVFM9L3RtcC90ZXN0X2F0dGVtcHRzLmpzb24KcDI9IiQoX3F1ZXVlX2Rldl9hdHRlbXB0X3N0b3JlX3BhdGgpIgpbWyAiJHAyIiA9PSAiL3RtcC90ZXN0X2F0dGVtcHRzLmpzb24iIF1dCnVuc2V0IFFVRVVFQkFTSF9ERVZfQVRURU1QVFM= \
    $FORCE_FLAG 2>/dev/null; then
    _qi_pass=$((_qi_pass+1)); echo "  added  _queue_dev_attempt_store_path"
else
    _rc=$?
    if [[ $_rc -eq 2 ]]; then _qi_skip=$((_qi_skip+1)); echo "  exists _queue_dev_attempt_store_path"
    else _qi_fail=$((_qi_fail+1)); echo "  FAIL   _queue_dev_attempt_store_path rc=$_rc" >&2; fi
fi

echo ""
echo "qbtest_installer: done — added=$_qi_pass exists=$_qi_skip failed=$_qi_fail"
[[ $_qi_fail -eq 0 ]]
