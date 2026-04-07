#!/usr/bin/env bash
# Restore latest prod dump into DEV (safety-checked). Resets public schema.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
exec node scripts/db/db-cli.mjs restore
