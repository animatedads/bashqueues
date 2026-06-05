#!/usr/bin/env bash
set -euo pipefail

command -v psql >/dev/null
: "${DATABASE_URL:?missing database url}"

for step in precheck migrate verify; do
  echo "running $step"
done

psql "$DATABASE_URL" -f ./migrations/001_init.sql
