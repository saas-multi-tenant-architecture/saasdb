import { defineConfig } from 'astro/config'
import starlight from '@astrojs/starlight'

export default defineConfig({
  output: 'static',
  integrations: [
    starlight({
      title: 'SMTA',
      description: 'SaaS Multi-Tenant Architecture — PostgreSQL multi-tenancy for your SaaS',
      social: [
        // Update href to your GitHub repo URL before deploying
        { icon: 'github', label: 'GitHub', href: 'https://github.com/YOUR_ORG/saasdb' },
      ],
      sidebar: [
        {
          label: 'Getting Started',
          items: [
            { label: 'What is SMTA?', slug: 'getting-started/what-is-smta' },
            { label: 'Installation', slug: 'getting-started/installation' },
            { label: 'Quick Start: Supabase', slug: 'getting-started/quickstart-supabase' },
            { label: 'Quick Start: Payload', slug: 'getting-started/quickstart-payload' },
          ],
        },
        {
          label: 'Architecture',
          items: [
            { label: 'Overview', slug: 'architecture/overview' },
            { label: 'Schema Boundaries', slug: 'architecture/schema-boundaries' },
            { label: 'Tenant Isolation & RLS', slug: 'architecture/tenant-isolation' },
            { label: 'Adapter Pattern', slug: 'architecture/adapter-pattern' },
          ],
        },
        {
          label: 'Adapters',
          items: [
            { label: 'Supabase', slug: 'adapters/supabase' },
            { label: 'Payload CMS', slug: 'adapters/payload' },
          ],
        },
        {
          label: 'Public RPC Reference',
          items: [
            { label: 'Organizations', slug: 'rpc-reference/organizations' },
            { label: 'Units', slug: 'rpc-reference/units' },
            { label: 'User Profile', slug: 'rpc-reference/user-profile' },
            { label: 'Invitations', slug: 'rpc-reference/invitations' },
            { label: 'Files', slug: 'rpc-reference/files' },
            { label: 'Secrets', slug: 'rpc-reference/secrets' },
            { label: 'Audit', slug: 'rpc-reference/audit' },
            { label: 'Products', slug: 'rpc-reference/products' },
          ],
        },
        {
          label: 'Billing Integration',
          items: [
            { label: 'Overview', slug: 'billing/overview' },
            { label: 'Stripe', slug: 'billing/stripe' },
            { label: 'Lemon Squeezy', slug: 'billing/lemon-squeezy' },
          ],
        },
        {
          label: 'Testing',
          items: [
            { label: 'Setup', slug: 'testing/setup' },
            { label: 'Running the Test Suite', slug: 'testing/running' },
          ],
        },
        {
          label: 'Contributing',
          items: [
            { label: 'Package Structure', slug: 'contributing/package-structure' },
            { label: 'Adding SQL', slug: 'contributing/adding-sql' },
            { label: 'Test Conventions', slug: 'contributing/test-conventions' },
          ],
        },
      ],
    }),
  ],
})
