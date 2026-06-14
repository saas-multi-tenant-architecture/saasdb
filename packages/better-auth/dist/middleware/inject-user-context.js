"use strict";
// inject-user-context.ts
// Sets app.current_user_id as a transaction-local PostgreSQL session variable.
// Must be called within a transaction — set_config(..., true) is scoped to the
// current transaction and cleared automatically on commit or rollback.
Object.defineProperty(exports, "__esModule", { value: true });
exports.injectUserContext = injectUserContext;
exports.clearUserContext = clearUserContext;
exports.withSMTA = withSMTA;
async function injectUserContext(client, userId) {
    await client.query(`SELECT set_config('app.current_user_id', $1, true)`, [userId]);
}
async function clearUserContext(client) {
    await client.query(`SELECT set_config('app.current_user_id', '', true)`);
}
async function withSMTA(pool, userId, fn) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        if (userId) {
            await injectUserContext(client, userId);
        }
        const result = await fn(client);
        await client.query('COMMIT');
        return result;
    }
    catch (err) {
        await client.query('ROLLBACK');
        throw err;
    }
    finally {
        client.release();
    }
}
