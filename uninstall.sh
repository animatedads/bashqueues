#!/usr/bin/env bash
set -euo pipefail

target="${HOME}/.local/share/bashqueues/queuebash.sh"
bashrc="${HOME}/.bashrc"
source_line='source "$HOME/.local/share/bashqueues/queuebash.sh"'

rm -f "$target"

if [[ -f "$bashrc" ]]; then
    tmp="$(mktemp)"
    grep -Fv "$source_line" "$bashrc" > "$tmp" || true
    mv "$tmp" "$bashrc"
fi

echo "Removed queuebash. Existing queue data under ~/.queuebash was not deleted."
