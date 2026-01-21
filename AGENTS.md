# AGENTS.md

Purpose: help agentic coding tools work effectively in this repo.

## Repository overview
- Primary artifacts live in `sql/` (DDL, functions, RLS) and `tests/` (pgTap).
- `schema_validation/` contains Zod v4 schemas + TS helpers.
- Build output is a combined SQL script written to `output/`.

## Build / lint / test commands
- Install deps: `pnpm install` (preferred) or `npm install`.
- Build combined SQL script: `pnpm build` or `npm run build`.
  - Runs `node ./combine_files.js` and writes to `output/SMTA Complete Script - <timestamp>.sql`.
- Test (full suite): `pnpm test` or `npm test`.
  - Runs `./run_tests.sh` which loads fixtures, runs pgTap tests, then cleans up.
- Lint: no lint script configured in `package.json`.

## Running a single test
- Use pgTap directly with `pg_prove`:
  - `pg_prove -d $DB_URL tests/rls/01_organizations_rls.sql`
  - `pg_prove -v postgresql://postgres:postgres@localhost:54322/postgres \
      tests/functions/01_organization_functions.sql`
- Category runs:
  - `pg_prove -d $DB_URL tests/schema/*.sql`
  - `pg_prove -d $DB_URL tests/rls/*.sql`
  - `pg_prove -d $DB_URL tests/platform/*.sql`

## Test prerequisites
- PostgreSQL + pgTap extension + `pg_prove` installed.
- A running Supabase/Postgres instance; `.env` provides connection vars.
- Copy env template: `cp .env.example .env`.
- Helpful check: `psql $DB_URL -c "SELECT 1"`.

## Repo-specific rules (Cursor/Copilot)
- No `.cursor/rules`, `.cursorrules`, or `.github/copilot-instructions.md` found.

## Code style guidelines

### SQL (primary code)
- Naming conventions:
  - Tables/columns use `snake_case` and lowercase.
  - Tables are plural nouns (e.g., `organizations`, `audit_logs`).
  - Foreign keys use `<entity>_id` (e.g., `organization_id`, `unit_id`).
  - Timestamps use `<action>_at` and actors use `<action>_by`.
  - Booleans are `is_`/`has_` prefixed.
  - Prefer `organization_id` over abbreviations like `org_id`.
- File layout:
  - SQL is grouped by schema under `sql/_core`, `sql/_platform`, `sql/_public`, `sql/_utils`.
  - Public RPCs live in `sql/_public/functions/`.
- Function conventions:
  - Use `CREATE OR REPLACE FUNCTION` with explicit parameters and return types.
  - `public` functions are `SECURITY INVOKER`; `platform` functions are `SECURITY DEFINER`.
  - Always set `SET search_path = <schema>` at the end of function definition.
  - Use `auth.uid()` to resolve caller identity instead of passing IDs from clients.
  - Validate access with helper functions (e.g., `core.is_org_member`).
  - Log writes with `core.log_audit(...)` (or platform equivalents).
  - Prefer explicit `RAISE EXCEPTION` with clear, user-facing messages.
- RLS and security:
  - RLS is enforced for tenant isolation; do not bypass it.
  - Avoid exposing raw tables in `public`; expose RPCs only.
- Formatting:
  - Indent with 2 spaces inside function bodies.
  - Use uppercase for SQL keywords (e.g., `CREATE`, `SELECT`, `INSERT`).
  - Keep line lengths readable; break long argument lists over multiple lines.

### SQL tests (pgTap)
- Each test file starts with `BEGIN;` and ends with `ROLLBACK;`.
- Use `SELECT plan(N)` with exact assertion count.
- End with `SELECT * FROM finish();` before `ROLLBACK;`.
- Do not include fixture loads in test files; `run_tests.sh` loads fixtures.
- Use helper functions from `test_helpers` (e.g., `set_auth_user`).

### TypeScript (schema validation)
- Zod v4 is the source of truth (`schema_validation/_schemas`).
- Export schema constants as `<name>Schema` in camelCase, e.g. `organizationsSchema`.
- Types are `z.infer<typeof ...>` re-exported in `schema_validation/_types`.
- Validation helpers return discriminated unions:
  - `{ success: true, data: ... }` or `{ success: false, error: ... }`.
- Formatting:
  - Use single quotes, semicolons, and 2-space indentation.
  - Prefer explicit `unknown` input types for validators.

### JavaScript (build tooling)
- Node scripts live at repo root (e.g., `combine_files.js`).
- Use `node:` built-in imports and async/await for file IO.
- Treat `output/` as generated; do not edit generated SQL manually.

## Error handling + safety
- SQL functions should validate inputs and permissions early with clear exceptions.
- Prefer deterministic errors over silent failures.
- Ensure soft-delete fields are maintained (`is_deleted`, `deleted_at`, `deleted_by`).
- When modifying functions or tables, update tests to cover new behavior.

## When adding new SQL artifacts
- Update `sql-scripts.json` ordering if the build should include new files.
- Keep schema boundaries (`core`, `platform`, `public`, `utils`) intact.
- Add or extend pgTap tests in the matching `tests/` category.
