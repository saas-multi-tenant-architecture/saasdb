# @smta/cli

**[Documentation](https://smta.dev)** · **[GitHub](https://github.com/saas-multi-tenant-architecture/saasdb)**

The deployment CLI for [SMTA (SaaS Multi-Tenant Architecture)](https://smta.dev). Combines the SQL files from `@smta/core` and your chosen adapter into a single deployment script, versioned and ready to apply to your PostgreSQL database.

## Usage

No installation required — run directly with `npx`:

```bash
# Supabase deployment (59 SQL files)
npx @smta/cli --adapter supabase
# → SMTA-supabase-<timestamp>.sql

# Payload CMS deployment (57 SQL files)
npx @smta/cli --adapter payload
# → SMTA-payload-<timestamp>.sql

# better-auth deployment (60 SQL files)
npx @smta/cli --adapter better-auth
# → SMTA-better-auth-<timestamp>.sql
```

The generated file is written to your current directory. Apply it to your database:

```bash
# Via psql
psql "$DATABASE_URL" -f SMTA-supabase-<timestamp>.sql

# Via Supabase SQL Editor
# Paste the file contents and run
```

See the [Installation guide](https://smta.dev/getting-started/installation/) and adapter-specific quick starts at [smta.dev](https://smta.dev) for the full setup walkthrough.

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--adapter` | `supabase` | Adapter to use: `supabase`, `payload`, or `better-auth` |

## How it works

The CLI resolves `@smta/core` and the chosen adapter package using `require.resolve`, reads the `sql-scripts.json` manifest from each to determine execution order, concatenates the SQL files with separator comments, and writes the combined output to `process.cwd()`. The result is a single idempotent script — re-applying it to an existing deployment is safe.

## Version compatibility

All `@smta/*` packages are released together at the same version. The TypeScript companion packages installed in your application should match the version used to deploy:

```bash
# Deploy database
npx @smta/cli@0.1.0 --adapter supabase

# Install matching TypeScript packages
npm install @smta/schemas@0.1.0 @smta/billing@0.1.0
```

## Part of the SMTA package family

| Package | Purpose |
|---------|---------|
| [`@smta/core`](https://www.npmjs.com/package/@smta/core) | Adapter-agnostic SQL schema |
| [`@smta/supabase`](https://www.npmjs.com/package/@smta/supabase) | Supabase adapter SQL |
| [`@smta/payload`](https://www.npmjs.com/package/@smta/payload) | Payload CMS adapter SQL + middleware |
| [`@smta/better-auth`](https://www.npmjs.com/package/@smta/better-auth) | better-auth adapter SQL + plugin |
| [`@smta/billing`](https://www.npmjs.com/package/@smta/billing) | BillingProvider interface (Stripe, Lemon Squeezy) |
| [`@smta/schemas`](https://www.npmjs.com/package/@smta/schemas) | Zod v4 schemas for all `public.*` RPC contracts |
| **`@smta/cli`** | This package — Deployment CLI |

## License

MIT
