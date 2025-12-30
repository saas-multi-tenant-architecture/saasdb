#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
DB_HOST="${DB_HOST:-aws-0-us-east-1.pooler.supabase.com}"
DB_SSLMODE="${DB_SSLMODE:-require}"
DB_PROJECT_REF="${DB_PROJECT_REF:-}"

# Construct connection URL
# postgres://postgres.<PROJECT_REF>:<PASSWORD>@aws-0-<REGION>.pooler.supabase.com:5432/postgres?sslmode=require"
DB_URL="postgresql://postgres.${DB_PROJECT_REF}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=${DB_SSLMODE}"

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

psql "$DB_URL" -f tests/fixtures/00_test_helpers.sql
echo "✓ Loaded test helpers"

psql "$DB_URL" -f tests/fixtures/01_roles.sql
echo "✓ Loaded roles"

psql "$DB_URL" -f tests/fixtures/02_test_users.sql
echo "✓ Loaded test users"

psql "$DB_URL" -f tests/fixtures/03_bella_italia.sql
echo "✓ Loaded Bella Italia test data"

psql "$DB_URL" -f tests/fixtures/04_pizza_palace.sql
echo "✓ Loaded Pizza Palace test data"

psql "$DB_URL" -f tests/fixtures/05_platform.sql
echo "✓ Loaded platform test data"

echo ""

# ========================================
# RUN: Execute tests with pg_prove
# ========================================
echo -e "${YELLOW}=== Running tests ===${NC}"
echo ""

# Run tests in logical order
# Using -v for verbose output
pg_prove -v "$DB_URL" \
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
  tests/rls/02_units_rls.sql \
  tests/rls/03_memberships_rls.sql \
  tests/rls/04_unit_memberships_rls.sql \
  tests/rls/05_users_meta_rls.sql \
  tests/rls/06_audit_logs_rls.sql \
  tests/rls/07_invitations_rls.sql \
  tests/edge_cases/01_multi_org_user.sql \
  tests/edge_cases/02_cascading_deletes.sql \
  tests/edge_cases/03_concurrent_access.sql \
  tests/edge_cases/04_role_scenarios.sql

TEST_EXIT_CODE=$?

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
if [ $TEST_EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}=== All tests passed! ===${NC}"
  exit 0
else
  echo -e "${RED}=== Some tests failed ===${NC}"
  exit $TEST_EXIT_CODE
fi
