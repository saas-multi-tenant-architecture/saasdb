-- organizations.sql
-- Purpose: Platform function for managing platform organizations

-- ========================================
-- FUNCTION: platform.create_platform_organization()
-- ========================================
-- Register a new organization in the platform control layer
CREATE OR REPLACE FUNCTION platform.create_platform_organization(
  p_organization_id UUID
) RETURNS VOID AS $$
DECLARE
  v_label TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT name INTO v_label FROM core.organizations WHERE id = p_organization_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization % not found', p_organization_id;
  END IF;

  INSERT INTO platform.platform_organizations (id, label)
  VALUES (p_organization_id, v_label);

  PERFORM platform.log_platform_action('create', 'platform.platform_organizations', p_organization_id,
    'create_platform_organization', NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
