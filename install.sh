#!/usr/bin/env bash
set -euo pipefail

install_dir="${HOME}/.local/share/bashqueues"
target="${install_dir}/queuebash.sh"
bashrc="${HOME}/.bashrc"

mkdir -p "$install_dir"
cp "$(dirname "$0")/queuebash.sh" "$target"
chmod 755 "$target"

source_line='source "$HOME/.local/share/bashqueues/queuebash.sh"'

if ! grep -Fq "$source_line" "$bashrc" 2>/dev/null; then
    {
        echo
        echo "# bashqueues"
        echo "$source_line"
    } >> "$bashrc"
    echo "Added bashqueues source line to $bashrc"
else
    echo "bashqueues source line already present in $bashrc"
fi

echo "Installed queuebash to $target"
echo "Run: source ~/.bashrc"
