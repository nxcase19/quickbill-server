#!/usr/bin/env bash
# Dump production → scripts/db/backups/prod_dump_YYYYMMDD_HHMMSS.sql
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
exec node scripts/db/db-cli.mjs dump
