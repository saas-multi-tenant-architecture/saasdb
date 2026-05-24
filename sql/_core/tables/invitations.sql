-- invitations.sql
-- Purpose: Invitation management for organization and unit memberships

-- ========================================
-- TABLE: core.invitations
-- ========================================
CREATE TABLE core.invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  unit_id UUID REFERENCES core.units(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES core.roles(id),
  invited_by UUID NOT NULL,

  -- Token and security
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),

  -- Status tracking
  status TEXT NOT NULL DEFAULT 'pending',
  accepted_at TIMESTAMPTZ,
  accepted_by UUID,

  -- Metadata for email delivery
  metadata JSONB DEFAULT '{}'::jsonb,

  -- Standard audit fields
  created_by UUID,
  updated_by UUID,
  is_deleted BOOLEAN DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valid_status CHECK (status IN ('pending', 'accepted', 'expired', 'cancelled')),
  CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_invitations_organization_id ON core.invitations(organization_id);
CREATE INDEX idx_invitations_unit_id ON core.invitations(unit_id) WHERE unit_id IS NOT NULL;
CREATE INDEX idx_invitations_token ON core.invitations(token) WHERE status = 'pending' AND is_deleted = false;
CREATE INDEX idx_invitations_email ON core.invitations(email) WHERE status = 'pending' AND is_deleted = false;
CREATE INDEX idx_invitations_status ON core.invitations(status);
CREATE INDEX idx_invitations_invited_by ON core.invitations(invited_by);
CREATE INDEX idx_invitations_expires_at ON core.invitations(expires_at) WHERE status = 'pending';

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_invitations_updated
BEFORE UPDATE ON core.invitations
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- NOTES
-- ========================================
-- Email validation regex allows standard email formats
-- Token is generated via gen_random_uuid() or custom secure token generator
-- metadata JSONB can store additional context (e.g., custom message, referral source)
-- Unit-level invitations are optional (unit_id can be NULL)
-- Expired invitations are marked via periodic cleanup or on-access check
