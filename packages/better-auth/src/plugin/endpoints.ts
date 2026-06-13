// endpoints.ts
// Wraps SMTA public.* functions as better-auth auth.api.* endpoints.
// Each endpoint enforces RLS via withSMTA() — users can only affect
// organizations they are members of, enforced at the database layer.
//
// Verify createAuthEndpoint import path against installed better-auth version.
// Common paths: 'better-auth/api' or 'better-auth/plugins'

import type { Pool, PoolClient } from 'pg';
import { withSMTA } from '../middleware/inject-user-context';
import { handleSetActiveOrg } from './session';

export interface EndpointOptions {
  pool: Pool;
}

// Helper: run a public.* function and return its first row result
async function callPublicFn(
  client: PoolClient,
  fnName: string,
  args: unknown[]
): Promise<unknown> {
  const placeholders = args.map((_, i) => `$${i + 1}`).join(', ');
  const sql = `SELECT * FROM ${fnName}(${placeholders})`;
  const result = await client.query(sql, args);
  return result.rows;
}

// Factory that returns all SMTA endpoint handlers given a pool.
// These are attached to the better-auth plugin's `endpoints` map in plugin/index.ts.
// The actual createAuthEndpoint() wiring lives there to keep this file
// focused on the SMTA logic.
export function createSMTAHandlers(pool: Pool) {
  return {
    async createOrganization(userId: string, name: string, description?: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.create_organization', [name, description ?? null])
      );
    },

    async listOrganizations(userId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.list_my_organizations', [])
      );
    },

    async getOrganization(userId: string, orgId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.get_organization', [orgId])
      );
    },

    async createInvitation(userId: string, orgId: string, email: string, roleId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.create_invitation', [orgId, email, roleId])
      );
    },

    async acceptInvitation(userId: string, token: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.accept_invitation', [token])
      );
    },

    async getInvitationDetails(token: string) {
      // get_invitation_details is intentionally anon-callable (invitation landing page)
      // No RLS enforcement needed — called without a user context
      const client = await pool.connect();
      try {
        return (await callPublicFn(client, 'public.get_invitation_details', [token]));
      } finally {
        client.release();
      }
    },

    async listInvitations(userId: string, orgId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.list_invitations', [orgId])
      );
    },

    async listOrgMembers(userId: string, orgId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.list_organization_members', [orgId])
      );
    },

    async getUserPermissions(userId: string, orgId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.get_user_permissions', [orgId])
      );
    },

    async setActiveOrg(pool: Pool, sessionId: string, orgId: string | null) {
      return handleSetActiveOrg(pool, sessionId, orgId);
    },
  };
}
