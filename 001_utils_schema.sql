-- 001_utils_schema.sql
-- Purpose: Shared utility schema for reusable functions and triggers
-- This file should be run before any others that depend on shared triggers/functions

-- ========================================
-- SCHEMA CREATION
-- ========================================
CREATE SCHEMA IF NOT EXISTS utils;

-- ========================================
-- FUNCTIONS
-- ========================================

-- update_timestamp(): updates updated_at column on any table
CREATE OR REPLACE FUNCTION utils.update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = utils
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ========================================
-- NOTES
-- ========================================
-- This function can be used by triggers on any table in any schema
-- Example usage:
--   CREATE TRIGGER trg_update_table
--   BEFORE UPDATE ON some_schema.some_table
--   FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- BASE COMPOSITE AUDIT FIELDS
-- USED ONLY TO COPY & PASTE INTO TABLES (FIELDS, NOT TYPE)
-- ========================================
-- created_by uuid,
-- updated_by uuid,
-- is_deleted boolean DEFAULT false,
-- deleted_at TIMESTAMPTZ,
-- deleted_by uuid,
-- created_at TIMESTAMPTZ DEFAULT NOW(),
-- updated_at TIMESTAMPTZ DEFAULT NOW()
