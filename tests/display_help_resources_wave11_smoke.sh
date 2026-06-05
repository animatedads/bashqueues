#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh
cluster_out="$(queue cluster help)"
enterprise_out="$(queue enterprise help)"
printf '%s\n' "$cluster_out" | grep -Fq 'Usage: queue cluster status [--json]'
printf '%s\n' "$cluster_out" | grep -Fq 'standalone-safe'
printf '%s\n' "$enterprise_out" | grep -Fq 'Usage: queue enterprise verify-profile PROFILE [--json]'
printf '%s\n' "$enterprise_out" | grep -Fq 'fixture/contract helpers'
echo 'display_help_resources_wave11_smoke: ok'
