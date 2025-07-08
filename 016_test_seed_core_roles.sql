-- 016_test_seed_core_roles.sql
-- Purpose: Seed default core roles for development/testing

INSERT INTO core.roles (name, priority, description)
VALUES
  ('admin', 1, 'Organization administrator'),
  ('manager', 2, 'Unit manager'),
  ('user', 3, 'Regular user')
ON CONFLICT (name) DO NOTHING;
