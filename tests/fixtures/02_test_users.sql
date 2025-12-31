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
-- NOTES
-- ========================================
-- User IDs are deterministic (based on email via uuid_generate_v5)
-- This allows tests to reference users consistently across runs
-- Use test_helpers.get_test_user_id('email@example.com') to get the UUID
-- The trg_on_auth_user_created trigger automatically creates users_meta rows
