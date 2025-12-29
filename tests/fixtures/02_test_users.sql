-- 02_test_users.sql
-- Purpose: Create test users for Bella Italia and Pizza Palace scenarios
--
-- Bella Italia Users:
-- - Maria (Owner/super_admin)
-- - Carlos (Regional Manager - Downtown & Airport)
-- - Sofia (Downtown Manager)
-- - Alex (Downtown Team, Mall Manager)
-- - Jordan (Airport & Mall Team)
-- - Sam (Downtown Team only)
-- - Taylor (Org member, no unit assignment)
--
-- Pizza Palace Users:
-- - Luigi (Owner/super_admin)
-- - Giuseppe (Team member)

-- ========================================
-- ENABLE UUID EXTENSION
-- ========================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ========================================
-- BELLA ITALIA USERS
-- ========================================

-- Maria - Owner
SELECT test_helpers.create_test_user(
  'maria@test.bellaitalia.com',
  'Maria',
  'Rossi'
);

-- Carlos - Regional Manager
SELECT test_helpers.create_test_user(
  'carlos@test.bellaitalia.com',
  'Carlos',
  'Garcia'
);

-- Sofia - Downtown Manager
SELECT test_helpers.create_test_user(
  'sofia@test.bellaitalia.com',
  'Sofia',
  'Martinez'
);

-- Alex - Multi-role (Team at Downtown, Manager at Mall)
SELECT test_helpers.create_test_user(
  'alex@test.bellaitalia.com',
  'Alex',
  'Johnson'
);

-- Jordan - Multi-site Team
SELECT test_helpers.create_test_user(
  'jordan@test.bellaitalia.com',
  'Jordan',
  'Lee'
);

-- Sam - Single-site Team
SELECT test_helpers.create_test_user(
  'sam@test.bellaitalia.com',
  'Sam',
  'Wilson'
);

-- Taylor - Org member, no units
SELECT test_helpers.create_test_user(
  'taylor@test.bellaitalia.com',
  'Taylor',
  'Brown'
);

-- ========================================
-- PIZZA PALACE USERS
-- ========================================

-- Luigi - Owner
SELECT test_helpers.create_test_user(
  'luigi@test.pizzapalace.com',
  'Luigi',
  'Conti'
);

-- Giuseppe - Team member
SELECT test_helpers.create_test_user(
  'giuseppe@test.pizzapalace.com',
  'Giuseppe',
  'Romano'
);

-- ========================================
-- STORE USER IDS FOR TEST REFERENCE
-- ========================================
DO $$
DECLARE
  v_maria UUID;
  v_carlos UUID;
  v_sofia UUID;
  v_alex UUID;
  v_jordan UUID;
  v_sam UUID;
  v_taylor UUID;
  v_luigi UUID;
  v_giuseppe UUID;
BEGIN
  -- Get user IDs
  SELECT id INTO v_maria FROM auth.users WHERE email = 'maria@test.bellaitalia.com';
  SELECT id INTO v_carlos FROM auth.users WHERE email = 'carlos@test.bellaitalia.com';
  SELECT id INTO v_sofia FROM auth.users WHERE email = 'sofia@test.bellaitalia.com';
  SELECT id INTO v_alex FROM auth.users WHERE email = 'alex@test.bellaitalia.com';
  SELECT id INTO v_jordan FROM auth.users WHERE email = 'jordan@test.bellaitalia.com';
  SELECT id INTO v_sam FROM auth.users WHERE email = 'sam@test.bellaitalia.com';
  SELECT id INTO v_taylor FROM auth.users WHERE email = 'taylor@test.bellaitalia.com';
  SELECT id INTO v_luigi FROM auth.users WHERE email = 'luigi@test.pizzapalace.com';
  SELECT id INTO v_giuseppe FROM auth.users WHERE email = 'giuseppe@test.pizzapalace.com';

  -- Store in config for easy access in tests
  PERFORM set_config('test.user_maria', v_maria::text, false);
  PERFORM set_config('test.user_carlos', v_carlos::text, false);
  PERFORM set_config('test.user_sofia', v_sofia::text, false);
  PERFORM set_config('test.user_alex', v_alex::text, false);
  PERFORM set_config('test.user_jordan', v_jordan::text, false);
  PERFORM set_config('test.user_sam', v_sam::text, false);
  PERFORM set_config('test.user_taylor', v_taylor::text, false);
  PERFORM set_config('test.user_luigi', v_luigi::text, false);
  PERFORM set_config('test.user_giuseppe', v_giuseppe::text, false);
END $$;

-- ========================================
-- NOTES
-- ========================================
-- User IDs are deterministic (based on email via uuid_generate_v5)
-- This allows tests to reference users consistently across runs
-- The trg_on_auth_user_created trigger automatically creates users_meta rows
