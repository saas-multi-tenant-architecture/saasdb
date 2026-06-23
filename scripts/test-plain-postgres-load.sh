#!/usr/bin/env bash
# test-plain-postgres-load.sh
# Applies a generated SMTA SQL file against a stock postgres:18 container in a
# single rolled-forward transaction with ON_ERROR_STOP. Exits non-zero on any
# load error (undefined role, missing auth.*, etc). Nothing is left committed
# because we drop the database afterward.
#
# Usage: scripts/test-plain-postgres-load.sh <sql-file> <container-name>
set -euo pipefail

SQL_FILE="${1:?usage: test-plain-postgres-load.sh <sql-file> <container-name>}"
CONTAINER="${2:?usage: test-plain-postgres-load.sh <sql-file> <container-name>}"
DB="smta_load_test"

if [ ! -f "$SQL_FILE" ]; then
  echo "ERROR: SQL file not found: $SQL_FILE" >&2
  exit 2
fi

cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=postgres postgres:18 >/dev/null

# Wait for readiness (max ~30s)
for i in $(seq 1 30); do
  if docker exec "$CONTAINER" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done

docker exec "$CONTAINER" psql -U postgres -c "CREATE DATABASE $DB" >/dev/null

echo "Applying $SQL_FILE ..."
docker exec -i "$CONTAINER" psql -U postgres -d "$DB" \
  -v ON_ERROR_STOP=1 --single-transaction < "$SQL_FILE"

echo "OK: $SQL_FILE loaded cleanly on vanilla PostgreSQL 18"
