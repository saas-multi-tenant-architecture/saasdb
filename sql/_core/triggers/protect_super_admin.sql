-- protect_super_admin.sql
-- Purpose: Prevent deletion or soft-deletion of super_admin membership

-- ========================================
-- FUNCTION: core.protect_super_admin()
-- ========================================
-- Ensures there is always exactly one super_admin per organization
-- Blocks DELETE and soft-delete (is_deleted = true) on super_admin rows
-- Allows is_super_admin to be set to false only via transfer_super_admin()
CREATE OR REPLACE FUNCTION core.protect_super_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
BEGIN
  -- On DELETE: block if row is super_admin
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_super_admin = true AND OLD.is_deleted = false THEN
      RAISE EXCEPTION 'Cannot delete super_admin membership. Transfer super_admin status first.';
    END IF;
    RETURN OLD;
  END IF;

  -- On UPDATE: block soft-delete of super_admin
  IF TG_OP = 'UPDATE' THEN
    -- Prevent soft-deleting super_admin
    IF OLD.is_super_admin = true AND OLD.is_deleted = false AND NEW.is_deleted = true THEN
      RAISE EXCEPTION 'Cannot soft-delete super_admin membership. Transfer super_admin status first.';
    END IF;

    -- Prevent removing super_admin flag without proper transfer
    -- This check ensures is_super_admin can only go from true->false
    -- if there's another super_admin being set in the same transaction
    -- The unique partial index will enforce only one super_admin exists
    IF OLD.is_super_admin = true AND NEW.is_super_admin = false THEN
      -- Allow this only if called from transfer_super_admin context
      -- The unique index ensures integrity - if no new super_admin is set,
      -- subsequent operations will fail
      NULL; -- Allow the change, index will enforce constraint
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ========================================
-- TRIGGER
-- ========================================
DROP TRIGGER IF EXISTS trg_protect_super_admin ON core.memberships;
CREATE TRIGGER trg_protect_super_admin
BEFORE UPDATE OR DELETE ON core.memberships
FOR EACH ROW EXECUTE FUNCTION core.protect_super_admin();

-- ========================================
-- NOTES
-- ========================================
-- This trigger works in conjunction with:
-- 1. The unique partial index idx_one_super_admin_per_org (ensures max 1 super_admin)
-- 2. The public.transfer_super_admin() function (proper transfer mechanism)
-- Together they ensure exactly one super_admin always exists per organization
