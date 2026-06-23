-- grants.sql
-- Purpose: EXECUTE grants for public.* SECURITY DEFINER functions.
--
-- PostgreSQL grants EXECUTE on public functions to PUBLIC by default.
-- For admin-only SECURITY DEFINER functions, this is too permissive: the default
-- PUBLIC grant includes unauthenticated callers. The internal auth checks
-- (is_super_admin, etc.) would still reject the call, but exposing the functions
-- to PUBLIC leaks their existence and creates an unnecessary attack surface.
--
-- Strategy: REVOKE EXECUTE FROM PUBLIC, then GRANT to app_user + app_admin
-- for admin functions. Public-by-design endpoints (get_invitation_details,
-- list_subscription_products) keep their default PUBLIC grant.

-- ========================================
-- ADMIN FUNCTIONS: require authentication
-- ========================================
-- REVOKE FROM PUBLIC to exclude unauthenticated callers, then GRANT to
-- app_user and app_admin for authenticated application access.
--
-- delete_organization
REVOKE EXECUTE ON FUNCTION public.delete_organization(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_organization(uuid) TO app_user, app_admin;

-- delete_unit
REVOKE EXECUTE ON FUNCTION public.delete_unit(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_unit(uuid) TO app_user, app_admin;

-- add_member_to_organization
REVOKE EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) TO app_user, app_admin;

-- add_member_to_unit
REVOKE EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) TO app_user, app_admin;

-- remove_member_from_organization
REVOKE EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) TO app_user, app_admin;

-- remove_member_from_unit
REVOKE EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) TO app_user, app_admin;

-- ========================================
-- INTENTIONAL PUBLIC FUNCTIONS
-- ========================================
-- These remain accessible to PUBLIC because they serve unauthenticated flows:
--   - public.get_invitation_details(text): invitation landing page before login
--   - public.list_subscription_products():  public pricing/marketing page
--
-- No REVOKE statements are issued for these functions; they inherit the
-- default PUBLIC EXECUTE grant established at function creation.
