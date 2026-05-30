#!/usr/bin/env bash
# Typed, ACL-gated remote-admin policy command helper. Not a shell/editor.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "$here/remote_admin_policy.py" "$@"
