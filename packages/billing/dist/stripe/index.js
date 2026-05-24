"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.StripeProvider = void 0;
const stripe_1 = require("stripe");
class StripeProvider {
    constructor(secretKey) {
        this.name = 'stripe';
        this.stripe = new stripe_1.default(secretKey, { apiVersion: '2025-02-24.acacia' });
    }
    async createCheckout(params) {
        const session = await this.stripe.checkout.sessions.create({
            mode: 'subscription',
            customer_email: params.billingEmail,
            line_items: [{ price: params.priceId, quantity: 1 }],
            success_url: params.successUrl,
            cancel_url: params.cancelUrl,
            metadata: { organization_id: params.organizationId, ...params.metadata },
        });
        return { checkoutUrl: session.url, sessionId: session.id };
    }
    async handleWebhook(event) {
        const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
        if (!webhookSecret)
            throw new Error('STRIPE_WEBHOOK_SECRET not set');
        const stripeEvent = this.stripe.webhooks.constructEvent(event.rawBody, event.signature, webhookSecret);
        if (stripeEvent.type === 'customer.subscription.updated' ||
            stripeEvent.type === 'customer.subscription.deleted') {
            const sub = stripeEvent.data.object;
            return {
                type: stripeEvent.type,
                organizationId: sub.metadata.organization_id,
                providerCustomerId: sub.customer,
                providerSubscriptionId: sub.id,
                plan: sub.items.data[0]?.price.id ?? '',
                status: sub.status,
                currentPeriodEnd: new Date(sub.current_period_end * 1000),
                cancelAtPeriodEnd: sub.cancel_at_period_end,
            };
        }
        throw new Error(`Unhandled Stripe event type: ${stripeEvent.type}`);
    }
    async getSubscription(providerSubscriptionId) {
        const sub = await this.stripe.subscriptions.retrieve(providerSubscriptionId);
        return {
            providerSubscriptionId: sub.id,
            plan: sub.items.data[0]?.price.id ?? '',
            status: sub.status,
            currentPeriodEnd: new Date(sub.current_period_end * 1000),
            cancelAtPeriodEnd: sub.cancel_at_period_end,
        };
    }
    async cancelSubscription(providerSubscriptionId) {
        await this.stripe.subscriptions.cancel(providerSubscriptionId);
    }
    async recordCustomer(organizationId, providerCustomerId, billingEmail, db) {
        await db.query(`INSERT INTO platform.billing_customers (organization_id, provider_customer_id, billing_email, provider)
       VALUES ($1, $2, $3, 'stripe')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_customer_id = EXCLUDED.provider_customer_id,
             billing_email = EXCLUDED.billing_email`, [organizationId, providerCustomerId, billingEmail]);
    }
    async recordSubscriptionUpdate(params, db) {
        await db.query(`INSERT INTO platform.billing_subscriptions
         (organization_id, provider_subscription_id, plan, status, provider)
       VALUES ($1, $2, $3, $4, 'stripe')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_subscription_id = EXCLUDED.provider_subscription_id,
             plan = EXCLUDED.plan,
             status = EXCLUDED.status`, [params.organizationId, params.providerSubscriptionId, params.plan, params.status]);
    }
}
exports.StripeProvider = StripeProvider;
