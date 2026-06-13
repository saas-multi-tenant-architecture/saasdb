"use strict";
// session.ts
// Declares the activeOrgId field added to the better-auth session by smtaPlugin.
// activeOrgId tracks which SMTA organization is currently "in context" for
// multi-org users. It is set by the client via smtaSetActiveOrg().
// The user's role within that org is NOT stored here — it goes stale as
// memberships change and must be fetched on demand.
Object.defineProperty(exports, "__esModule", { value: true });
exports.smtaSessionSchema = void 0;
exports.handleSetActiveOrg = handleSetActiveOrg;
// Schema extension for better-auth — adds activeOrgId to the session table.
// See: https://www.better-auth.com/docs/plugins/create-your-own#schema
exports.smtaSessionSchema = {
    session: {
        fields: {
            activeOrgId: {
                type: 'string',
                nullable: true,
                defaultValue: null,
            },
        },
    },
};
// Handler for the smtaSetActiveOrg endpoint.
// Updates activeOrgId in the session record.
// pool is passed in from the plugin factory closure.
async function handleSetActiveOrg(pool, sessionId, orgId) {
    const client = await pool.connect();
    try {
        await client.query(`UPDATE session SET "activeOrgId" = $1 WHERE id = $2`, [orgId, sessionId]);
    }
    finally {
        client.release();
    }
}
