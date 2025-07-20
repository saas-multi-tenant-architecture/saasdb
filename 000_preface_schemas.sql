-- 000_preface_schemas.sql
-- Purpose: Create all foundational schemas for the project
-- Run this file first before any schema-specific DDL

-- ========================================
-- SCHEMA CREATION
-- ========================================
CREATE SCHEMA IF NOT EXISTS utils;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS platform;

-- ========================================
-- NOTES
-- ========================================
-- These schemas define logical boundaries:
-- - utils: shared triggers/functions
-- - core: identity, access control, helper functions, audit logs
-- - app: tenant-facing application tables
-- - platform: SaaS-wide admin and control layer (service role only)


-- ========================================
-- ACCESS CONTROL
-- ========================================
-- Lock down platform schema to prevent tenant access
REVOKE ALL ON SCHEMA platform FROM authenticated, anon, public;
REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon, public;

