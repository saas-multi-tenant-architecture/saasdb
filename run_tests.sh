#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file configuration
LOG_FILE="./tests/test_logs/test_results_$(date +%Y%m%d_%H%M%S).log"
QUIET_MODE="${QUIET_MODE:-false}"

# Load environment variables from .env if it exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Database connection parameters (with defaults for local Supabase)
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-54322}"
DB_NAME="${DB_NAME:-postgres}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_SSLMODE="${DB_SSLMODE:-disable}"
DB_PROJECT_REF="${DB_PROJECT_REF:-}"

# Construct connection URL
# Supabase pooler (port 6543) uses "postgres.PROJECT_REF" username format.
# Local/direct connections (port 54322) use plain "postgres".
if [[ -n "$DB_PROJECT_REF" ]]; then
  DB_QUALIFIED_USER="${DB_USER}.${DB_PROJECT_REF}"
else
  DB_QUALIFIED_USER="${DB_USER}"
fi
DB_URL="postgresql://${DB_QUALIFIED_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=${DB_SSLMODE}"

echo -e "${YELLOW}=== SMTA Test Suite ===${NC}"
echo "Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo ""

# Check if pg_prove is installed
if ! command -v pg_prove &> /dev/null; then
  echo -e "${RED}ERROR: pg_prove is not installed${NC}"
  echo "Install with: sudo apt-get install libtap-parser-sourcehandler-pgtap-perl"
  echo "Or on macOS: brew install pgtap"
  exit 1
fi

# Check if database is accessible
if ! psql "$DB_URL" -c "SELECT 1" &> /dev/null; then
  echo -e "${RED}ERROR: Cannot connect to database${NC}"
  echo "Connection URL: ${DB_URL}"
  exit 1
fi

echo -e "${GREEN}✓ Database connection successful${NC}"
echo ""

# ========================================
# SETUP: Load test fixtures
# ========================================
echo -e "${YELLOW}=== Setting up test fixtures ===${NC}"
echo "=== Setting up test fixtures ===" > "$LOG_FILE"

# Use -q to suppress notices during fixture loading
psql "$DB_URL" -q -f tests/fixtures/00_test_helpers.sql 2>> "$LOG_FILE"
echo "✓ Loaded test helpers"

psql "$DB_URL" -q -f tests/fixtures/01_roles.sql 2>> "$LOG_FILE"
echo "✓ Loaded roles"

psql "$DB_URL" -q -f tests/fixtures/02_test_users.sql 2>> "$LOG_FILE"
echo "✓ Loaded test users"

psql "$DB_URL" -q -f tests/fixtures/03_bella_italia.sql 2>> "$LOG_FILE"
echo "✓ Loaded Bella Italia test data"

psql "$DB_URL" -q -f tests/fixtures/04_pizza_palace.sql 2>> "$LOG_FILE"
echo "✓ Loaded Pizza Palace test data"

psql "$DB_URL" -q -f tests/fixtures/05_platform.sql 2>> "$LOG_FILE"
echo "✓ Loaded platform test data"

echo ""

# ========================================
# RUN: Execute tests with pg_prove
# ========================================
echo -e "${YELLOW}=== Running tests ===${NC}"
echo ""
echo "=== Running tests ===" >> "$LOG_FILE"
echo "Output saved to: $LOG_FILE"
echo ""

# Export connection parameters for pg_prove/psql
export PGHOST="$DB_HOST"
export PGPORT="$DB_PORT"
export PGDATABASE="$DB_NAME"
export PGUSER="${DB_QUALIFIED_USER}"
export PGPASSWORD="$DB_PASSWORD"
export PGSSLMODE="$DB_SSLMODE"
# Suppress NOTICE/INFO messages from PostgreSQL (reduces noise like "SQL function X statement Y")
export PGOPTIONS="-c client_min_messages=WARNING"

# Run tests in logical order
# Using -v for verbose output, pipe to tee to save and display
pg_prove -v \
  tests/schema/01_schemas_exist.sql \
  tests/schema/02_core_tables.sql \
  tests/schema/03_platform_tables.sql \
  tests/schema/04_indexes.sql \
  tests/schema/05_triggers.sql \
  tests/membership/01_roles_exist.sql \
  tests/membership/02_super_admin_protection.sql \
  tests/membership/03_transfer_super_admin.sql \
  tests/membership/04_organization_membership.sql \
  tests/membership/05_unit_membership.sql \
  tests/triggers/01_updated_at_triggers.sql \
  tests/triggers/02_auto_create_triggers.sql \
  tests/platform/01_platform_roles.sql \
  tests/platform/02_platform_users.sql \
  tests/platform/03_platform_settings.sql \
  tests/platform/04_feature_flags.sql \
  tests/functions/01_organization_functions.sql \
  tests/functions/02_unit_functions.sql \
  tests/functions/03_membership_functions.sql \
  tests/functions/04_user_functions.sql \
  tests/invitations/01_create_invitation.sql \
  tests/invitations/02_accept_invitation.sql \
  tests/invitations/03_manage_invitations.sql \
  tests/rls/01_organizations_rls.sql \
  tests/rls/08_organizations_meta_rls.sql \
  tests/rls/02_units_rls.sql \
  tests/rls/03_memberships_rls.sql \
  tests/rls/04_unit_memberships_rls.sql \
  tests/rls/05_users_meta_rls.sql \
  tests/rls/06_audit_logs_rls.sql \
  tests/rls/07_invitations_rls.sql \
  tests/edge_cases/01_multi_org_user.sql \
  tests/edge_cases/02_cascading_deletes.sql \
  tests/edge_cases/03_concurrent_access.sql \
  tests/edge_cases/04_role_scenarios.sql \
  2>&1 | tee -a "$LOG_FILE"

TEST_EXIT_CODE=${PIPESTATUS[0]}

echo ""

# ========================================
# CLEANUP: Remove test data
# ========================================
echo -e "${YELLOW}=== Cleaning up test data ===${NC}"

psql "$DB_URL" -c "SELECT test_helpers.cleanup_test_data();" > /dev/null
echo "✓ Test data cleaned up"

echo ""

# ========================================
# SUMMARY
# ========================================
echo ""
echo "Full output saved to: $LOG_FILE"
echo ""

if [ $TEST_EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}=== All tests passed! ===${NC}"
  echo "=== All tests passed! ===" >> "$LOG_FILE"
  exit 0
else
  echo -e "${RED}=== Some tests failed ===${NC}"
  echo "=== Some tests failed ===" >> "$LOG_FILE"
  exit $TEST_EXIT_CODE
fi
