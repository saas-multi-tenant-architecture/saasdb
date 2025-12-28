# SaaS Multi-Tenant Architecture - SMTA 
### Based on Supabase + PostgreSQL 

## General Overview

Building a multi-tenant database can be a daunting task, particularly for a newly developing product. In many fledgling projects it is typically relagated to 'phase 2' in the interest of expedinecy, but this creates a substantial amount of technical debt. When an application gains success, establishing multi-tenancy involves limitations or awkward workarounds that are annoying to the customer end-user because the limitations of the initial database are just too costly to re-write. In some cases, multi-tenancy is achieved using a 'one-database-per-tenant  model', that is more costly to maintain and can lack cross-tenant integration (such as user log-ins across multiple tenants or macro-analytics). Still worse, sometimes a multi-tenant database is designed on top of the original database, reducing isolation, security, or performance, and sometimes all three.

This *SaaS Multi-Tenant Architecture*, aka **SMTA**, is an open-source project designed to address these challenges by providing a ready-made solution that can be used to quickly bootstrap your SaaS. The architecture is designed to be modular, scalable, and extensible to customize it to your needs. **SMTA**, combined with Supabase, removes all of the comlexity of multi-tenancy so that you can focus on building your MVP. 

To accomplish this goal, **SMTA** relies heavily on Supabase and PostgreSQL. Supabase provides excellent integration with its authentication layer and the database, including via Row Level Security (RLS) and user-specific functions (like ```auth.uid()```). This integration makes security and tenant isolation much easier to implement. This is also true of other database-adjacent features that Supabase brings, such as the Vault and an s3 compatible storage, both of which are an inherent part of almost every SaaS. The result is that many of the complicated tasks associated with a multi-tenant SaaS are abstracted behind clearly defined SQL functions, that are all subject to a standardized testing routing during development.

## 🎯 Goal

Create a reusable, secure, and modular SaaS backend using Supabase as the backend service. The system supports:

- Multi-tenant architecture within a shared database

- Fine-grained role-based access at both the organization and sub-entity ("unit") level

- PostgreSQL RLS (Row-Level Security) for tenant isolation and redundant tenant isolation

- Soft deletion, auditing, and payment processor billing integration

- Clear schema boundaries and API control via SQL functions

## ✅ Key Features

### Tenancy & Access

- Single Postgres database (shared schema)

- Users can belong to multiple organizations with different roles

- Role-based access at both organization and unit level

- Roles defined in a lookup table (no Postgres enums)

### Schemas

The following schemas complement those provided by Supabase. These are designed to segment functionality and enforce security boundaries:

- `core`: identity, access, helper functions, audit logs

- `app`: all tenant-specific application logic (e.g., documents, tasks)

- `platform`: SaaS-wide management, logs, and overrides (service role only)

- `public`: only for exposing SQL functions callable by clients (RPC)

### Access Control

- PostgreSQL RLS enforced on all tenant-aware tables

- Centralized helper functions (e.g., `is_org_member`) enforce membership and role checks

- `roles.priority` enables scalable role comparison logic

### Platform Schema Security

- Platform functionality (`platform.*`) is strictly backend-only (SaaS operator only)

- Supabase roles (`authenticated`, `anon`) are **explicitly revoked** from accessing the `platform` schema:

```sql

REVOKE ALL ON SCHEMA platform FROM authenticated, anon;

REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon;

```

- No SQL functions or tables from `platform` are exposed in the `public` schema

- Platform functionality is accessed via Edge Functions using the Supabase **service role**

- (Optional) RLS policies can be applied to `platform.*` tables with `USING (false)` for defense in depth

### Soft Deletion

- All identity/domain tables include:

- `is_deleted BOOLEAN`

- `deleted_at TIMESTAMPTZ`

- `deleted_by UUID`

- All soft deletes are logged in audit log

### Audit Logging

- Central `core.audit_logs` table records:

- Who acted, on what, and when

- Table and row IDs

- Action type and change summary

- Platform admin actions are recorded in `platform_action_logs` for traceability

### Billing

- Common structure for integration with a billing provider such as Stripe or Lemon Squeezy

- `billing_customers`, `billing_subscriptions`, and `billing_plans` tables

- Feature limits enforced via plan metadata, not RLS

### Secrets Management

- Secrets such as API keys and SMTP credentials are securely referenced via `platform.tenant_secrets`

- Secrets are scoped per organization or per user using a `scope` column (`'organization'` or `'user'`)

- Actual secret values are stored in Supabase Vault, and only the `vault_key_id` is saved in the database

- RLS support ensures tenant/user isolation for secret access

### API & Client Access

- Tables only exist in `core`, `app`, `platform` schemas

- Supabase client accesses only `public` via Remote Procedure Calls (RPC) functions

- SQL functions in `public` execute in the context of the calling user (not SECURITY DEFINER)

- Edge Functions used only when needed (e.g. for Stripe hooks, admin)

- Application-specific logic resides in the `app` schema to make the SaaS database more extensible and portable

---

## 📂 Tables by Schema

### core

- `users_meta`

- `organizations`

- `organizations_meta`

- `units`

- `unit_meta`

- `memberships`

- `unit_memberships`

- `roles`

- `audit_logs`

### app

- Domain-specific tables (e.g. `documents`, `projects`, etc.)

- Each table includes `organization_id`, optional `unit_id`, and full audit fields

### platform

- `platform_users` (SaaS admins)

- `platform_organizations` (platform control layer)

- `platform_subscription_overrides` (non-standard plan/feature exceptions)

- `platform_action_logs` (tracks all admin-level activity)

- `platform_settings` (central configuration flags in JSONB)

- `platform_feature_flags` (per-tenant and global toggles)

- `platform_system_events` (platform-wide activity stream, failures, notices)

- `platform.tenant_secrets` (Vault-based secret references with scope control)

### public

- SQL functions only (e.g., `create_project`, `get_user_profile`)

- All functions execute under the privileges of the calling user (not SECURITY DEFINER) to ensure RLS validates context

- Functions (RPCs) also explicitly validate context to create a 'belt and suspenders' approach to tenant isolation and security.

---

## ⚙️ Planned Automation

- On creation of:

  - a user → auto-create `users_meta`

  - an organization → auto-create `organizations_meta` and `platform_organizations`

  - a unit → auto-create `unit_meta`

- Shared `updated_at` trigger function for all tables

- Centralized helper functions for org/unit membership and role checks

- Platform-facing automation functions for:

  - creating `platform_action_logs`

  - applying `platform_subscription_overrides`

  - registering feature flags via `platform_feature_flags`

  - logging system-wide failures, syncs, or alerts via `platform_system_events`

---

## 🧠 Naming Conventions

### Table Naming

- Use `snake_case`, all lowercase

- Use plural nouns unless singular makes more sense (e.g. `audit_logs`, `documents`)

- Prefix platform tables with `platform_` (e.g. `platform_users`) to reduce ambiguity

### Column Naming

- Primary key: `id`

- Foreign keys: `<entity>_id` (e.g. `organization_id`, `unit_id`)

- Timestamps: `<action>_at` (e.g. `created_at`, `updated_at`, `deleted_at`)

- Actors: `<action>_by` (e.g. `created_by`, `deleted_by`)

- Booleans: `is_` or `has_` prefix (e.g. `is_deleted`, `has_access`)

### Standard Audit Fields

```sql

created_at TIMESTAMPTZ DEFAULT now(),

updated_at TIMESTAMPTZ DEFAULT now(),

created_by UUID,

is_deleted BOOLEAN DEFAULT false,

deleted_at TIMESTAMPTZ,

deleted_by UUID

```

## 📡 Public RPC Function Conventions

Public functions serve as the client-facing API for the database. They are always defined in the `public` schema and operate under the privileges of the **calling user** (`SECURITY INVOKER`).

### ✅ Naming Conventions

Use `verb_noun[_context]` structure for clarity and consistency:

| Verb      | Description                            | Example                       |
| --------- | -------------------------------------- | ----------------------------- |
| `get_`    | Fetch a single record                  | `get_user_profile()`          |
| `list_`   | Fetch a collection                     | `list_org_members(org_id)`    |
| `create_` | Insert a new record                    | `create_project(...)`         |
| `update_` | Modify a record                        | `update_document_status(...)` |
| `delete_` | Soft delete a record                   | `delete_unit(unit_id)`        |
| `sync_`   | Idempotent state sync or recalculation | `sync_billing(...)`           |
| `log_`    | Track events or custom logs            | `log_invitation(...)`         |

Functions should:

- Use `auth.uid()` where applicable to avoid passing user IDs from the client
- Validate input and verify access control via helper functions or RLS
- Return structured JSON or typed rows for client parsing

---

### 🛡️ Security Practices

- All public functions are `SECURITY INVOKER`
- RLS on underlying tables must be enforced
- No direct access to core or platform tables by clients
- No direct access to any table unless via a 'public'-schema function

---

### 🧾 Audit Logging in RPC

To support traceability, public functions that mutate data (create, update, delete) should log activity using the following:

```sql
core.log_audit(
  action_type TEXT,
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB
)
```

## 📡 Public RPC Functions

This section defines the client-facing SQL functions exposed via the `public` schema.

The functions should have the following in common:

- Are `SECURITY INVOKER`
- Use `auth.uid()` internally to ensure identity context; This ties the user to their role and organization.
- Respect RLS policies on underlying tables
- Perform input validation and enforce business rules (where applicable)

### 🧾 Core Identity & Membership Functions

| Function Name                                              | Description                                                 |
| ---------------------------------------------------------- | ----------------------------------------------------------- |
| `get_user_profile()`                                       | Returns metadata for the currently authenticated user       |
| `update_user_profile(data JSON)`                           | Updates profile fields for the current user                 |
| `list_my_organizations()`                                  | Lists all organizations the user belongs to                 |
| `get_organization(id UUID)`                                | Returns metadata for a specific organization                |
| `list_organization_members(id UUID)`                       | Lists members (users) in the specified organization         |
| `get_user_role(org_id UUID)`                               | Returns the role of the calling user within an organization |
| `create_organization(name TEXT)`                           | Creates a new organization (with plan/user limits enforced) |
| `invite_user_to_organization(email TEXT, role_id UUID)`    | Sends invite to another user to join org                    |
| `remove_user_from_organization(user_id UUID, org_id UUID)` | Removes a user from the org                                 |

### 🏢 Unit Functions

| Function Name                                                   | Description                                         |
| --------------------------------------------------------------- | --------------------------------------------------- |
| `list_my_units()`                                               | Lists all units the user belongs to across all orgs |
| `get_unit(id UUID)`                                             | Returns metadata for a specific unit                |
| `create_unit(org_id UUID, name TEXT)`                           | Creates a new unit in an organization               |
| `assign_user_to_unit(user_id UUID, unit_id UUID, role_id UUID)` | Assigns a user to a unit                            |
| `remove_user_from_unit(user_id UUID, unit_id UUID)`             | Removes user from unit                              |

### 🧾 Audit and Admin

| Function Name                           | Description                                        |
| --------------------------------------- | -------------------------------------------------- |
| `get_audit_log(org_id UUID, limit INT)` | Returns audit log entries for a given organization |

---

## ✅ Sample: `get_user_profile()`

```sql
CREATE OR REPLACE FUNCTION public.get_user_profile()
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id,
    u.email,
    m.first_name,
    m.last_name,
    m.avatar_url,
    m.timezone,
    m.locale
  FROM auth.users u
  JOIN core.users_meta m ON u.id = m.id
  WHERE u.id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;
```

### 🔒 Notes

- Uses `auth.uid()` to determine the user
- Safe to expose directly to clients
- Can be extended to include roles or membership context

## 🛠️ Platform RPC Functions

These SQL functions live in the `platform` schema and are executed by trusted platform users (e.g., SaaS admins). They are protected by RLS policies (`USING (false)`) and are invoked with elevated privileges using `SECURITY DEFINER`. Each function validates the caller's identity and role via `platform.ensure_platform_admin()`.

All write operations should log an entry in `platform.platform_action_logs` for auditability.

### 📋 Proposed Platform Functions

| Function Name                                                                     | Description                                             |
| --------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `create_platform_user(user_id UUID, role TEXT)`                                   | Adds a new platform user with a specific role           |
| `update_platform_user_role(user_id UUID, role TEXT)`                              | Changes the assigned role for a platform user           |
| `delete_platform_user(user_id UUID)`                                              | Soft-deletes a platform user                            |
| `create_platform_organization(org_id UUID)`                                       | Registers a new org in the platform control layer       |
| `set_platform_override(org_id UUID, key TEXT, value JSONB)`                       | Stores or updates a subscription override for an org    |
| `delete_platform_override(org_id UUID, key TEXT)`                                 | Removes a subscription override                         |
| `create_platform_feature_flag(key TEXT, value JSONB, org_id UUID DEFAULT NULL)`   | Registers a global or per-org feature toggle            |
| `log_platform_event(event_type TEXT, message TEXT, metadata JSONB)`               | Records a system-level or admin-triggered event         |
| `get_platform_user_role()`                                                        | Returns the current user's platform role                |
| `create_tenant_secret(scope TEXT, id UUID, name TEXT, secret TEXT, user_id UUID)` | Creates a new tenant secret for an organization or user |
| `delete_tenant_secret(secret_id UUID, user_id UUID)`                              | Deletes a tenant secret for an organization or user     |
| `get_platform_action_log(limit INT DEFAULT 100)`                                  | Fetches recent platform actions for monitoring or audit |

### 🔒 Security Model

- Where scope is referenced it is either `organization` or `user`, and id refers to `organization_id` or `user_id`
- Functions must validate the user's role, along with the organization and unit membership.
- A platform or tenant user can never access an unencrypted secret directly
  - The secret will be retrieved by the system as part of other functionality
- For tenant_secrets, validate if the user is part of the organization.

  - This may require that the user_id (tenant) is retrieved by the frontend and included in the function parameters.
  - Example:

  ```sql
    -- Ensure caller is a valid member of the org/user they are targeting
    IF NOT EXISTS (
        SELECT 1
        FROM core.memberships
        WHERE user_id = userid
          AND organization_id = _organization_id
          AND role_id = (SELECT id FROM core.roles WHERE name = 'admin')
      ) THEN
        RAISE EXCEPTION 'You are not authorized to manage secrets for this organization.';
      END IF;
  ```

  Or for user secrets:

  ```sql
  IF NOT EXISTS (
      SELECT 1
      FROM auth.users
      WHERE id = userid
        AND user_id = _user_id
    ) THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this user.';
    END IF;
  ```

- All functions use `SECURITY DEFINER`
- Access is only granted through explicit role validation inside each function
- RLS on all tables prevents any raw table access, even for authenticated users

#### 🔐 Final Access Flow for Platform Functions: Belt & Suspenders

| Layer                  | Responsibility                                        | Enforced? |
| ---------------------- | ----------------------------------------------------- | --------- |
| Edge Function          | Auth + role validation                                | ✅        |
| SQL Function           | Membership and/or identity check (platform or tenant) | ✅        |
| RLS on platform tables | `USING (false)` fallback barrier                      | ✅        |

### 🧾 Logging Convention

Every time a function is invoked, add a row to `platform.platform_action_logs` with:

- `actor_id = auth.uid()`
- `action = 'select' | 'create' | 'update' | 'delete' | 'log' | 'override'`
- `target_table` and `target_id` where applicable
- `summary` and `metadata` to describe the action
- `created_at` timestamp with timezone

This enforces accountability and traceability across platform operations.

### Best Practices

- Avoid abbreviations like `org_id`; prefer `organization_id`

- Use consistent names across tables (e.g. always use `unit_id` when referencing `units`)

- Fully qualify fields in joins for readability and traceability

---

## 🔧 Technology

- PostgreSQL and plpgsql for database and functions

- Zod v4 and Typescript for type-safe integration with any front/backend

- pgTap for Testing

---

## 🚫 What’s Explicitly Avoided

- No PostgreSQL enums (lookup tables used instead)

- No client access to raw tables

- No direct use of Supabase Edge Functions for CRUD unless necessary

---
