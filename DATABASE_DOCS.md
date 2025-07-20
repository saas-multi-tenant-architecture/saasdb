# Database Reference

This document provides an overview of all schemas, tables, functions and RLS (Row Level Security) policies in this project. It is intended as a companion to `README.md` and explains how the multi-tenant structure works.

## Schemas

- **utils** – common helper functions and triggers.
- **core** – tenant aware data such as users, organizations and audit logs.
- **app** – place to add application specific tables/functions for your SaaS.
- **platform** – administrative layer used only by the SaaS operator.
- **public** – exposes selected functions to clients via Supabase RPC.

## utils schema

### Table & Functions

| Name | Type | Purpose |
| ---- | ---- | ------- |
| `utils.update_timestamp()` | function | trigger helper that sets `updated_at` to `now()` whenever a row is updated. Used by many tables. |

## core schema

### Tables

| Table | Purpose |
| ----- | ------- |
| `core.organizations` | Top level tenant entity. Soft delete fields included. |
| `core.units` | Sub divisions of an organization. |
| `core.unit_meta` | Extra metadata for units (1:1 with `units`). |
| `core.roles` | Lookup table of role names with a priority. |
| `core.memberships` | Links users to organizations with a role. |
| `core.unit_memberships` | Links users to units with a role. |
| `core.organization_files` | References files stored in Supabase Storage. |
| `core.audit_logs` | Immutable log of important actions. |
| `core.users_meta` | Profile info about each user. 1:1 with `auth.users`. |
| `core.organization_meta` | Additional info for organizations (address, timezone etc.). |

### Functions (public schema wrappers call these under the hood)

- `core.log_audit(action_type, target_table, target_id, summary, metadata)` – writes to `core.audit_logs`.
- `core.is_org_member(org_id)` – checks if current auth user belongs to an organization.
- `core.is_unit_member(unit_id)` – checks membership in a unit.
- `core.get_org_role(org_id)` – returns role name of current user within an org.
- `core.has_org_role(org_id, role)` – boolean helper using roles.priority.
- `core.has_unit_role(unit_id, role)` – same for unit scope.
- `core.shares_organization(user_id)` – true if current user shares any org with the given user.

### RLS Policies

Row level security is enabled on all tenant aware tables. Highlights:

- `users_meta` – users can select their row or rows of users who share an organization. Only owner may update.
- `organization_meta`, `organizations` – any member can select; admins can update/insert.
- `units`, `unit_meta` – members can view; org/unit admins manage inserts and updates.
- `memberships`, `unit_memberships` – members can see their rows; admins manage membership.
- `audit_logs` – only organization admins can read logs.
- `organization_files` – organization members read, admins write.

## app schema

Use this schema for any application specific tables. Keep tenant aware data here and protect with RLS just like the `core` tables. To add new modules:

1. Create tables/functions inside the `app` schema.
2. Write RLS helper functions in the `core` schema if they are tenant wide.
3. Expose any client RPCs by creating wrapper functions in the `public` schema.
4. Optionally seed default data in a separate SQL file.

## public schema

The `public` schema exposes safe RPC functions used by clients. Examples include:

- `get_user_profile()` and `update_user_profile(data)`
- `list_my_organizations()` / `create_organization(name)`
- `invite_user_to_organization(email, role_id)`
- `list_my_units()` / `create_unit(org_id, name)`
- `create_file()` / `delete_file(file_id)`
- `get_audit_log(org_id, limit)`

These functions enforce RLS automatically and also write to audit logs when appropriate.

## platform schema

The platform schema contains administration only tables. Access to the entire schema is revoked from regular Supabase roles and every table has `USING (false)` policies for defense in depth.

### Tables

| Table | Purpose |
| ----- | ------- |
| `platform.platform_roles` | Roles for platform staff such as `admin` or `support`. |
| `platform.platform_users` | Staff accounts mapped to `auth.users`. |
| `platform.platform_organizations` | Registry of all tenant org ids. |
| `platform.platform_action_logs` | Tracks every admin operation performed via platform functions. |
| `platform.platform_settings` | Key/value configuration data. |
| `platform.platform_subscription_overrides` | Per-org overrides for plans or feature flags. |
| `platform.platform_feature_flags` | Global or per-org feature toggles. |
| `platform.platform_system_events` | Records infrastructure level events. |
| `platform.tenant_secrets` | References to encrypted secrets stored in Supabase Vault. |
| `platform.billing_customers` | Stripe customer ids mapped to organizations. |
| `platform.billing_subscriptions` | Stripe subscription state. |
| `platform.subscription_products` | Catalog of subscription plans. |

### Functions

Platform operations all call `platform.ensure_platform_admin()` to verify the caller is a platform admin.

- `log_platform_action(action, table, id, summary, metadata)` – internal helper.
- `create_platform_user(user_id, role)` – add a new platform user.
- `update_platform_user_role(user_id, role)` – change role.
- `delete_platform_user(user_id)` – remove a platform user.
- `create_platform_organization(org_id)` – register tenant in platform layer.
- `set_platform_override(org_id, key, value)` / `delete_platform_override(org_id, key)` – manage subscription overrides.
- `create_platform_feature_flag(key, value, org_id)` – feature flags.
- `log_platform_event(type, message, metadata)` – system events.
- `get_platform_user_role()` – returns current user platform role.
- `create_tenant_secret(scope, id, name, secret, user_id)` – store a secret in Vault and reference it.
- `delete_tenant_secret(secret_id, user_id)` – soft delete secret.
- `get_platform_action_log(limit)` – list recent admin actions.
- `link_stripe_customer(org_id, stripe_customer_id, billing_email)` – tie an org to a Stripe customer.
- `record_subscription_update(org_id, stripe_subscription_id, plan, status, current_period_end, cancel_at_period_end)` – track subscription status changes.
- `list_all_subscription_products()` / `add_subscription_product(...)` – manage Stripe price catalog.

### RLS Policies

Every table in `platform` is locked down with a `deny_all` policy using `USING (false)` so direct client access is impossible. Only the service role via Edge Functions should call platform functions.

## Seeding & Tests

Seed files such as `016_test_seed_core_roles.sql` and `015_test_seed_core.sql` provide sample roles, users and organizations. The `tests` folder contains basic SQL tests verifying the RLS rules and functions work as intended.

## Road Map / Future Enhancements

- **Feature limits** – Implement enforcement of plan limits using metadata in `platform.subscription_products`.
- **Better enum constraints** – Many tables use plain text for status fields. Adding `CHECK` constraints or enum types would prevent bad data.
- **Comprehensive auditing** – Expand `core.audit_logs` usage to every public function. Integrate with external logging if needed.
- **User & org web hooks** – Expose hooks when organizations or users are created or deleted so the app layer can react.
- **Stronger typing between Zod schemas and SQL** – `Fixes.md` highlights several mismatches that should be addressed.
- **Unit hierarchy** – Introduce parent/child relationships for units if required by the business domain.
- **Automated cleanup of soft deleted data** – Scheduled jobs could purge data marked `is_deleted` after a retention window.
- **Enhanced secrets management** – Optionally integrate with an external KMS provider for envelope encryption.
- **Better test coverage** – Add tests for every function and edge case, possibly using pgTAP.

## Implementing Application Code (app schema)

1. Create your tenant specific tables inside the `app` schema (e.g. `app.documents`).
2. Protect them with RLS using helpers like `core.is_org_member` or new ones if needed.
3. Write `public` functions as the API surface for clients (for example `public.create_document`).
4. Optionally log actions to `core.audit_logs` in these functions.
5. Update seed files and tests if your application tables require initial data.

