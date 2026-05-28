-- grants.sql
-- Purpose: EXECUTE grants for public.* SECURITY DEFINER functions.
--
-- PostgreSQL grants EXECUTE on public functions to PUBLIC (anon + authenticated)
-- by default. For admin-only SECURITY DEFINER functions, this is too permissive:
-- the unauthenticated anon role can attempt to call them. The internal auth
-- checks (is_super_admin, etc.) would still reject the call, but exposing the
-- functions to anon leaks their existence and creates an unnecessary attack
-- surface (Supabase lint 0028).
--
-- Strategy: REVOKE EXECUTE FROM PUBLIC, then GRANT to authenticated + service_role
-- for admin functions. Public-by-design endpoints (get_invitation_details,
-- list_subscription_products) keep their default PUBLIC grant.

-- ========================================
-- ADMIN FUNCTIONS: require authentication
-- ========================================
-- delete_organization
REVOKE EXECUTE ON FUNCTION public.delete_organization(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.delete_organization(uuid) TO authenticated, service_role;

-- delete_unit
REVOKE EXECUTE ON FUNCTION public.delete_unit(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.delete_unit(uuid) TO authenticated, service_role;

-- add_member_to_organization
REVOKE EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) TO authenticated, service_role;

-- add_member_to_unit
REVOKE EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) TO authenticated, service_role;

-- remove_member_from_organization
REVOKE EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) TO authenticated, service_role;

-- remove_member_from_unit
REVOKE EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) TO authenticated, service_role;

-- ========================================
-- INTENTIONAL PUBLIC FUNCTIONS (anon callable by design)
-- ========================================
-- These remain accessible to anon because they serve unauthenticated flows:
--   - public.get_invitation_details(text): invitation landing page before login
--   - public.list_subscription_products():  public pricing/marketing page
-- The corresponding Supabase lint 0028 warnings are accepted.
--
-- No REVOKE statements are issued for these functions; they inherit the
-- default PUBLIC EXECUTE grant established at function creation.
