# Testing Guide

## Overview

This project uses **pgTap** for PostgreSQL database testing. Tests are organized into logical categories and executed in a specific order to ensure proper setup and isolation.

## Prerequisites

1. **PostgreSQL** with **pgTap extension** installed
2. **pg_prove** command-line tool
3. A running PostgreSQL/Supabase database instance

### Installing pgTap and pg_prove

**Ubuntu/Debian:**
```bash
sudo apt-get install postgresql-pgtap
sudo apt-get install libtap-parser-sourcehandler-pgtap-perl
```

**macOS:**
```bash
brew install pgtap
```

**Verify installation:**
```bash
pg_prove --version
```

## Setup

1. **Copy environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Configure database connection** in `.env`:
   ```bash
   # For local Supabase (default)
   DB_HOST=localhost
   DB_PORT=54322
   DB_NAME=postgres
   DB_USER=postgres
   DB_PASSWORD=postgres
   ```

3. **Ensure your database schema is deployed:**
   ```bash
   # If using Supabase CLI
   supabase db reset

   # Or manually apply SQL files
   psql $DB_URL -f sql/00_init/schemas.sql
   # ... apply remaining SQL files
   ```

## Running Tests

### Run all tests:
```bash
npm test
```

Or directly:
```bash
./run_tests.sh
```

### Run specific test category:
```bash
# Schema tests only
pg_prove -d $DB_URL tests/schema/*.sql

# RLS tests only
pg_prove -d $DB_URL tests/rls/*.sql

# Platform tests only
pg_prove -d $DB_URL tests/platform/*.sql
```

### Run a single test file:
```bash
pg_prove -v postgresql://postgres:postgres@localhost:54322/postgres \
  tests/rls/01_organizations_rls.sql
```

## Test Structure

Tests are organized into the following categories (executed in this order):

1. **`tests/fixtures/`** - Test data and helper functions (loaded once at start)
   - `00_test_helpers.sql` - pgTap setup and helper functions
   - `01_roles.sql` - Standard role definitions
   - `02_test_users.sql` - Test user accounts
   - `03_bella_italia.sql` - Bella Italia organization test data
   - `04_pizza_palace.sql` - Pizza Palace organization test data
   - `05_platform.sql` - Platform admin test data

2. **`tests/schema/`** - Schema and table structure validation
3. **`tests/membership/`** - Role and membership logic
4. **`tests/triggers/`** - Database trigger functionality
5. **`tests/platform/`** - Platform admin functions
6. **`tests/functions/`** - Public RPC functions
7. **`tests/rls/`** - Row Level Security policies
8. **`tests/edge_cases/`** - Complex scenarios and edge cases

## Test Execution Flow

The `run_tests.sh` script follows this flow:

1. **Setup Phase** - Loads all fixtures (test helpers, roles, users, organizations)
2. **Test Phase** - Executes all test files in order using `pg_prove`
3. **Cleanup Phase** - Removes all test data using `test_helpers.cleanup_test_data()`

## Writing Tests

### Test File Template

```sql
-- test_name.sql
-- Purpose: Brief description of what this test validates

BEGIN;

SELECT plan(5); -- Number of tests in this file

-- ========================================
-- TEST: Description of what you're testing
-- ========================================
SELECT ok(
  condition_to_test,
  'Human-readable description of test'
);

SELECT * FROM finish();

ROLLBACK;
```

### Important Notes

- Each test file must begin with `BEGIN;` and end with `ROLLBACK;`
- Do NOT include `\i` fixture loads in individual test files (fixtures are loaded by `run_tests.sh`)
- Use `SELECT plan(N)` where N is the exact number of test assertions
- Always use `SELECT * FROM finish()` before `ROLLBACK;`
- Use helper functions from `test_helpers` schema (e.g., `test_helpers.set_auth_user()`)

### Available Test Helpers

```sql
-- Simulate authentication as a user
SELECT test_helpers.set_auth_user('user-uuid-here');

-- Clear authentication (simulate anonymous)
SELECT test_helpers.clear_auth_user();

-- Set service role for platform operations
SELECT test_helpers.set_service_role();

-- Create a test user
SELECT test_helpers.create_test_user('email@example.com', 'First', 'Last');

-- Clean up all test data (run by test script)
SELECT test_helpers.cleanup_test_data();
```

## Common pgTap Assertions

```sql
-- Boolean assertions
SELECT ok(condition, 'description');
SELECT is(actual, expected, 'description');
SELECT isnt(actual, expected, 'description');

-- Existence checks
SELECT has_table('schema', 'table_name', 'description');
SELECT has_column('schema', 'table', 'column', 'description');
SELECT has_function('schema', 'function_name', 'description');

-- Exception testing
SELECT lives_ok($$SQL STATEMENT$$, 'description');
SELECT throws_ok($$SQL STATEMENT$$, 'expected error message', 'description');
```

## Troubleshooting

### Tests fail with "relation does not exist"
- Ensure database schema is fully deployed before running tests
- Check that fixtures loaded successfully

### Tests fail with "function auth.uid() does not exist"
- Verify you're testing against a Supabase database or have Supabase auth functions installed

### Connection refused
- Check database is running
- Verify `.env` connection parameters
- Test connection: `psql $DB_URL -c "SELECT 1"`

### pg_prove not found
- Install pg_prove (see Prerequisites above)
- Ensure it's in your PATH

## Continuous Integration

To run tests in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run database tests
  run: |
    cp .env.example .env
    # Update .env with CI database credentials
    npm test
```

## Additional Resources

- [pgTap Documentation](https://pgtap.org/)
- [pg_prove Documentation](https://pgtap.org/pg_prove.html)
- [Supabase Testing Guide](https://supabase.com/docs/guides/database/testing)
