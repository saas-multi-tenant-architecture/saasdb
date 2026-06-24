---
"@smta/core": minor
---

De-Supabase `@smta/core`: core is now adapter-agnostic and loads standalone on vanilla PostgreSQL 18.

- Core owns two neutral roles, `app_user` (RLS-subject) and `app_admin` (BYPASSRLS); `core.get_current_user_id()` (reading `app.current_user_id`) replaces `auth.uid()` everywhere, and all `auth.*` references are removed from core.
- Supabase adapter restores its deltas — maps `authenticated`→`app_user` / `service_role`→`app_admin`, re-adds the `auth.users` FKs and signup trigger, owns the `pg_graphql` disable, and provides the Vault `read_secret_impl`. Behavior is unchanged on Supabase.
- better-auth and payload adapters gain a pgcrypto secrets implementation (keyed off the `app.secrets_key` GUC) and neutral-role wiring.
- A plain-Postgres load gate plus CI workflow guard against regressions; the pgTap suite runs on vanilla Postgres via `SMTA_TARGET=plain`.

BREAKING: `@smta/cli` now requires `--better-auth-ids <uuid|mapped>` when `--adapter better-auth`. BREAKING: `platform.platform_users.supabase_user_id` is renamed to `user_id`.
