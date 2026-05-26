# @smta/schemas

**[Documentation](https://smta.dev)** · **[GitHub](https://github.com/saas-multi-tenant-architecture/saasdb)**

[Zod v4](https://zod.dev/) schemas for every `public.*` RPC function in [SMTA (SaaS Multi-Tenant Architecture)](https://smta.dev). Use these to validate inputs before calling SMTA functions and to parse and type the responses.

## Install

```bash
npm install @smta/schemas
```

## Usage

Each RPC function has a corresponding input schema and output schema. Import what you need:

```typescript
import {
  createOrganizationInputSchema,
  createOrganizationOutputSchema,
  listMyOrganizationsOutputSchema,
  type CreateOrganizationInput,
  type ListMyOrganizationsItem,
} from '@smta/schemas'

// Validate input before calling the RPC (e.g. in a server action)
const input = createOrganizationInputSchema.parse({
  p_name: formData.get('name'),
  p_description: formData.get('description'),
})

// Parse and type the RPC response (Supabase example)
const { data, error } = await supabase.rpc('create_organization', input)
const org = createOrganizationOutputSchema.parse(data)

// List organizations
const { data: orgsData } = await supabase.rpc('list_my_organizations')
const orgs: ListMyOrganizationsItem[] = listMyOrganizationsOutputSchema.parse(orgsData)
```

## Covered RPC functions

Schemas are provided for all functions in these areas. See the [RPC Reference](https://smta.dev/rpc-reference/organizations/) at smta.dev for the full function signatures.

- **Organizations** — `create_organization`, `get_organization`, `list_my_organizations`, `update_organization`, `list_organization_members`, `add_member_to_organization`, `remove_user_from_organization`, `transfer_super_admin`
- **Units** — create, get, list, update, add/remove members
- **User Profile** — get and update profile
- **Invitations** — create, accept, list, revoke

## Version compatibility

Schema versions are locked to the SMTA SQL version. Install the same version as your deployed database:

```bash
npm install @smta/schemas@0.1.0  # matches @smta/cli@0.1.0 deployment
```

## Part of the SMTA package family

| Package | Purpose |
|---------|---------|
| [`@smta/core`](https://www.npmjs.com/package/@smta/core) | Adapter-agnostic SQL schema |
| [`@smta/supabase`](https://www.npmjs.com/package/@smta/supabase) | Supabase adapter SQL |
| [`@smta/payload`](https://www.npmjs.com/package/@smta/payload) | Payload CMS adapter SQL + middleware |
| [`@smta/billing`](https://www.npmjs.com/package/@smta/billing) | BillingProvider interface (Stripe, Lemon Squeezy) |
| **`@smta/schemas`** | This package — Zod v4 schemas for all `public.*` RPC contracts |
| [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) | Deployment CLI |

## License

MIT
