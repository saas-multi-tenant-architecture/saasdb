import type { Pool } from 'pg';
export interface SMTASessionFields {
    activeOrgId: string | null;
}
export declare const smtaSessionSchema: {
    session: {
        fields: {
            activeOrgId: {
                type: "string";
                nullable: boolean;
                defaultValue: null;
            };
        };
    };
};
export declare function handleSetActiveOrg(pool: Pool, sessionId: string, orgId: string | null): Promise<void>;
