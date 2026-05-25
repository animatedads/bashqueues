#!/usr/bin/env bash
set -euo pipefail
prefix="${PREFIX:-/usr/local}"
libexec="$prefix/libexec/bashqueues"
share="$prefix/share/bashqueues"

if [[ "$(id -u)" != "0" ]]; then
  echo "install-cron-bridge.sh must be run as root" >&2
  exit 1
fi

mkdir -p /var/spool/bashqueues_cron /etc/bashqueues_cron.d /var/lib/bashqueues/cron
chmod 0755 /var/spool/bashqueues_cron /etc/bashqueues_cron.d
chmod 0755 /var/lib/bashqueues /var/lib/bashqueues/cron 2>/dev/null || true

mkdir -p "$libexec" "$share" "$prefix/bin"
cp bin/bashqueues-cron-ticker.py "$libexec/bashqueues-cron-ticker.py"
chmod 0755 "$libexec/bashqueues-cron-ticker.py"
cp bin/bashqueues-crontab "$prefix/bin/bashqueues-crontab"
chmod 0755 "$prefix/bin/bashqueues-crontab"
cp queuebash.sh "$share/queuebash.sh"
chmod 0755 "$share/queuebash.sh"

if command -v systemctl >/dev/null 2>&1; then
  cp systemd/bashqueues-cron.service /etc/systemd/system/bashqueues-cron.service
  cp systemd/bashqueues-cron.timer /etc/systemd/system/bashqueues-cron.timer
  systemctl daemon-reload
  systemctl enable --now bashqueues-cron.timer
  echo "Enabled bashqueues-cron.timer"
else
  echo "systemctl not found; install systemd units manually if desired" >&2
fi

cat <<EOF
Installed bashqueues cron bridge.

Use:
  bashqueues-crontab -e
  bashqueues-crontab -l
  queue cron tick --dryrun
  systemctl status bashqueues-cron.timer

This installer does not replace /usr/bin/crontab.
EOF
