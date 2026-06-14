// session.ts
// Declares the activeOrgId field added to the better-auth session by smtaPlugin.
// activeOrgId tracks which SMTA organization is currently "in context" for
// multi-org users. It is set by the client via smtaSetActiveOrg().
// The user's role within that org is NOT stored here — it goes stale as
// memberships change and must be fetched on demand.

import type { Pool } from 'pg';

export interface SMTASessionFields {
  activeOrgId: string | null;
}

// Schema extension for better-auth — adds activeOrgId to the session table.
// See: https://www.better-auth.com/docs/plugins/create-your-own#schema
export const smtaSessionSchema = {
  session: {
    fields: {
      activeOrgId: {
        type: 'string' as const,
        required: false,
        defaultValue: null,
      },
    },
  },
};

// Handler for the smtaSetActiveOrg endpoint.
// Updates activeOrgId in the session record.
// pool is passed in from the plugin factory closure.
// NOTE: No membership verification — any authenticated user can set any orgId.
// RLS in the database still enforces actual data access per org, so the security
// impact is limited to the session field itself. A full fix would require a
// public.set_active_org() function with RLS enforcement (out of current scope).
export async function handleSetActiveOrg(
  pool: Pool,
  sessionId: string,
  orgId: string | null,
  sessionTable = 'session'
): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query(
      `UPDATE "${sessionTable}" SET "activeOrgId" = $1 WHERE id = $2`,
      [orgId, sessionId]
    );
  } finally {
    client.release();
  }
}
