#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=../assets.d/class_classifier.sh
source assets.d/class_classifier.sh

fixtures="tests/fixtures/class_classifier"
decisions="$fixtures/decisions"

out="$(queue_asset_facilities)"
[[ "$out" == *'class_classifier:no_downgrade'* ]]
[[ "$out" == *'class_classifier:warn_on_downgrade'* ]]
[[ "$out" == *'class_classifier:decision_explainable'* ]]
[[ "$out" == *'class_classifier:risk_floor_review'* ]]

set +e
block_out="$(queue_asset_check_class_classifier_no_downgrade _ decision_file="$decisions/downgrade_block_decision.json" min_confidence=0.80 action=block 2>&1)"
block_rc=$?
set -e
[[ "$block_rc" -ne 0 ]] || { echo "expected downgrade block" >&2; echo "$block_out" >&2; exit 1; }
[[ "$block_out" == *'asset_check_blocked: class_classifier:no_downgrade downgrade_detected'* ]]

queue_asset_check_class_classifier_warn_on_downgrade _ decision_file="$decisions/downgrade_block_decision.json" min_confidence=0.65 >/tmp/classifier_warn.out
[[ "$(cat /tmp/classifier_warn.out)" == *'warning=1'* ]]

queue_asset_check_class_classifier_no_downgrade _ decision_file="$decisions/near_miss_decision.json" min_confidence=0.80 action=block >/tmp/classifier_near.out
[[ "$(cat /tmp/classifier_near.out)" == *'asset_check_ok:'* ]]

queue_asset_check_class_classifier_no_downgrade _ decision_file="$decisions/cold_start_decision.json" min_confidence=0.80 action=block >/tmp/classifier_cold.out
[[ "$(cat /tmp/classifier_cold.out)" == *'insufficient_history'* ]]

set +e
risk_out="$(queue_asset_check_class_classifier_risk_floor_review _ decision_file="$decisions/risk_floor_decision.json" min_risk_score=3 action=require_authorisation 2>&1)"
risk_rc=$?
set -e
[[ "$risk_rc" -ne 0 ]] || { echo "expected risk-floor review to require authorisation" >&2; echo "$risk_out" >&2; exit 1; }
[[ "$risk_out" == *'class_classifier:risk_floor_review review_required'* ]]

queue_asset_check_class_classifier_risk_floor_review _ decision_file="$decisions/cold_start_decision.json" min_risk_score=3 action=require_authorisation >/tmp/classifier_risk_cold.out
[[ "$(cat /tmp/classifier_risk_cold.out)" == *'no_risk_floor'* ]]

queue_asset_check_class_classifier_risk_floor_review _ decision_file="$decisions/risk_floor_decision.json" min_risk_score=3 action=warn >/tmp/classifier_risk_warn.out
[[ "$(cat /tmp/classifier_risk_warn.out)" == *'configured_warn'* ]]

set +e
explain_out="$(queue_asset_check_class_classifier_decision_explainable _ decision_file="$decisions/downgrade_unexplained_decision.json" 2>&1)"
explain_rc=$?
set -e
[[ "$explain_rc" -ne 0 ]] || { echo "expected unexplained decision to fail explainability gate" >&2; echo "$explain_out" >&2; exit 1; }
[[ "$explain_out" == *'unexplained_decision'* ]]

queue_asset_check_class_classifier_no_downgrade _ decision_file="$decisions/downgrade_unexplained_decision.json" min_confidence=0.80 action=block >/tmp/classifier_unexplained.out
[[ "$(cat /tmp/classifier_unexplained.out)" == *'unexplained_not_auto_blocked'* ]]

set +e
job_out="$(queue_asset_check_class_classifier_no_downgrade _ job_file="$decisions/downgrade_block_job.json" history="$fixtures/history_normal.jsonl" policy="$fixtures/policy_block_on_downgrade.json" helper="bin/queue-class-infer.py" min_confidence=0.80 action=block 2>&1)"
job_rc=$?
set -e
[[ "$job_rc" -ne 0 ]] || { echo "expected job_file preview downgrade block" >&2; echo "$job_out" >&2; exit 1; }
[[ "$job_out" == *'downgrade_detected'* ]]

rm -f /tmp/classifier_warn.out /tmp/classifier_near.out /tmp/classifier_cold.out /tmp/classifier_unexplained.out /tmp/classifier_risk_cold.out /tmp/classifier_risk_warn.out
printf 'class_classifier_asset_smoke: ok\n'
