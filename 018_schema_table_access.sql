-- ========================================
-- SCHEMA TABLE ACCESS
-- ========================================
GRANT SELECT ON ALL TABLES IN SCHEMA app TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA utils TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO authenticated;
