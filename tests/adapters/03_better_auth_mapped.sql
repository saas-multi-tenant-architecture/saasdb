-- 03_better_auth_mapped.sql
-- Purpose: Verify @smta/better-auth MAPPED mode: arbitrary string ids map to UUIDs,
-- signup writes core.user_identities + core.users_meta, and get_current_user_id resolves.
BEGIN;
SELECT plan(4);

CREATE TABLE IF NOT EXISTS "user" (
  id TEXT PRIMARY KEY, email TEXT NOT NULL, name TEXT,
  "createdAt" TIMESTAMPTZ DEFAULT now(), "updatedAt" TIMESTAMPTZ DEFAULT now()
);
DROP TRIGGER IF EXISTS trg_on_better_auth_user_created ON "user";
CREATE TRIGGER trg_on_better_auth_user_created
AFTER INSERT ON "user" FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();

-- A non-UUID (cuid-style) id must NOT throw in mapped mode.
SELECT lives_ok(
  $$INSERT INTO "user" (id, email) VALUES ('cuid_abc123', 'mapped@test.example.com')$$,
  'mapped mode: non-UUID id inserts without error'
);

-- A mapping row exists.
SELECT ok(
  EXISTS (SELECT 1 FROM core.user_identities WHERE external_id = 'cuid_abc123'),
  'mapped mode: user_identities row created for external id'
);

-- users_meta row exists with the minted UUID.
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta um
    JOIN core.user_identities ui ON ui.user_id = um.id
    WHERE ui.external_id = 'cuid_abc123' AND um.email = 'mapped@test.example.com'
  ),
  'mapped mode: users_meta row minted and linked'
);

-- get_current_user_id resolves the external id from the session var to the UUID.
SELECT set_config('app.current_user_id', 'cuid_abc123', true);
SELECT is(
  core.get_current_user_id(),
  (SELECT user_id FROM core.user_identities WHERE external_id = 'cuid_abc123'),
  'mapped mode: get_current_user_id resolves external id to UUID'
);

SELECT * FROM finish();
ROLLBACK;
