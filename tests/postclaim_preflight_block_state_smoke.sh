#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec tests/postclaim_preflight_waiting_state_smoke.sh
