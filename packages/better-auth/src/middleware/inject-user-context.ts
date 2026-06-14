// inject-user-context.ts
// Sets app.current_user_id as a transaction-local PostgreSQL session variable.
// Must be called within a transaction — set_config(..., true) is scoped to the
// current transaction and cleared automatically on commit or rollback.

import type { Pool, PoolClient } from 'pg';

export async function injectUserContext(
  client: PoolClient,
  userId: string
): Promise<void> {
  await client.query(
    `SELECT set_config('app.current_user_id', $1, true)`,
    [userId]
  );
}

export async function clearUserContext(client: PoolClient): Promise<void> {
  await client.query(
    `SELECT set_config('app.current_user_id', '', true)`
  );
}

export async function withSMTA<T>(
  pool: Pool,
  userId: string | null | undefined,
  fn: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (userId) {
      await injectUserContext(client, userId);
    }
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
