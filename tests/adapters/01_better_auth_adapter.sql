-- 01_better_auth_adapter.sql
-- Purpose: Verify @smta/better-auth adapter (UUID mode) — auth impl, new-user trigger, and RLS chain.
-- Run standalone against a better-auth-deployed database:
--   pg_prove -v <db_url> tests/adapters/01_better_auth_adapter.sql

BEGIN;

SELECT plan(8);

-- ========================================
-- SECTION 1: core.get_current_user_id()
-- Tests that the better-auth impl reads from app.current_user_id
-- ========================================

-- Set a known UUID and verify the function returns it
SELECT set_config('app.current_user_id', 'aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa', true);

SELECT is(
  core.get_current_user_id(),
  'aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa'::UUID,
  'get_current_user_id() returns UUID from app.current_user_id when set'
);

-- Set a different UUID to verify it reads the current value (not cached)
SELECT set_config('app.current_user_id', 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb', true);

SELECT is(
  core.get_current_user_id(),
  'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'::UUID,
  'get_current_user_id() returns updated UUID after config change'
);

-- Clear the setting and verify NULL is returned (not an exception)
SELECT set_config('app.current_user_id', '', true);

SELECT is(
  core.get_current_user_id(),
  NULL::UUID,
  'get_current_user_id() returns NULL when app.current_user_id is empty string'
);

-- ========================================
-- SECTION 2: new-user trigger
-- Tests that INSERT into better-auth user table creates core.users_meta
-- ========================================

-- Create a minimal user table stub for trigger testing
-- (If better-auth is deployed, this is a no-op; trigger will already exist)
CREATE TABLE IF NOT EXISTS "user" (
  id TEXT NOT NULL PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ DEFAULT NOW()
);

-- Attach the trigger function (idempotent — safe to run in any env)
DROP TRIGGER IF EXISTS trg_on_better_auth_user_created ON "user";
CREATE TRIGGER trg_on_better_auth_user_created
AFTER INSERT ON "user"
FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();

-- Insert a valid UUID user — trigger should create users_meta row
INSERT INTO "user" (id, email, name)
VALUES ('cccccccc-3333-3333-3333-cccccccccccc', 'trigger@test.example.com', 'Trigger Test');

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = 'cccccccc-3333-3333-3333-cccccccccccc'::UUID
      AND email = 'trigger@test.example.com'
  ),
  'INSERT into user table creates corresponding core.users_meta row'
);

-- Verify email is copied correctly
SELECT is(
  (SELECT email FROM core.users_meta WHERE id = 'cccccccc-3333-3333-3333-cccccccccccc'::UUID),
  'trigger@test.example.com',
  'users_meta.email matches better-auth user email'
);

-- Non-UUID id should raise an exception from the ::UUID cast in the trigger
SELECT throws_ok(
  $$INSERT INTO "user" (id, email) VALUES ('not-a-uuid', 'bad@example.com')$$,
  'invalid input syntax for type uuid: "not-a-uuid"',
  'non-UUID id raises cast exception — enforces UUID configuration requirement'
);

-- ========================================
-- SECTION 3: RLS chain end-to-end
-- Tests that app.current_user_id drives SMTA RLS correctly
-- Requires fixture data: org aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa must exist
-- and user maria@test.bellaitalia.com must be a member.
-- ========================================

-- Set user who has membership in the Bella Italia org
SELECT test_helpers.set_auth_user(
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'RLS: org member can see their organization'
);

-- Set a user with no memberships — should see zero organizations
SELECT set_config('app.current_user_id', 'ffffffff-ffff-ffff-ffff-ffffffffffff', true);

SELECT is(
  (SELECT count(*)::int FROM core.organizations),
  0,
  'RLS: user with no memberships sees zero organizations'
);

SELECT * FROM finish();
ROLLBACK;
