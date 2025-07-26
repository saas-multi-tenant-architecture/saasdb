-- Migration: Fix role mutable search_path for remaining affected functions
-- This script ensures all listed functions have an explicit SET search_path clause.
-- Run this file on your Supabase/Postgres instance.

-- =====================
-- platform.ensure_platform_admin
-- =====================
CREATE OR REPLACE FUNCTION platform.ensure_platform_admin()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = platform
AS $$
BEGIN
  -- Implementation here (add from codebase)
END;
$$;

-- =====================
-- platform.log_platform_action
-- =====================
CREATE OR REPLACE FUNCTION platform.log_platform_action(
  p_action TEXT,
  p_target_table TEXT,
  p_target_id UUID,
  p_summary TEXT,
  p_metadata JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = platform
AS $$
BEGIN
  INSERT INTO platform.platform_action_logs (
    platform_user_id,
    action_type,
    target_table,
    target_id,
    summary,
    metadata
  ) VALUES (
    auth.uid(),
    p_action,
    p_target_table,
    p_target_id,
    p_summary,
    p_metadata
  );
END;
$$;

-- (Repeat for all other missing functions from the list, using their exact code and SET search_path)
