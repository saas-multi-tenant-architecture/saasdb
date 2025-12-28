-- units.sql
-- Purpose: Sub-entities within organizations (teams, departments, etc.)

-- ========================================
-- TABLE: core.units
-- ========================================
CREATE TABLE core.units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_units_updated
BEFORE UPDATE ON core.units
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- TABLE: core.unit_meta
-- ========================================
CREATE TABLE core.unit_meta (
  id UUID PRIMARY KEY REFERENCES core.units(id) ON DELETE CASCADE,
  notes TEXT,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_unit_meta_updated
BEFORE UPDATE ON core.unit_meta
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();
