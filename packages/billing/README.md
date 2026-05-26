# @smta/billing

**[Documentation](https://smta.dev)** · **[GitHub](https://github.com/saas-multi-tenant-architecture/saasdb)**

The billing abstraction layer for [SMTA (SaaS Multi-Tenant Architecture)](https://smta.dev). Provides a `BillingProvider` interface with ready-to-use implementations for Stripe and Lemon Squeezy, wired to SMTA's billing tables.

## Install

```bash
npm install @smta/billing
```

## Usage

### Stripe

```typescript
import { StripeProvider } from '@smta/billing'

const billing = new StripeProvider(process.env.STRIPE_SECRET_KEY!)

// Create a checkout session
const { checkoutUrl } = await billing.createCheckout({
  organizationId: org.id,
  planId: 'pro',
  priceId: 'price_xxx',
  billingEmail: user.email,
  successUrl: 'https://myapp.com/billing/success',
  cancelUrl: 'https://myapp.com/billing',
})

// Handle a webhook
const event = await billing.handleWebhook({ provider: 'stripe', rawBody, signature })
await billing.recordSubscriptionUpdate(event, db)
```

### Lemon Squeezy

```typescript
import { LemonSqueezyProvider } from '@smta/billing'

const billing = new LemonSqueezyProvider(process.env.LEMON_SQUEEZY_API_KEY!)
```

Both providers implement the same `BillingProvider` interface — swap them without changing your application logic.

### BillingProvider interface

```typescript
interface BillingProvider {
  createCheckout(params: CheckoutParams): Promise<CheckoutResult>
  handleWebhook(event: WebhookEvent): Promise<ParsedWebhookEvent>
  getSubscription(providerSubscriptionId: string): Promise<SubscriptionResult>
  cancelSubscription(providerSubscriptionId: string): Promise<void>
  recordCustomer(organizationId, providerCustomerId, billingEmail, db): Promise<void>
  recordSubscriptionUpdate(params: ParsedWebhookEvent, db: DbClient): Promise<void>
}
```

For the full billing architecture and how SMTA's billing tables relate to your subscription data, see the [Billing docs](https://smta.dev/billing/overview/).

## Part of the SMTA package family

| Package | Purpose |
|---------|---------|
| [`@smta/core`](https://www.npmjs.com/package/@smta/core) | Adapter-agnostic SQL schema |
| [`@smta/supabase`](https://www.npmjs.com/package/@smta/supabase) | Supabase adapter SQL |
| [`@smta/payload`](https://www.npmjs.com/package/@smta/payload) | Payload CMS adapter SQL + middleware |
| **`@smta/billing`** | This package — BillingProvider interface (Stripe, Lemon Squeezy) |
| [`@smta/schemas`](https://www.npmjs.com/package/@smta/schemas) | Zod v4 schemas for all `public.*` RPC contracts |
| [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) | Deployment CLI |

## License

MIT
