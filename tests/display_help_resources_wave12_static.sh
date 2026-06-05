#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for path in   resources.d/display/lang_eng/plan-help.txt   resources.d/display/fallback/plan-help.txt; do
  [[ -f "$path" ]] || { echo "missing resource: $path" >&2; exit 1; }
  grep -Fq "queue plan scan PATH" "$path" || { echo "missing scan usage in $path" >&2; exit 1; }
  grep -Fq "queue.control_plan.v1" "$path" || { echo "missing schema mention in $path" >&2; exit 1; }
  ! grep -Eq '\$\(|`' "$path" || { echo "resource contains shell-like substitution syntax: $path" >&2; exit 1; }
done

grep -Fq '_queue_resource_fetch_i18nl_command --name plan-help.txt' queuebash.sh || {
  echo "queue plan help is not resource-backed" >&2
  exit 1
}

if awk '/_queue_plan_command\(\)/,/^}/ { print }' queuebash.sh | grep -Fq "cat <<'EOF'"; then
  echo "_queue_plan_command still embeds heredoc help" >&2
  exit 1
fi

echo "PASS display_help_resources_wave12_static"
