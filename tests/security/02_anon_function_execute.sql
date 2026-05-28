-- 02_anon_function_execute.sql
-- Purpose: Verify anon role cannot EXECUTE admin SECURITY DEFINER functions,
-- but authenticated still can. Public-by-design functions remain anon-callable.

BEGIN;

SELECT plan(16);

-- Admin functions: anon should NOT have EXECUTE
SELECT ok(
  NOT has_function_privilege('anon', 'public.add_member_to_organization(uuid, uuid, uuid)', 'EXECUTE'),
  'anon must NOT execute add_member_to_organization'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.add_member_to_unit(uuid, uuid, uuid)', 'EXECUTE'),
  'anon must NOT execute add_member_to_unit'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.delete_organization(uuid)', 'EXECUTE'),
  'anon must NOT execute delete_organization'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.delete_unit(uuid)', 'EXECUTE'),
  'anon must NOT execute delete_unit'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.remove_member_from_organization(uuid, uuid)', 'EXECUTE'),
  'anon must NOT execute remove_member_from_organization'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.remove_member_from_unit(uuid, uuid)', 'EXECUTE'),
  'anon must NOT execute remove_member_from_unit'
);

-- Admin functions: authenticated MUST have EXECUTE
SELECT ok(
  has_function_privilege('authenticated', 'public.add_member_to_organization(uuid, uuid, uuid)', 'EXECUTE'),
  'authenticated must execute add_member_to_organization'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.add_member_to_unit(uuid, uuid, uuid)', 'EXECUTE'),
  'authenticated must execute add_member_to_unit'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.delete_organization(uuid)', 'EXECUTE'),
  'authenticated must execute delete_organization'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.delete_unit(uuid)', 'EXECUTE'),
  'authenticated must execute delete_unit'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.remove_member_from_organization(uuid, uuid)', 'EXECUTE'),
  'authenticated must execute remove_member_from_organization'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.remove_member_from_unit(uuid, uuid)', 'EXECUTE'),
  'authenticated must execute remove_member_from_unit'
);

-- service_role MUST retain EXECUTE on admin functions
SELECT ok(
  has_function_privilege('service_role', 'public.delete_organization(uuid)', 'EXECUTE'),
  'service_role must execute delete_organization'
);

-- Intentionally-public endpoints remain callable by both anon and authenticated
SELECT ok(
  has_function_privilege('anon', 'public.get_invitation_details(text)', 'EXECUTE'),
  'anon must still execute get_invitation_details (public invitation landing)'
);
SELECT ok(
  has_function_privilege('anon', 'public.list_subscription_products()', 'EXECUTE'),
  'anon must still execute list_subscription_products (public pricing)'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.list_subscription_products()', 'EXECUTE'),
  'authenticated must still execute list_subscription_products'
);

SELECT * FROM finish();
ROLLBACK;
