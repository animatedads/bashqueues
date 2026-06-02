#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(8[1-9]|[9-9][0-9])"' queuebash.sh
grep -q '_queue_cloud_command()' queuebash.sh
grep -q 'queue cloud - unified cloud broker front' queuebash.sh
grep -q 'cloud|cloud-broker|cloud_broker)' queuebash.sh

test -x providers.d/cloud_broker/cloud_broker_provider.sh
bash -n providers.d/cloud_broker/cloud_broker_provider.sh

grep -q 'queuebash.cloud_broker.explain.v1' providers.d/cloud_broker/cloud_broker_provider.sh
grep -Eq 'live cloud API discovery|does not' docs/CLOUD_BROKER_FRONT.md
