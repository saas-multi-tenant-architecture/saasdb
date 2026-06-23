-- constraints.sql
-- Purpose: Restore auth.users FKs that core removed for adapter-agnosticism.
-- This file runs after core tables are created and adds Supabase-specific integrity.

ALTER TABLE core.users_meta
  ADD CONSTRAINT fk_users_meta_auth_users
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE core.memberships
  ADD CONSTRAINT fk_memberships_auth_users
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE core.unit_memberships
  ADD CONSTRAINT fk_unit_memberships_auth_users
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE core.invitations
  ADD CONSTRAINT fk_invitations_invited_by_auth_users
  FOREIGN KEY (invited_by) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE core.invitations
  ADD CONSTRAINT fk_invitations_accepted_by_auth_users
  FOREIGN KEY (accepted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- Platform identity FKs (core dropped these for adapter-agnosticism).
ALTER TABLE platform.platform_users
  ADD CONSTRAINT fk_platform_users_auth_users
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE platform.tenant_secrets
  ADD CONSTRAINT fk_tenant_secrets_auth_users
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
