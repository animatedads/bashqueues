#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for f in code-help.txt code-sign-help.txt code-verify-help.txt code-audit-help.txt code-trust-help.txt; do
  test -s "resources.d/display/lang_eng/$f"
  test -s "resources.d/display/fallback/$f"
done
grep -q "code-help.txt" queuebash.sh
grep -q "code-sign-help.txt" queuebash.sh
grep -q "code-verify-help.txt" queuebash.sh
grep -q "code-audit-help.txt" queuebash.sh
grep -q "code-trust-help.txt" queuebash.sh
! grep -q 'echo "Usage: queue code sign|verify|audit|trust|policy"' queuebash.sh
! grep -q 'echo "Usage: queue code sign --all' queuebash.sh
! grep -q 'echo "Usage: queue code verify' queuebash.sh
! grep -q 'echo "Usage: queue code audit' queuebash.sh
! grep -q 'echo "Usage: queue code trust --public-key' queuebash.sh
