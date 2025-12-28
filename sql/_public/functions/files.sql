-- files.sql
-- Purpose: Public RPC functions for file management

-- ========================================
-- FUNCTION: public.create_file()
-- ========================================
CREATE OR REPLACE FUNCTION public.create_file(
  p_org_id UUID,
  p_file_url TEXT,
  p_file_type TEXT,
  p_file_size INTEGER DEFAULT NULL,
  p_file_specs JSONB DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_file_id UUID;
BEGIN
  INSERT INTO core.organization_files (
    organization_id, file_url, file_type, file_size, file_specs, created_by
  )
  VALUES (
    p_org_id, p_file_url, p_file_type, p_file_size, p_file_specs, auth.uid()
  )
  RETURNING id INTO v_file_id;

  PERFORM core.log_audit(
    'insert', 'core.organization_files', v_file_id, 'create_file',
    jsonb_build_object(
      'file_url', p_file_url,
      'file_type', p_file_type,
      'file_size', p_file_size,
      'file_specs', p_file_specs
    )
  );

  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at
  FROM core.organization_files
  WHERE id = v_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_file_metadata()
-- ========================================
CREATE OR REPLACE FUNCTION public.update_file_metadata(
  p_file_id UUID,
  p_file_specs JSONB DEFAULT NULL,
  p_file_size INTEGER DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  file_url TEXT,
  file_type TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  UPDATE core.organization_files
  SET
    file_specs = COALESCE(p_file_specs, file_specs),
    file_size = COALESCE(p_file_size, file_size),
    updated_by = auth.uid(),
    updated_at = now()
  WHERE id = p_file_id;

  PERFORM core.log_audit(
    'update', 'core.organization_files', p_file_id, 'update_file_metadata',
    jsonb_build_object(
      'file_specs', p_file_specs,
      'file_size', p_file_size
    )
  );

  RETURN QUERY
  SELECT id, file_url, file_type, updated_at FROM core.organization_files WHERE id = p_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_file()
-- ========================================
CREATE OR REPLACE FUNCTION public.get_file(p_file_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at, updated_at
  FROM core.organization_files
  WHERE id = p_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_files()
-- ========================================
CREATE OR REPLACE FUNCTION public.list_files(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at, updated_at
  FROM core.organization_files
  WHERE organization_id = p_org_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.delete_file()
-- ========================================
CREATE OR REPLACE FUNCTION public.delete_file(p_file_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE core.organization_files
  SET
    is_deleted = true,
    deleted_at = now(),
    deleted_by = auth.uid()
  WHERE id = p_file_id;

  PERFORM core.log_audit(
    'delete', 'core.organization_files', p_file_id, 'delete_file',
    jsonb_build_object(
      'file_id', p_file_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
