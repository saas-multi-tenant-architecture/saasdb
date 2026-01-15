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
BEGIN
  -- Insert org metadata (same UUID)
  INSERT INTO core.organizations_meta (id, created_by, updated_by)
  VALUES (NEW.id, NEW.created_by, NEW.updated_by);

  -- Insert into platform registry
  INSERT INTO platform.platform_organizations (id, label, created_at, updated_at)
  VALUES (NEW.id, NEW.name, now(), now());

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
