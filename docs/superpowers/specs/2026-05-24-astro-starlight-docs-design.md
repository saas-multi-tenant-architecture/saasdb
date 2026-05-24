# SMTA Documentation Site Design Spec

## Goal

Build a public-facing documentation site for SMTA at `smta.dev` using Astro Starlight, hosted on Cloudflare Pages with automatic deployment from the `master` branch.

## Architecture

The docs site lives at `apps/docs/` inside the existing pnpm monorepo as a first-class workspace member named `@smta/docs`. It has no runtime dependency on other packages — it is pure content. The `@smta/schemas` Zod types serve as a reference for writing accurate RPC function documentation but are not imported by the build.

A future `apps/demo/` site would follow the same pattern, requiring no structural changes.

## Workspace Integration

**`pnpm-workspace.yaml`** — add `apps/*`:
```yaml
packages:
  - 'packages/*'
  - 'apps/*'
```

**Root `package.json`** — add build script:
```json
"build:docs": "pnpm --filter @smta/docs build"
```

**`turbo.json`** — no changes required; the existing `build` pipeline handles new workspace members automatically.

## Directory Structure

```
apps/
└── docs/
    ├── package.json        (name: "@smta/docs")
    ├── astro.config.mjs    (Starlight config, site title, nav structure)
    ├── src/
    │   ├── content/
    │   │   └── docs/       (all Markdown/MDX pages, organized by section)
    │   └── assets/         (images, logo, diagrams)
    └── public/             (favicon, robots.txt)
```

## Content Structure

Seven top-level sections in the Starlight sidebar:

### 1. Getting Started
- What is SMTA
- Installation & deployment (prerequisites, apply SQL to your database)
- Quick start: Supabase adapter
- Quick start: Payload adapter

### 2. Architecture
- 25,000 ft overview (the layered design: application → SMTA → platform)
- Schema boundaries (`core`, `platform`, `utils`, `public`, `app`)
- Tenant isolation and RLS model
- Adapter pattern explained (what is adapter-agnostic, what is adapter-specific)

### 3. Adapters
- Supabase adapter: what it provides, setup steps
- Payload adapter: what it provides, setup steps

### 4. Public RPC Reference
- One page per logical group of `public.*` functions
- Each function documents: purpose, parameters (from `@smta/schemas` Zod contracts), return shape, example call

### 5. Billing Integration
- BillingProvider interface
- Stripe setup
- Lemon Squeezy setup

### 6. Testing
- pgTap setup
- Running the test suite (`npm test`)
- Test conventions and structure

### 7. Contributing
- Package structure overview
- Adding SQL files (manifest ordering, naming conventions)
- Test conventions for new features

## Deployment

**Platform:** Cloudflare Pages  
**Trigger:** Git integration — auto-deploys on every push to `master`  
**Domain:** `smta.dev` (configured once in Cloudflare dashboard)

Astro is configured with `output: 'static'`. Cloudflare Pages runs `pnpm --filter @smta/docs build` and serves `apps/docs/dist/`. HTTPS and CDN are handled automatically by Cloudflare.

The Cloudflare Pages project and `smta.dev` custom domain are set up once manually in the Cloudflare dashboard. This is outside the scope of the implementation plan — the plan assumes the Cloudflare project exists before the first deploy.

**Build settings for Cloudflare Pages dashboard:**
- Build command: `pnpm --filter @smta/docs build`
- Build output directory: `apps/docs/dist`
- Root directory: `/` (monorepo root)
- Node version: 20

## Out of Scope

- CloudFront or AWS infrastructure (replaced by Cloudflare Pages)
- Auto-generated API docs from source code (docs are hand-authored)
- Versioning or multi-version docs (single version matching current `master`)
- Demo site implementation (placeholder `apps/demo/` not created now)
- Cloudflare Pages project or DNS setup (manual, one-time, outside this plan)
