// inject-user-context.ts
// Injects the current user's ID into the PostgreSQL session before each query.
// Use inside a Payload beforeOperation hook — SET LOCAL is transaction-scoped,
// so it must run within the same transaction as the database operation.
//
// See packages/payload/README.md for the recommended Payload hook pattern.

export interface DbExecutor {
  query(sql: string, params?: unknown[]): Promise<unknown>;
}

export async function injectUserContext(db: DbExecutor, userId: string): Promise<void> {
  await db.query(`SELECT set_config('app.current_user_id', $1, true)`, [userId]);
}

export async function clearUserContext(db: DbExecutor): Promise<void> {
  await db.query(`SELECT set_config('app.current_user_id', '', true)`, []);
}
