import type { Pool, PoolClient } from 'pg';
export declare function injectUserContext(client: PoolClient, userId: string): Promise<void>;
export declare function clearUserContext(client: PoolClient): Promise<void>;
export declare function withSMTA<T>(pool: Pool, userId: string | null | undefined, fn: (client: PoolClient) => Promise<T>): Promise<T>;
