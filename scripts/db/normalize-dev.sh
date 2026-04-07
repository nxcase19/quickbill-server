#!/usr/bin/env bash
# Apply normalize-dev.sql to DEV_DATABASE_URL only
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
exec node scripts/db/db-cli.mjs normalize
