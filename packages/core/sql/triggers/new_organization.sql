-- new_organization.sql
-- Purpose: Automate creation of metadata and platform registry rows when a new organization is added

-- ========================================
-- FUNCTION: core.handle_new_organization()
-- ========================================
CREATE OR REPLACE FUNCTION core.handle_new_organization()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
DECLARE
  v_super_admin_role_id UUID;
BEGIN
  IF NEW.created_by IS NULL THEN
    RAISE EXCEPTION 'organizations.created_by is required';
  END IF;

  -- Insert org metadata (same UUID)
  INSERT INTO core.organizations_meta (id, created_by, updated_by)
  VALUES (NEW.id, NEW.created_by, NEW.updated_by);

  -- Insert into platform registry
  INSERT INTO platform.platform_organizations (id, label, created_at, updated_at)
  VALUES (NEW.id, NEW.name, now(), now());

  -- Seed initial membership: creator is the org super_admin
  SELECT core.roles.id
  INTO v_super_admin_role_id
  FROM core.roles
  WHERE core.roles.name = 'super_admin'
  LIMIT 1;

  IF v_super_admin_role_id IS NULL THEN
    RAISE EXCEPTION 'Role "super_admin" not found';
  END IF;

  INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
  VALUES (NEW.created_by, NEW.id, v_super_admin_role_id, true, NEW.created_by, NEW.created_by)
  ON CONFLICT (user_id, organization_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- ========================================
-- TRIGGER
-- ========================================
DROP TRIGGER IF EXISTS trg_on_organization_created ON core.organizations;
CREATE TRIGGER trg_on_organization_created
AFTER INSERT ON core.organizations
FOR EACH ROW EXECUTE FUNCTION core.handle_new_organization();

-- ========================================
-- NOTES
-- ========================================
-- This keeps platform and tenant-level structures synchronized
-- Assumes that organization name in `core.organizations` maps to label in platform
