# Zod Schema vs SQL Table Audit

This document catalogs mismatches and logical/design errors between Zod schemas (TypeScript) and SQL tables (PostgreSQL) in the project. Each section lists the Zod schema, the SQL table, and any mismatches or questionable design choices.

---

## Legend

- **Missing in Zod**: Column exists in SQL but not in Zod
- **Missing in SQL**: Field exists in Zod but not in SQL
- **Type Mismatch**: Types differ significantly (e.g., string vs. integer, uuid vs. string, date vs. timestamptz)
- **Optionality Mismatch**: Required in one, optional in the other
- **Logical/Design Issue**: Unusual or questionable schema design

---

## 1. Platform Tables

### platform.platform_roles

- **Zod**: `platform_rolesSchema` ([source](utils/_schemas/platform_roles.ts))
- **SQL**: `platform.platform_roles` ([source](002_platform_schema.sql))
- **Comparison**: No significant mismatches. All fields align in type and naming.

### platform.platform_users

- **Zod**: `platform_usersSchema` ([source](utils/_schemas/platform_users.ts))
- **SQL**: `platform.platform_users` ([source](002_platform_schema.sql))
- **Mismatches:**
  - `is_deleted`: Zod is required, SQL has `DEFAULT false` (should be optional in Zod for insert).
  - `deleted_at`, `deleted_by`: Zod is optional, SQL is nullable (OK).
  - `supabase_user_id`: Zod required, SQL `NOT NULL` (OK).
  - All other fields match.

### platform.platform_organizations

- **Zod**: `platform_organizationsSchema`
- **SQL**: `platform.platform_organizations`
- **Mismatches:**
  - `notes`: Zod optional, SQL nullable (OK).
  - `is_deleted`: Zod required, SQL `DEFAULT false` (see above).
  - All other fields match.

### platform.platform_action_logs

- **Zod**: `platform_action_logsSchema`
- **SQL**: `platform.platform_action_logs`
- **Mismatches:**
  - `action_type`: Zod is enum, SQL is `TEXT NOT NULL` (should document allowed values in SQL or use a check constraint for parity).
  - `platform_user_id`: Zod required, SQL `REFERENCES` (OK).
  - `created_at`: Zod required, SQL `DEFAULT now()` (OK).
  - All others align.

### platform.platform_subscription_overrides

- **Zod**: `platform_subscription_overridesSchema`
- **SQL**: `platform.platform_subscription_overrides`
- **Mismatches:**
  - `features`: Zod is `z.any()`, SQL is `JSONB` (OK if only JSON allowed in Zod usage).
  - `is_deleted`: Zod required, SQL `DEFAULT false` (see above).
  - All others match.

# TODO: Start Here!

### platform.platform_feature_flags

- **Zod**: `platform_feature_flagsSchema`
- **SQL**: `platform.platform_feature_flags`
- **Mismatches:**
  - `organization_id`: Zod optional, SQL nullable (OK).
  - `value`: Zod is `z.any()`, SQL is `JSONB` (see above).
  - `is_active`: Zod required, SQL `DEFAULT true` (should be optional in Zod for insert).

### platform.platform_system_events

- **Zod**: `platform_system_eventsSchema`
- **SQL**: `platform.platform_system_events`
- **Mismatches:**
  - `details`: Zod is `z.any().optional()`, SQL is `JSONB` (OK).
  - `created_by`: Zod required, SQL present (OK).

### platform.settings

- **Zod**: `platform_settingsSchema`
- **SQL**: (Not found in SQL DDL, possible mismatch)
- **Mismatches:**
  - Table may not exist in SQL.

### platform.billing_customers

- **Zod**: `billing_customersSchema`
- **SQL**: `platform.billing_customers`
- **Mismatches:**
  - `organization_id`: Zod required, SQL `PRIMARY KEY` (OK).
  - `stripe_customer_id`: Zod required, SQL `NOT NULL` (OK).
  - `billing_email`: Zod optional, SQL nullable (OK).
  - All others match.

### platform.billing_subscriptions

- **Zod**: `billing_subscriptionsSchema`
- **SQL**: `platform.billing_subscriptions`
- **Mismatches:**
  - `id`: Zod required, SQL not present (SQL uses `organization_id` as PK, not `id`).
  - `organization_id`: Zod required, SQL PK (OK).
  - `cancel_at_period_end`: Zod optional, SQL `DEFAULT FALSE` (should be optional in Zod for insert).
  - All others match.

### platform.subscription_products

- **Zod**: `subscription_productsSchema`
- **SQL**: `platform.subscription_products`
- **Mismatches:**
  - All fields match in name and type. Zod has all fields optional that are nullable in SQL.

---

## 2. Core Tables

### core.organizations

- **Zod**: `organizationsSchema`
- **SQL**: `core.organizations`
- **Mismatches:**
  - All fields match in name and type.

### core.units

- **Zod**: `unitsSchema`
- **SQL**: `core.units`
- **Mismatches:**
  - `description`: Zod required, SQL nullable (should be optional in Zod).
  - `is_deleted`: Zod required, SQL `DEFAULT FALSE` (see above).

### core.unit_meta

- **Zod**: `unit_metaSchema`
- **SQL**: `core.unit_meta`
- **Mismatches:**
  - `notes`: Zod nullable, SQL nullable (OK).
  - `is_deleted`: Zod required, SQL `DEFAULT FALSE` (see above).

### core.roles

- **Zod**: `rolesSchema`
- **SQL**: `core.roles`
- **Mismatches:**
  - All fields match.

### core.memberships

- **Zod**: `membershipsSchema`
- **SQL**: `core.memberships`
- **Mismatches:**
  - `is_deleted`: Zod optional, SQL `DEFAULT FALSE` (should be required or defaulted in Zod).

### core.unit_memberships

- **Zod**: `unit_membershipsSchema`
- **SQL**: `core.unit_memberships`
- **Mismatches:**
  - `is_deleted`: Zod optional, SQL `DEFAULT FALSE` (should be required or defaulted in Zod).

### core.organization_files

- **Zod**: `organization_filesSchema`
- **SQL**: `core.organization_files`
- **Mismatches:**
  - `file_specs`: Zod nullable, SQL `JSONB` nullable (OK).
  - `file_size`: Zod nullable, SQL nullable (OK).
  - `is_deleted`: Zod optional, SQL `DEFAULT FALSE` (should be required or defaulted in Zod).

### core.audit_logs

- **Zod**: `audit_logsSchema`
- **SQL**: `core.audit_logs`
- **Mismatches:**
  - `actor_id`, `organization_id`, `target_id`: Zod optional, SQL nullable (OK).
  - `action`: Zod string, SQL `TEXT NOT NULL` (OK, but Zod could use enum for stricter parity).

### core.users_meta

- **Zod**: `users_metaSchema`
- **SQL**: `core.users_meta`
- **Mismatches:**
  - `created_by`, `updated_by`, `is_deleted`, `deleted_at`, `deleted_by`: Zod present, not in SQL (possible logical mismatch or Zod is used for a superset).
  - `email`: Zod required, SQL nullable (should be optional in Zod).

### core.organization_meta

- **Zod**: `organization_metaSchema`
- **SQL**: `core.organization_meta`
- **Mismatches:**
  - `logo_file_id`: Zod optional, SQL nullable (OK).

---

## 3. Other/Notes

- **General**: Many Zod schemas treat boolean fields as required, but SQL defaults to `false`. For inserts, Zod should make these optional or provide defaults.
- **Date Fields**: Zod uses `z.date()`, SQL uses `TIMESTAMPTZ DEFAULT now()`. Ensure Zod can accept missing dates for inserts (let DB default apply).
- **JSON Fields**: Zod uses `z.any()`, SQL uses `JSONB`. Acceptable, but Zod should enforce JSON-compatible values.
- **Enums**: Zod uses enums for some fields, but SQL uses plain `TEXT`. Consider adding SQL check constraints for stricter parity.
- **ID Fields**: All UUIDs align between Zod and SQL.

---

# Summary Table

| Table/Schema                    | Mismatch Type(s)                        |
| ------------------------------- | --------------------------------------- |
| platform_users                  | Optionality: is_deleted                 |
| platform_organizations          | Optionality: is_deleted                 |
| platform_action_logs            | Enum in Zod, TEXT in SQL                |
| platform_subscription_overrides | Optionality: is_deleted, JSON type      |
| platform_feature_flags          | Optionality: is_active, JSON type       |
| platform_settings               | Missing SQL table                       |
| billing_subscriptions           | Zod has id, SQL uses organization_id PK |
| units                           | Optionality: description, is_deleted    |
| unit_meta                       | Optionality: is_deleted                 |
| memberships                     | Optionality: is_deleted                 |
| unit_memberships                | Optionality: is_deleted                 |
| organization_files              | Optionality: is_deleted                 |
| users_meta                      | Zod has more fields than SQL            |
| audit_logs                      | Zod could use enum for action           |

---

# Recommendations

- Make all boolean fields with SQL `DEFAULT FALSE` optional in Zod or provide defaults.
- Align optionality of fields (especially for inserts) between Zod and SQL.
- Add SQL check constraints for enum-like fields in Zod.
- Ensure Zod schemas for insert operations do not require fields that are defaulted by SQL (e.g., timestamps, booleans).
- Review `users_meta` Zod/SQL alignment: Zod has more fields than SQL.
- Document any fields present in Zod but not in SQL, and vice versa.

---

# End of Audit

This file is auto-generated for review. Please validate against your use case and update schemas as appropriate.
