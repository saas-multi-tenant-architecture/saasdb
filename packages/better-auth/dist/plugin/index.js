"use strict";
// plugin/index.ts
// Composes the smtaPlugin for registration in better-auth's auth config.
Object.defineProperty(exports, "__esModule", { value: true });
exports.smtaPlugin = smtaPlugin;
const api_1 = require("better-auth/api");
const zod_1 = require("zod");
const session_1 = require("./session");
const endpoints_1 = require("./endpoints");
function smtaPlugin(options) {
    const handlers = (0, endpoints_1.createSMTAHandlers)(options.pool);
    return {
        id: 'smta',
        schema: session_1.smtaSessionSchema,
        $Infer: {},
        endpoints: {
            smtaCreateOrganization: (0, api_1.createAuthEndpoint)('/smta/organization', { method: 'POST', body: zod_1.z.object({ name: zod_1.z.string(), description: zod_1.z.string().optional() }), use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.createOrganization(session.user.id, ctx.body.name, ctx.body.description);
                return ctx.json(result);
            }),
            smtaListOrganizations: (0, api_1.createAuthEndpoint)('/smta/organizations', { method: 'GET', use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.listOrganizations(session.user.id);
                return ctx.json(result);
            }),
            smtaGetOrganization: (0, api_1.createAuthEndpoint)('/smta/organization/:orgId', { method: 'GET', use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.getOrganization(session.user.id, ctx.params.orgId);
                return ctx.json(result);
            }),
            smtaCreateInvitation: (0, api_1.createAuthEndpoint)('/smta/invitation', { method: 'POST', body: zod_1.z.object({ orgId: zod_1.z.string(), email: zod_1.z.string(), roleId: zod_1.z.string() }), use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.createInvitation(session.user.id, ctx.body.orgId, ctx.body.email, ctx.body.roleId);
                return ctx.json(result);
            }),
            smtaAcceptInvitation: (0, api_1.createAuthEndpoint)('/smta/invitation/accept', { method: 'POST', body: zod_1.z.object({ token: zod_1.z.string() }), use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.acceptInvitation(session.user.id, ctx.body.token);
                return ctx.json(result);
            }),
            smtaGetInvitationDetails: (0, api_1.createAuthEndpoint)('/smta/invitation/:token', { method: 'GET' }, async (ctx) => {
                const result = await handlers.getInvitationDetails(ctx.params.token);
                return ctx.json(result);
            }),
            smtaListInvitations: (0, api_1.createAuthEndpoint)('/smta/organization/:orgId/invitations', {
                method: 'GET',
                // Optional ?status= filter. Deliberately a plain string rather than an
                // enum: the accepted values are owned by SQL, so listing them here
                // would drift the moment a status is added.
                query: zod_1.z.object({ status: zod_1.z.string().optional() }).optional(),
                use: [api_1.sessionMiddleware],
            }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.listInvitations(session.user.id, ctx.params.orgId, ctx.query?.status);
                return ctx.json(result);
            }),
            smtaCancelInvitation: (0, api_1.createAuthEndpoint)('/smta/invitation/:id/cancel', { method: 'POST', use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.cancelInvitation(session.user.id, ctx.params.id);
                return ctx.json(result);
            }),
            // The response body contains a fresh invitation token. Callers should send
            // it in an email and not persist or log it.
            smtaResendInvitation: (0, api_1.createAuthEndpoint)('/smta/invitation/:id/resend', { method: 'POST', use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.resendInvitation(session.user.id, ctx.params.id);
                return ctx.json(result);
            }),
            smtaListOrgMembers: (0, api_1.createAuthEndpoint)('/smta/organization/:orgId/members', { method: 'GET', use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.listOrgMembers(session.user.id, ctx.params.orgId);
                return ctx.json(result);
            }),
            smtaGetUserPermissions: (0, api_1.createAuthEndpoint)('/smta/organization/:orgId/permissions', { method: 'GET', use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                const result = await handlers.getUserPermissions(session.user.id, ctx.params.orgId);
                return ctx.json(result);
            }),
            smtaSetActiveOrg: (0, api_1.createAuthEndpoint)('/smta/active-org', { method: 'POST', body: zod_1.z.object({ orgId: zod_1.z.string().nullable() }), use: [api_1.sessionMiddleware] }, async (ctx) => {
                const session = ctx.context.session;
                await handlers.setActiveOrg(session.session.id, ctx.body.orgId, options.sessionTable);
                return ctx.json({ success: true });
            }),
        },
    };
}
