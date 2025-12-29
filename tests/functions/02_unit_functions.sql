-- 02_unit_functions.sql
-- Purpose: Test public unit management functions

BEGIN;

SELECT plan(12);

-- ========================================
-- TEST: create_unit creates unit successfully
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT lives_ok(
  $$SELECT public.create_unit(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Waterfront',
    'New waterfront location'
  )$$,
  'create_unit should succeed'
);

-- Verify unit was created
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.units
    WHERE name = 'Waterfront'
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Unit should be created with correct name'
);

-- ========================================
-- TEST: unit_meta is created automatically (trigger)
-- ========================================
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.unit_meta um
    JOIN core.units u ON u.id = um.id
    WHERE u.name = 'Waterfront'
  ),
  'unit_meta should be created automatically for new unit'
);

-- ========================================
-- TEST: list_units returns correct units
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_units('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  4, -- Downtown, Airport, Mall, Waterfront
  'list_units should return 4 units'
);

-- ========================================
-- TEST: get_unit returns correct data
-- ========================================
SELECT ok(
  (SELECT name FROM public.get_unit('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')) = 'Downtown',
  'get_unit should return correct name'
);

SELECT ok(
  (SELECT description FROM public.get_unit('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')) = 'Downtown flagship location',
  'get_unit should return correct description'
);

-- ========================================
-- TEST: update_unit works
-- ========================================
SELECT lives_ok(
  $$SELECT public.update_unit(
    'aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
    'Downtown Updated',
    'Updated description'
  )$$,
  'update_unit should succeed'
);

SELECT ok(
  (SELECT name FROM public.get_unit('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')) = 'Downtown Updated',
  'Unit name should be updated'
);

-- ========================================
-- TEST: delete_unit soft-deletes
-- ========================================
-- Get the Waterfront unit ID
DO $$
DECLARE
  v_unit_id UUID;
BEGIN
  SELECT id INTO v_unit_id FROM core.units WHERE name = 'Waterfront';
  PERFORM set_config('test.unit_id', v_unit_id::text, true);
END $$;

SELECT lives_ok(
  format(
    $$SELECT public.delete_unit('%s'::uuid)$$,
    current_setting('test.unit_id')
  ),
  'delete_unit should succeed'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.units
    WHERE id = current_setting('test.unit_id')::uuid
      AND is_deleted = true
  ),
  'Unit should be soft-deleted'
);

-- ========================================
-- TEST: Deleted unit not in list_units
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_units('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  3, -- Downtown, Airport, Mall (Waterfront deleted)
  'Deleted unit should not appear in list_units'
);

-- ========================================
-- TEST: get_unit returns NULL for deleted unit
-- ========================================
SELECT ok(
  (SELECT id FROM public.get_unit(current_setting('test.unit_id')::uuid)) IS NULL,
  'get_unit should return NULL for deleted unit'
);

SELECT * FROM finish();

ROLLBACK;
