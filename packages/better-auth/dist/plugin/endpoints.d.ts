import type { Pool } from 'pg';
export interface EndpointOptions {
    pool: Pool;
}
export declare function createSMTAHandlers(pool: Pool): {
    createOrganization(userId: string, name: string, description?: string): Promise<unknown>;
    listOrganizations(userId: string): Promise<unknown>;
    getOrganization(userId: string, orgId: string): Promise<unknown>;
    createInvitation(userId: string, orgId: string, email: string, roleId: string): Promise<unknown>;
    acceptInvitation(userId: string, token: string): Promise<unknown>;
    getInvitationDetails(token: string): Promise<unknown>;
    listInvitations(userId: string, orgId: string): Promise<unknown>;
    listOrgMembers(userId: string, orgId: string): Promise<unknown>;
    getUserPermissions(userId: string, orgId: string): Promise<unknown>;
    setActiveOrg(sessionId: string, orgId: string | null, sessionTable?: string): Promise<void>;
};
