# Additional Schema Review

This follow up lists mismatches discovered after the previous round of fixes. Each entry compares the Zod schema with the SQL definition and calls out any remaining issues.

---

## Platform Tables

### platform.platform_action_logs
- **Zod**: `platform_action_logsSchema`
- **SQL**: `platform.platform_action_logs`
- **Mismatch**: Zod requires `platform_user_id`, but the SQL column is nullable (set to `NULL` on delete).

### platform.platform_subscription_overrides
- **Zod**: `platform_subscription_overridesSchema`
- **SQL**: `platform.platform_subscription_overrides`
- **Mismatch**: `organization_id`, `plan_override`, `features`, and `reason` are required in Zod but nullable in SQL.

### platform.platform_system_events
- **Zod**: `platform_system_eventsSchema`
- **SQL**: `platform.platform_system_events`
- **Mismatch**: Zod previously included `created_by` which does not exist in SQL. Schema updated to remove this field.

### platform.platform_roles
- **Zod**: `platform_rolesSchema`
- **SQL**: `platform.platform_roles`
- **Mismatch**: Typo in `priority` validator corrected to `z.number().int()`.

## Core Tables

### core.organization_files
- **Zod**: `organization_filesSchema`
- **SQL**: `core.organization_files`
- **Status**: Fields now align; functions updated to reference this table correctly.

---

These items should be reviewed to ensure the application logic matches the database constraints. Optional vs. required fields in Zod should mirror the NULL/NOT NULL settings in SQL where practical.
