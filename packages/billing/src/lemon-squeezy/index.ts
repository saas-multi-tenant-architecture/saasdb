import { lemonSqueezySetup, getSubscription, cancelSubscription } from '@lemonsqueezy/lemonsqueezy.js';
import type {
  BillingProvider, CheckoutParams, CheckoutResult,
  WebhookEvent, ParsedWebhookEvent, SubscriptionResult, DbClient
} from '../provider';
import { createHmac } from 'crypto';

export class LemonSqueezyProvider implements BillingProvider {
  readonly name = 'lemon_squeezy' as const;
  private apiKey: string;
  private storeId: string;

  constructor(apiKey: string, storeId: string) {
    this.apiKey = apiKey;
    this.storeId = storeId;
    lemonSqueezySetup({ apiKey });
  }

  async createCheckout(params: CheckoutParams): Promise<CheckoutResult> {
    const response = await fetch('https://api.lemonsqueezy.com/v1/checkouts', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
      body: JSON.stringify({
        data: {
          type: 'checkouts',
          attributes: {
            checkout_data: { custom: { organization_id: params.organizationId } },
            checkout_options: { embed: false },
            product_options: {
              redirect_url: params.successUrl,
            },
          },
          relationships: {
            store: { data: { type: 'stores', id: this.storeId } },
            variant: { data: { type: 'variants', id: params.priceId } },
          },
        },
      }),
    });
    const data = await response.json() as { data: { attributes: { url: string }, id: string } };
    return { checkoutUrl: data.data.attributes.url, sessionId: data.data.id };
  }

  async handleWebhook(event: WebhookEvent): Promise<ParsedWebhookEvent> {
    const secret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET;
    if (!secret) throw new Error('LEMONSQUEEZY_WEBHOOK_SECRET not set');

    const hmac = createHmac('sha256', secret);
    hmac.update(event.rawBody);
    const digest = hmac.digest('hex');
    if (digest !== event.signature) throw new Error('Invalid webhook signature');

    const payload = JSON.parse(event.rawBody.toString()) as {
      meta: { event_name: string; custom_data: { organization_id: string } };
      data: { attributes: {
        customer_id: number; first_subscription_item: { subscription_id: number; price_id: string };
        status: string; ends_at: string | null; cancelled: boolean;
      }, id: string };
    };

    return {
      type: payload.meta.event_name,
      organizationId: payload.meta.custom_data.organization_id,
      providerCustomerId: String(payload.data.attributes.customer_id),
      providerSubscriptionId: payload.data.id,
      plan: String(payload.data.attributes.first_subscription_item?.price_id ?? ''),
      status: payload.data.attributes.status as ParsedWebhookEvent['status'],
      currentPeriodEnd: payload.data.attributes.ends_at
        ? new Date(payload.data.attributes.ends_at)
        : new Date(),
      cancelAtPeriodEnd: payload.data.attributes.cancelled,
    };
  }

  async getSubscription(providerSubscriptionId: string): Promise<SubscriptionResult> {
    const { data } = await getSubscription(providerSubscriptionId);
    if (!data) throw new Error('Subscription not found');
    const attrs = data.data.attributes;
    return {
      providerSubscriptionId,
      plan: String(attrs.variant_id),
      status: attrs.status,
      currentPeriodEnd: attrs.ends_at ? new Date(attrs.ends_at) : new Date(),
      cancelAtPeriodEnd: attrs.cancelled,
    };
  }

  async cancelSubscription(providerSubscriptionId: string): Promise<void> {
    await cancelSubscription(providerSubscriptionId);
  }

  async recordCustomer(organizationId: string, providerCustomerId: string, billingEmail: string, db: DbClient): Promise<void> {
    await db.query(
      `INSERT INTO platform.billing_customers (organization_id, provider_customer_id, billing_email, provider)
       VALUES ($1, $2, $3, 'lemon_squeezy')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_customer_id = EXCLUDED.provider_customer_id,
             billing_email = EXCLUDED.billing_email`,
      [organizationId, providerCustomerId, billingEmail]
    );
  }

  async recordSubscriptionUpdate(params: ParsedWebhookEvent, db: DbClient): Promise<void> {
    await db.query(
      `INSERT INTO platform.billing_subscriptions
         (organization_id, provider_subscription_id, plan, status, provider)
       VALUES ($1, $2, $3, $4, 'lemon_squeezy')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_subscription_id = EXCLUDED.provider_subscription_id,
             plan = EXCLUDED.plan,
             status = EXCLUDED.status`,
      [params.organizationId, params.providerSubscriptionId, params.plan, params.status]
    );
  }
}
