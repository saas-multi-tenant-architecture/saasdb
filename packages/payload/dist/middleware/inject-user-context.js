"use strict";
// inject-user-context.ts
// Injects the current user's ID into the PostgreSQL session before each query.
// Use inside a Payload beforeOperation hook — SET LOCAL is transaction-scoped,
// so it must run within the same transaction as the database operation.
//
// See packages/payload/README.md for the recommended Payload hook pattern.
Object.defineProperty(exports, "__esModule", { value: true });
exports.injectUserContext = injectUserContext;
exports.clearUserContext = clearUserContext;
async function injectUserContext(db, userId) {
    await db.query(`SELECT set_config('app.current_user_id', $1, true)`, [userId]);
}
async function clearUserContext(db) {
    await db.query(`SELECT set_config('app.current_user_id', '', true)`, []);
}
