# @smta/payload — Payload CMS Adapter

## Auth Injection Mechanism (Task 6.1 Research)

**Finding:** `@payloadcms/db-postgres` (v3.x) does NOT expose a `beforeQuery` hook or `onConnect` callback. It accepts a standard `pg.Pool` configuration via the `pool` option, then creates the pool internally and wraps it with Drizzle ORM.

There is no built-in mechanism to run SQL before each query.

**Recommended approach:** Payload's `beforeOperation` collection/global hooks. These fire before each database operation and receive `req` which includes the authenticated user. Within a `beforeOperation` hook, call `SET LOCAL app.current_user_id = '...'` using the Payload DB execute helper. Since Payload wraps most operations in transactions, `SET LOCAL` (transaction-scoped) is the right choice.

```typescript
// In your collection config:
beforeOperation: [
  async ({ req }) => {
    if (req.user?.id) {
      await req.payload.db.pool.query(
        `SELECT set_config('app.current_user_id', $1, true)`,
        [req.user.id]
      );
    }
  }
]
```

**Fallback:** For operations outside a transaction, use `SET SESSION` (connection-scoped). This is less safe in a pooled environment — clear the value after use.

See `src/middleware/inject-user-context.ts` for the reusable helper.
