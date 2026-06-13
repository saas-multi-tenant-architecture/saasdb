import type { BetterAuthPlugin } from 'better-auth';
import type { Pool } from 'pg';
export interface SMTAPluginOptions {
    pool: Pool;
}
export declare function smtaPlugin(options: SMTAPluginOptions): BetterAuthPlugin;
