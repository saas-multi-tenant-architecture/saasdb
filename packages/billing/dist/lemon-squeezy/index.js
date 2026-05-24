"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LemonSqueezyProvider = void 0;
const lemonsqueezy_js_1 = require("@lemonsqueezy/lemonsqueezy.js");
const crypto_1 = require("crypto");
class LemonSqueezyProvider {
    constructor(apiKey, storeId) {
        this.name = 'lemon_squeezy';
        this.apiKey = apiKey;
        this.storeId = storeId;
        (0, lemonsqueezy_js_1.lemonSqueezySetup)({ apiKey });
    }
    async createCheckout(params) {
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
        const data = await response.json();
        return { checkoutUrl: data.data.attributes.url, sessionId: data.data.id };
    }
    async handleWebhook(event) {
        const secret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET;
        if (!secret)
            throw new Error('LEMONSQUEEZY_WEBHOOK_SECRET not set');
        const hmac = (0, crypto_1.createHmac)('sha256', secret);
        hmac.update(event.rawBody);
        const digest = hmac.digest('hex');
        if (digest !== event.signature)
            throw new Error('Invalid webhook signature');
        const payload = JSON.parse(event.rawBody.toString());
        return {
            type: payload.meta.event_name,
            organizationId: payload.meta.custom_data.organization_id,
            providerCustomerId: String(payload.data.attributes.customer_id),
            providerSubscriptionId: payload.data.id,
            plan: String(payload.data.attributes.first_subscription_item?.price_id ?? ''),
            status: payload.data.attributes.status,
            currentPeriodEnd: payload.data.attributes.ends_at
                ? new Date(payload.data.attributes.ends_at)
                : new Date(),
            cancelAtPeriodEnd: payload.data.attributes.cancelled,
        };
    }
    async getSubscription(providerSubscriptionId) {
        const { data } = await (0, lemonsqueezy_js_1.getSubscription)(providerSubscriptionId);
        if (!data)
            throw new Error('Subscription not found');
        const attrs = data.data.attributes;
        return {
            providerSubscriptionId,
            plan: String(attrs.variant_id),
            status: attrs.status,
            currentPeriodEnd: attrs.ends_at ? new Date(attrs.ends_at) : new Date(),
            cancelAtPeriodEnd: attrs.cancelled,
        };
    }
    async cancelSubscription(providerSubscriptionId) {
        await (0, lemonsqueezy_js_1.cancelSubscription)(providerSubscriptionId);
    }
    async recordCustomer(organizationId, providerCustomerId, billingEmail, db) {
        await db.query(`INSERT INTO platform.billing_customers (organization_id, provider_customer_id, billing_email, provider)
       VALUES ($1, $2, $3, 'lemon_squeezy')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_customer_id = EXCLUDED.provider_customer_id,
             billing_email = EXCLUDED.billing_email`, [organizationId, providerCustomerId, billingEmail]);
    }
    async recordSubscriptionUpdate(params, db) {
        await db.query(`INSERT INTO platform.billing_subscriptions
         (organization_id, provider_subscription_id, plan, status, provider)
       VALUES ($1, $2, $3, $4, 'lemon_squeezy')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_subscription_id = EXCLUDED.provider_subscription_id,
             plan = EXCLUDED.plan,
             status = EXCLUDED.status`, [params.organizationId, params.providerSubscriptionId, params.plan, params.status]);
    }
}
exports.LemonSqueezyProvider = LemonSqueezyProvider;
