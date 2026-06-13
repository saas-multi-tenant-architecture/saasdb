"use strict";
// endpoints.ts
// Wraps SMTA public.* functions as better-auth auth.api.* endpoints.
// Each endpoint enforces RLS via withSMTA() — users can only affect
// organizations they are members of, enforced at the database layer.
//
// Verify createAuthEndpoint import path against installed better-auth version.
// Common paths: 'better-auth/api' or 'better-auth/plugins'
Object.defineProperty(exports, "__esModule", { value: true });
exports.createSMTAHandlers = createSMTAHandlers;
const inject_user_context_1 = require("../middleware/inject-user-context");
const session_1 = require("./session");
// Helper: run a public.* function and return its first row result
async function callPublicFn(client, fnName, args) {
    const placeholders = args.map((_, i) => `$${i + 1}`).join(', ');
    const sql = `SELECT * FROM ${fnName}(${placeholders})`;
    const result = await client.query(sql, args);
    return result.rows;
}
// Factory that returns all SMTA endpoint handlers given a pool.
// These are attached to the better-auth plugin's `endpoints` map in plugin/index.ts.
// The actual createAuthEndpoint() wiring lives there to keep this file
// focused on the SMTA logic.
function createSMTAHandlers(pool) {
    return {
        async createOrganization(userId, name, description) {
            return (0, inject_user_context_1.withSMTA)(pool, userId, (client) => callPublicFn(client, 'public.create_organization', [name, description ?? null]));
        },
        async listOrganizations(userId) {
            return (0, inject_user_context_1.withSMTA)(pool, userId, (client) => callPublicFn(client, 'public.list_my_organizations', []));
        },
        async getOrganization(userId, orgId) {
            return (0, inject_user_context_1.withSMTA)(pool, userId, (client) => callPublicFn(client, 'public.get_organization', [orgId]));
        },
        async createInvitation(userId, orgId, email, roleId) {
            return (0, inject_user_context_1.withSMTA)(pool, userId, (client) => callPublicFn(client, 'public.create_invitation', [orgId, email, roleId]));
        },
        async acceptInvitation(userId, token) {
            return (0, inject_user_context_1.withSMTA)(pool, userId, (client) => callPublicFn(client, 'public.accept_invitation', [token]));
        },
        async getInvitationDetails(token) {
            // get_invitation_details is intentionally anon-callable (invitation landing page)
            // No RLS enforcement needed — called without a user context
            const client = await pool.connect();
            try {
                return (await callPublicFn(client, 'public.get_invitation_details', [token]));
            }
            finally {
                client.release();
            }
        },
        async listInvitations(userId, orgId) {
            return (0, inject_user_context_1.withSMTA)(pool, userId, (client) => callPublicFn(client, 'public.list_invitations', [orgId]));
        },
        async listOrgMembers(userId, orgId) {
            return (0, inject_user_context_1.withSMTA)(pool, userId, (client) => callPublicFn(client, 'public.list_organization_members', [orgId]));
        },
        async getUserPermissions(userId, orgId) {
            return (0, inject_user_context_1.withSMTA)(pool, userId, (client) => callPublicFn(client, 'public.get_user_permissions', [orgId]));
        },
        async setActiveOrg(sessionId, orgId) {
            return (0, session_1.handleSetActiveOrg)(pool, sessionId, orgId);
        },
    };
}
