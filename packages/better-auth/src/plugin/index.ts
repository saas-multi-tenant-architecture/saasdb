// plugin/index.ts
// Composes the smtaPlugin for registration in better-auth's auth config.

import type { BetterAuthPlugin } from 'better-auth';
import { createAuthEndpoint, sessionMiddleware } from 'better-auth/api';
import { z } from 'better-auth';
import type { Pool } from 'pg';
import { smtaSessionSchema, type SMTASessionFields } from './session';
import { createSMTAHandlers } from './endpoints';

export interface SMTAPluginOptions {
  pool: Pool;
}

export function smtaPlugin(options: SMTAPluginOptions): BetterAuthPlugin {
  const handlers = createSMTAHandlers(options.pool);

  return {
    id: 'smta',

    schema: smtaSessionSchema,

    $Infer: {} as {
      activeOrgId: SMTASessionFields['activeOrgId'];
    },

    endpoints: {
      smtaCreateOrganization: createAuthEndpoint(
        '/smta/organization',
        { method: 'POST', body: z.object({ name: z.string(), description: z.string().optional() }), use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.createOrganization(session.user.id, ctx.body.name, ctx.body.description);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),

      smtaListOrganizations: createAuthEndpoint(
        '/smta/organizations',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.listOrganizations(session.user.id);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),

      smtaGetOrganization: createAuthEndpoint(
        '/smta/organization/:orgId',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.getOrganization(session.user.id, ctx.params.orgId);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),

      smtaCreateInvitation: createAuthEndpoint(
        '/smta/invitation',
        { method: 'POST', body: z.object({ orgId: z.string(), email: z.string(), roleId: z.string() }), use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.createInvitation(session.user.id, ctx.body.orgId, ctx.body.email, ctx.body.roleId);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),

      smtaAcceptInvitation: createAuthEndpoint(
        '/smta/invitation/accept',
        { method: 'POST', body: z.object({ token: z.string() }), use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.acceptInvitation(session.user.id, ctx.body.token);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),

      smtaGetInvitationDetails: createAuthEndpoint(
        '/smta/invitation/:token',
        { method: 'GET' },
        async (ctx) => {
          const result = await handlers.getInvitationDetails(ctx.params.token);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),

      smtaListInvitations: createAuthEndpoint(
        '/smta/organization/:orgId/invitations',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.listInvitations(session.user.id, ctx.params.orgId);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),

      smtaListOrgMembers: createAuthEndpoint(
        '/smta/organization/:orgId/members',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.listOrgMembers(session.user.id, ctx.params.orgId);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),

      smtaGetUserPermissions: createAuthEndpoint(
        '/smta/organization/:orgId/permissions',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.getUserPermissions(session.user.id, ctx.params.orgId);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),

      smtaSetActiveOrg: createAuthEndpoint(
        '/smta/active-org',
        { method: 'POST', body: z.object({ orgId: z.string().nullable() }), use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          await handlers.setActiveOrg(session.session.id, ctx.body.orgId);
          return ctx.json({ success: true });
        }
      ),
    },
  } satisfies BetterAuthPlugin;
}
