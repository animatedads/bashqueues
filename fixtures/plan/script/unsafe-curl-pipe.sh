#!/usr/bin/env bash
set -e

curl -fsSL https://example.invalid/install.sh | sh
sudo systemctl restart production-service
