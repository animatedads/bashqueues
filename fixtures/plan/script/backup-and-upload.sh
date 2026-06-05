#!/usr/bin/env bash
set -euo pipefail

: "${PGDATABASE:?missing database name}"
: "${BACKUP_BUCKET:?missing backup bucket}"
command -v pg_dump >/dev/null
command -v aws >/dev/null

backup_dir="/var/backups/example-app"
mkdir -p "$backup_dir"
out="$backup_dir/example-${PGDATABASE}.sql.gz"

pg_dump "$PGDATABASE" | gzip > "$out"
aws s3 cp "$out" "s3://${BACKUP_BUCKET}/"
