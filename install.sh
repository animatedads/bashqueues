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


# Install bundled asset plugins without overwriting user/site edits.
QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-$HOME/.queuebash}"
mkdir -p "$QUEUEBASH_ROOT/assets.d"
if [[ -d "$(dirname "$0")/assets.d" ]]; then
  for plugin in "$(dirname "$0")"/assets.d/*.sh; do
    [[ -f "$plugin" ]] || continue
    dst="$QUEUEBASH_ROOT/assets.d/$(basename "$plugin")"
    if [[ ! -e "$dst" ]]; then
      cp "$plugin" "$dst"
      chmod +x "$dst" 2>/dev/null || true
      echo "Installed asset plugin: $dst"
    else
      echo "Keeping existing asset plugin: $dst"
    fi
  done
fi
