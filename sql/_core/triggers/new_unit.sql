-- new_unit.sql
-- Purpose: Automate creation of metadata row when a new unit is added

-- ========================================
-- FUNCTION: core.handle_new_unit()
-- ========================================
CREATE OR REPLACE FUNCTION core.handle_new_unit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
BEGIN
  -- Insert unit metadata (same UUID as unit)
  INSERT INTO core.unit_meta (id, created_by, updated_by)
  VALUES (NEW.id, NEW.created_by, NEW.created_by);

  RETURN NEW;
END;
$$;

-- ========================================
-- TRIGGER
-- ========================================
CREATE TRIGGER trg_on_unit_created
AFTER INSERT ON core.units
FOR EACH ROW EXECUTE FUNCTION core.handle_new_unit();

-- ========================================
-- NOTES
-- ========================================
-- Ensures unit_meta is always created alongside the unit
-- Uses the same UUID as the unit for 1:1 relationship
