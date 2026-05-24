export interface DbExecutor {
    query(sql: string, params?: unknown[]): Promise<unknown>;
}
export declare function injectUserContext(db: DbExecutor, userId: string): Promise<void>;
export declare function clearUserContext(db: DbExecutor): Promise<void>;
