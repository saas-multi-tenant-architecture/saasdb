-- tests/003_run_tests.sql
-- Execute core and platform tests using seeded data

\i tests/001_setup_auth.sql
\i 016_test_seed_core_roles.sql
\i 015_test_seed_core.sql
\i 017_test_seed_platform.sql
\i tests/002_test_framework.sql

-- Test: get_user_profile returns correct data for admin
SELECT auth.set_uid(:tenant_admin_id);
DO $$
DECLARE v_first TEXT;
BEGIN
  SELECT first_name INTO v_first FROM public.get_user_profile();
  PERFORM test.assert_true(v_first = 'Alice', 'get_user_profile as admin');
END;$$;

-- Test: tenant user cannot update organization metadata
SELECT auth.set_uid(:tenant_user_id);
DO $$
BEGIN
  PERFORM test.assert_raises(
    $$UPDATE core.s SET address='Hack St' WHERE id='10000000-0000-0000-0000-000000000001'$$,
    'user cannot update organizations_meta'
  );
END;$$;

-- Test: admin can update organization metadata
SELECT auth.set_uid(:tenant_admin_id);
UPDATE core.organizations_meta SET address='456 Main St' WHERE id='10000000-0000-0000-0000-000000000001';
DO $$
DECLARE v_addr TEXT;
BEGIN
  SELECT address INTO v_addr FROM core.organizations_meta WHERE id='10000000-0000-0000-0000-000000000001';
  PERFORM test.assert_true(v_addr = '456 Main St', 'admin updated organizations_meta');
END;$$;

-- Test: list_my_organizations works for normal user
SELECT auth.set_uid(:tenant_user_id);
DO $$
DECLARE v_count INT;
BEGIN
  SELECT count(*) INTO v_count FROM public.list_my_organizations();
  PERFORM test.assert_true(v_count = 1, 'list_my_organizations returns one row');
END;$$;

-- Test: platform admin role retrieval
SELECT auth.set_uid(:platform_admin_id);
DO $$
DECLARE v_role TEXT;
BEGIN
  SELECT platform.get_platform_user_role() INTO v_role;
  PERFORM test.assert_true(v_role = 'admin', 'platform admin role retrieval');
END;$$;

-- Test: tenant admin cannot call platform function
SELECT auth.set_uid(:tenant_admin_id);
DO $$
BEGIN
  PERFORM test.assert_raises('SELECT platform.get_platform_user_role()', 'tenant admin blocked from platform function');
END;$$;

-- Test: tenant admin cannot read platform table
DO $$
BEGIN
  PERFORM test.assert_raises('SELECT * FROM platform.platform_users', 'tenant admin blocked from reading platform table');
END;$$;

-- Test: other admin cannot read first organization
SELECT auth.set_uid(:other_admin_id);
DO $$
DECLARE c INT;
BEGIN
  SELECT count(*) INTO c FROM core.organizations WHERE id='10000000-0000-0000-0000-000000000001';
  PERFORM test.assert_true(c = 0, 'other admin cannot view org1');
END;$$;

-- Test: org member can view another member profile
SELECT auth.set_uid(:tenant_user_id);
DO $$
DECLARE c INT;
BEGIN
  SELECT count(*) INTO c FROM core.users_meta WHERE id = :'tenant_admin_id';
  PERFORM test.assert_true(c = 1, 'member can read admin profile');
END;$$;

-- Test: outsider cannot view user profile
SELECT auth.set_uid(:other_admin_id);
DO $$
DECLARE c INT;
BEGIN
  SELECT count(*) INTO c FROM core.users_meta WHERE id = :'tenant_admin_id';
  PERFORM test.assert_true(c = 0, 'non member cannot read user profile');
END;$$;

-- Test: user cannot update other user profile
SELECT auth.set_uid(:tenant_user_id);
DO $$
BEGIN
  PERFORM test.assert_raises(
    $$UPDATE core.users_meta SET first_name='Evil' WHERE id=:'tenant_admin_id'$$,
    'user blocked from updating other profile'
  );
END;$$;

-- Test: normal user cannot create unit
DO $$
BEGIN
  PERFORM test.assert_raises(
    $$SELECT * FROM public.create_unit('10000000-0000-0000-0000-000000000001','Sneaky Unit')$$,
    'non admin blocked from create_unit'
  );
END;$$;

-- Test: admin creates a unit and assigns user
SELECT auth.set_uid(:tenant_admin_id);
SELECT id FROM public.create_unit('10000000-0000-0000-0000-000000000001','Acme West') INTO TEMP TABLE new_unit;
SELECT id FROM new_unit LIMIT 1 \gset
DO $$
BEGIN
  PERFORM public.assign_user_to_unit(:tenant_user_id, :'id', (SELECT id FROM core.roles WHERE name='manager'));
END;$$;
DO $$
DECLARE c INT;
BEGIN
  SELECT count(*) INTO c FROM core.unit_memberships WHERE unit_id = :'id' AND user_id = :tenant_user_id;
  PERFORM test.assert_true(c = 1, 'admin assigned user to new unit');
END;$$;

-- Test: user sees two units after assignment
SELECT auth.set_uid(:tenant_user_id);
DO $$
DECLARE c INT;
BEGIN
  SELECT count(*) INTO c FROM public.list_my_units();
  PERFORM test.assert_true(c = 2, 'list_my_units shows two units');
END;$$;
