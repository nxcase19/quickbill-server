#!/usr/bin/env bash
# [1/3] dump prod → [2/3] restore dev → [3/3] normalize dev
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
exec node scripts/db/db-cli.mjs sync
