#!/usr/bin/env bash
# bashqueues asset plugin: class_classifier
# Consumes non-mutating queue class-infer JSON decisions as class-policy signals.
# It does not train models, submit jobs, mutate queue state, or override policy.

queue_asset_facilities() {
    cat <<'FACILITIES'
class_classifier:no_downgrade Blocks when an explainable class-infer decision says the submitted class is a high-confidence downgrade
class_classifier:warn_on_downgrade Emits an auditable warning for explainable downgrade decisions without blocking
class_classifier:decision_explainable Requires non-ok/non-allow class-infer decisions to include reasons before policy may enforce them
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
class_classifier:no_downgrade	target=policy label or _	params=decision_file=/path/result.json min_confidence=0.80 action=block|warn|require_authorisation	 example=queue_class_shared_asset class_classifier no_downgrade _ decision_file=/run/queuebash/class-infer.json min_confidence=0.80 action=block	notes=Consumes queue class-infer recommend/explain JSON. Blocks only when downgrade/mismatch is high-confidence and explainable; otherwise defers to class policy.
class_classifier:warn_on_downgrade	target=policy label or _	params=decision_file=/path/result.json min_confidence=0.65	 example=queue_class_shared_asset class_classifier warn_on_downgrade _ decision_file=/run/queuebash/class-infer.json min_confidence=0.65	notes=Never blocks for a downgrade; prints a warning signal for audit/review flows.
class_classifier:decision_explainable	target=policy label or _	params=decision_file=/path/result.json	 example=queue_class_shared_asset class_classifier decision_explainable _ decision_file=/run/queuebash/class-infer.json	notes=Fails closed when a non-ok/non-allow decision lacks reasons. This prevents unexplained classifier output from being used for automatic blocking.
EOF_HINTS
}

_queue_asset_class_classifier_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in
            "$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
        esac
    done
    return 1
}

_queue_asset_class_classifier_bool() {
    case "${1:-}" in 1|yes|true|on|Y|y) return 0 ;; *) return 1 ;; esac
}

_queue_asset_class_classifier_decision_json() {
    local decision_file job_file history policy helper cwd requested_class
    decision_file="$(_queue_asset_class_classifier_param decision_file "$@" || true)"
    [[ -z "$decision_file" ]] && decision_file="$(_queue_asset_class_classifier_param result_file "$@" || true)"
    [[ -z "$decision_file" ]] && decision_file="${QUEUEBASH_CLASS_INFER_DECISION_FILE:-}"
    if [[ -n "$decision_file" ]]; then
        [[ -r "$decision_file" ]] || { echo "asset_check_blocked: class_classifier decision_file_unreadable path=$decision_file"; return 1; }
        cat "$decision_file"
        return 0
    fi

    # Optional fixture/local preview path for tests and future policy dry-runs.
    # Still non-mutating: delegates to queue-class-infer recommend --json over a
    # supplied job fixture and trusted history/policy inputs.
    job_file="$(_queue_asset_class_classifier_param job_file "$@" || true)"
    [[ -z "$job_file" ]] && job_file="${QUEUEBASH_CLASS_INFER_JOB_FILE:-}"
    if [[ -n "$job_file" ]]; then
        helper="$(_queue_asset_class_classifier_param helper "$@" || true)"
        if [[ -z "$helper" ]]; then
            helper="${QUEUEBASH_CLASS_INFER_HELPER:-}"
        fi
        if [[ -z "$helper" ]]; then
            helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/../bin/queue-class-infer.py"
        fi
        [[ -x "$helper" || -r "$helper" ]] || { echo "asset_check_blocked: class_classifier helper_unavailable path=$helper"; return 1; }
        history="$(_queue_asset_class_classifier_param history "$@" || true)"
        policy="$(_queue_asset_class_classifier_param policy "$@" || true)"
        cwd="$(_queue_asset_class_classifier_param cwd "$@" || true)"
        requested_class="$(_queue_asset_class_classifier_param requested_class "$@" || true)"
        local -a cmd=(python3 "$helper" recommend --json --job "$job_file")
        [[ -n "$history" ]] && cmd+=(--history "$history")
        [[ -n "$policy" ]] && cmd+=(--policy "$policy")
        [[ -n "$cwd" ]] && cmd+=(--cwd "$cwd")
        [[ -n "$requested_class" ]] && cmd+=(--requested-class "$requested_class")
        "${cmd[@]}"
        return $?
    fi

    echo "asset_check_blocked: class_classifier decision_file_or_job_file_required"
    return 1
}

_queue_asset_class_classifier_eval_json() {
    local expr="$1"
    shift || true
    python3 -c '
import json, sys
expr = sys.argv[1]
obj = json.load(sys.stdin)
rec = obj.get("recommendation") if obj.get("schema") == "queuebash.class_inference.explain.v1" else obj
if expr == "decision": print(str(rec.get("decision", "")))
elif expr == "recommended_action": print(str(rec.get("recommended_action", "")))
elif expr == "confidence": print(rec.get("confidence", 0.0))
elif expr == "requested_class": print(str(rec.get("requested_class", "")))
elif expr == "recommended_class": print(str(rec.get("recommended_class", "")))
elif expr == "reasons_count": print(len(rec.get("reasons") or []))
elif expr == "schema": print(str(rec.get("schema", obj.get("schema", ""))))
else: raise SystemExit(2)
' "$expr"
}

_queue_asset_class_classifier_tuple_from_json() {
    python3 -c '
import json, sys
obj = json.load(sys.stdin)
rec = obj.get("recommendation") if obj.get("schema") == "queuebash.class_inference.explain.v1" else obj
fields = [
    str(rec.get("schema", obj.get("schema", ""))),
    str(rec.get("decision", "")),
    str(rec.get("recommended_action", "")),
    str(rec.get("confidence", 0.0)),
    str(rec.get("requested_class", "")),
    str(rec.get("recommended_class", "")),
    str(len(rec.get("reasons") or [])),
]
print("\t".join(fields))
'
}

_queue_asset_class_classifier_float_ge() {
    python3 - "$1" "$2" <<'PY'
import sys
try:
    have=float(sys.argv[1]); need=float(sys.argv[2])
except Exception:
    sys.exit(1)
sys.exit(0 if have >= need else 1)
PY
}

_queue_asset_class_classifier_decision_tuple() {
    local json decision action confidence requested recommended reasons schema
    json="$(_queue_asset_class_classifier_decision_json "$@")" || return 1
    printf '%s' "$json" | _queue_asset_class_classifier_tuple_from_json
}

queue_asset_check_class_classifier_decision_explainable() {
    local target="${1:-_}"
    shift || true
    local tuple schema decision action confidence requested recommended reasons
    tuple="$(_queue_asset_class_classifier_decision_tuple "$@")" || return 1
    IFS=$'\t' read -r schema decision action confidence requested recommended reasons <<< "$tuple"
    if [[ "$decision" != "ok" || "$action" != "allow" ]]; then
        if [[ "${reasons:-0}" -le 0 ]]; then
            echo "asset_check_blocked: class_classifier:decision_explainable unexplained_decision target=$target decision=$decision action=$action requested=$requested recommended=$recommended"
            return 1
        fi
    fi
    echo "asset_check_ok: class_classifier:decision_explainable target=$target decision=$decision action=$action reasons=${reasons:-0}"
}

queue_asset_check_class_classifier_warn_on_downgrade() {
    local target="${1:-_}"
    shift || true
    local min_conf tuple schema decision action confidence requested recommended reasons
    min_conf="$(_queue_asset_class_classifier_param min_confidence "$@" || echo 0.65)"
    tuple="$(_queue_asset_class_classifier_decision_tuple "$@")" || return 1
    IFS=$'\t' read -r schema decision action confidence requested recommended reasons <<< "$tuple"
    if [[ "$decision" == "class_downgrade_suspected" || "$decision" == "class_mismatch" ]]; then
        if _queue_asset_class_classifier_float_ge "$confidence" "$min_conf"; then
            echo "asset_check_ok: class_classifier:warn_on_downgrade warning=1 target=$target decision=$decision confidence=$confidence requested=$requested recommended=$recommended reasons=${reasons:-0}"
            return 0
        fi
    fi
    echo "asset_check_ok: class_classifier:warn_on_downgrade warning=0 target=$target decision=$decision confidence=$confidence"
}

queue_asset_check_class_classifier_no_downgrade() {
    local target="${1:-_}"
    shift || true
    local min_conf configured_action tuple schema decision action confidence requested recommended reasons
    min_conf="$(_queue_asset_class_classifier_param min_confidence "$@" || echo 0.80)"
    configured_action="$(_queue_asset_class_classifier_param action "$@" || echo block)"
    tuple="$(_queue_asset_class_classifier_decision_tuple "$@")" || return 1
    IFS=$'\t' read -r schema decision action confidence requested recommended reasons <<< "$tuple"

    case "$decision" in
        class_downgrade_suspected|class_mismatch)
            if ! _queue_asset_class_classifier_float_ge "$confidence" "$min_conf"; then
                echo "asset_check_ok: class_classifier:no_downgrade below_threshold target=$target decision=$decision confidence=$confidence min_confidence=$min_conf"
                return 0
            fi
            if [[ "${reasons:-0}" -le 0 ]]; then
                echo "asset_check_ok: class_classifier:no_downgrade unexplained_not_auto_blocked target=$target decision=$decision confidence=$confidence"
                return 0
            fi
            case "$configured_action" in
                warn|audit|allow)
                    echo "asset_check_ok: class_classifier:no_downgrade configured_${configured_action} target=$target decision=$decision confidence=$confidence requested=$requested recommended=$recommended reasons=$reasons"
                    return 0
                    ;;
                block|require_authorisation|require_authorization)
                    echo "asset_check_blocked: class_classifier:no_downgrade downgrade_detected target=$target decision=$decision confidence=$confidence requested=$requested recommended=$recommended reasons=$reasons action=$configured_action"
                    return 1
                    ;;
                *)
                    echo "asset_check_blocked: class_classifier:no_downgrade invalid_action=$configured_action"
                    return 2
                    ;;
            esac
            ;;
        insufficient_history)
            echo "asset_check_ok: class_classifier:no_downgrade insufficient_history target=$target action=defer_to_class_policy confidence=$confidence"
            return 0
            ;;
        *)
            echo "asset_check_ok: class_classifier:no_downgrade target=$target decision=$decision action=$action confidence=$confidence"
            return 0
            ;;
    esac
}
