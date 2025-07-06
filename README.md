# SaaS Backend Architecture Plan (Supabase + PostgreSQL)

## 🎯 Goal

Create a reusable, secure, and modular SaaS backend using Supabase as the backend service. The system supports:

\- Multi-tenant architecture with shared database

\- Fine-grained role-based access at both the organization and sub-entity ("unit") level

\- PostgreSQL RLS (Row-Level Security) for tenant isolation

\- Soft deletion, auditing, and Stripe-based billing

\- Clear schema boundaries and API control via SQL functions

## ✅ Key Features

### Tenancy & Access

- Single Postgres database (shared schema)

- Users can belong to multiple organizations

- Role-based access at both organization and unit level

- Roles defined in a lookup table (no Postgres enums)

### Schemas

- \`core\`: identity, access, helper functions, audit logs

- \`app\`: all tenant-specific application logic (e.g., documents, tasks)

- \`platform\`: SaaS-wide management, logs, and overrides (service role only)

- \`public\`: only for exposing SQL functions callable by clients (RPC)

### Access Control

- PostgreSQL RLS enforced on all tenant-aware tables

\- Centralized helper functions (e.g., \`is_org_member\`) enforce membership and role checks

- \`roles.priority\` enables scalable role comparison logic

### Platform Schema Security

- Platform functionality (\`platform.\*\`) is strictly backend-only (SaaS operator only)

- Supabase roles (\`authenticated\`, \`anon\`) are \*\*explicitly revoked\*\* from accessing the \`platform\` schema:

```sql

REVOKE ALL ON SCHEMA platform FROM authenticated, anon;

REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon;

```

- No SQL functions or tables from \`platform\` are exposed in the \`public\` schema

- All platform functionality is accessed exclusively via Edge Functions using the Supabase \*\*service role\*\*

\- (Optional) RLS policies can be applied to \`platform.\*\` tables with \`USING (false)\` for defense in depth

### Soft Deletion

- All identity/domain tables include:

- \`is_deleted BOOLEAN\`

- \`deleted_at TIMESTAMPTZ\`

- \`deleted_by UUID\`

- All soft deletes are logged in audit log

### Audit Logging

- Central \`core.audit_logs\` table records:

- Who acted, on what, and when

- Table and row IDs

- Action type and change summary

- Platform admin actions are recorded in \`platform_action_logs\` for traceability

### Billing

- Stripe integration using Edge Functions

- \`billing_customers\`, \`billing_subscriptions\`, and \`billing_plans\` tables

- Feature limits enforced via plan metadata, not RLS

### Secrets Management

- Secrets such as API keys and SMTP credentials are securely referenced via \`platform.tenant_secrets\`

- Secrets are scoped per organization or per user using a \`scope\` column (\`'organization'\` or \`'user'\`)

- Actual secret values are stored in Supabase Vault, and only the \`vault_key_id\` is saved in the database

- RLS support ensures tenant/user isolation for secret access

- Future support planned for KMS integration (e.g., AWS KMS)

### API & Client Access

- Tables only exist in \`core\`, \`app\`, \`platform\` schemas

- Supabase client accesses only \`public\` RPC functions

- SQL functions in \`public\` execute in the context of the calling user (not SECURITY DEFINER)

- Edge Functions used only when needed (Stripe hooks, admin)

- Application-specific logic may reside in a single \`app\` schema

---

## 📂 Tables by Schema

### core

- \`users_meta\`

- \`organizations\`

- \`organization_meta\`

- \`units\`

- \`unit_meta\`

- \`memberships\`

- \`unit_memberships\`

- \`roles\`

- \`audit_logs\`

### app

- Domain-specific tables (e.g. \`documents\`, \`projects\`, etc.)

- Each table includes \`organization_id\`, optional \`unit_id\`, and full audit fields

### platform

- \`platform_users\` (SaaS admins)

- \`platform_organizations\` (platform control layer)

- \`platform_subscription_overrides\`

- \`platform_action_logs\` (tracks all admin-level activity)

- \`platform_settings\` (central configuration flags in JSONB)

- \`platform_feature_flags\` (per-tenant and global toggles)

- \`platform_system_events\` (platform-wide activity stream, failures, notices)

- \`platform.tenant_secrets\` (Vault-based secret references with scope control)

### public

- SQL functions only (e.g., \`create_project\`, \`get_user_profile\`)

- All functions execute under the privileges of the calling user (not SECURITY DEFINER)

- Functions explicitly validate context and rely on RLS for security

---

## 🔧 Planned Automation

- On creation of:

- a user → auto-create \`users_meta\`

- an organization → auto-create \`organization_meta\` and \`platform_organizations\`

- a unit → auto-create \`unit_meta\`

- Shared \`updated_at\` trigger function for all tables

- Centralized helper functions for org/unit membership and role checks

- Platform-facing automation functions for:

- creating \`platform_action_logs\`

- applying \`platform_subscription_overrides\`

- registering feature flags via \`platform_feature_flags\`

- logging system-wide failures, syncs, or alerts via \`platform_system_events\`

---

## 🧠 Naming Conventions

### Table Naming

- Use \`snake_case\`, all lowercase

- Use plural nouns unless singular makes more sense (e.g. \`audit_logs\`, \`documents\`)

- Prefix platform tables with \`platform\_\` (e.g. \`platform_users\`) to reduce ambiguity

### Column Naming

- Primary key: \`id\`

- Foreign keys: \`\<entity>\_id\` (e.g. \`organization_id\`, \`unit_id\`)

- Timestamps: \`\<action>\_at\` (e.g. \`created_at\`, \`updated_at\`, \`deleted_at\`)

- Actors: \`\<action>\_by\` (e.g. \`created_by\`, \`deleted_by\`)

- Booleans: \`is\_\` or \`has\_\` prefix (e.g. \`is_deleted\`, \`has_access\`)

### Standard Audit Fields

```sql

created\_at TIMESTAMPTZ DEFAULT now(),

updated\_at TIMESTAMPTZ DEFAULT now(),

created\_by UUID,

is\_deleted BOOLEAN DEFAULT false,

deleted\_at TIMESTAMPTZ,

deleted\_by UUID

```

### Best Practices

- Avoid abbreviations like \`org_id\`; prefer \`organization_id\`

- Use consistent names across tables (e.g. always use \`unit_id\` when referencing \`units\`)

- Fully qualify fields in joins for readability and traceability

---

## 🚫 What’s Explicitly Avoided

- No PostgreSQL enums (lookup tables used instead)

- No client access to raw tables

- No direct use of Supabase Edge Functions for CRUD unless necessary

---

## 🧭 Next Options

- Finalize \`platform\` schema table definitions and generate DDL

- Model first \`app\` table with full RLS and function access

- Set up schema migration structure and test data loaders
