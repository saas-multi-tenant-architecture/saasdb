import type { BillingProvider, CheckoutParams, CheckoutResult, WebhookEvent, ParsedWebhookEvent, SubscriptionResult, DbClient } from '../provider';
export declare class StripeProvider implements BillingProvider {
    readonly name: "stripe";
    private stripe;
    constructor(secretKey: string);
    createCheckout(params: CheckoutParams): Promise<CheckoutResult>;
    handleWebhook(event: WebhookEvent): Promise<ParsedWebhookEvent>;
    getSubscription(providerSubscriptionId: string): Promise<SubscriptionResult>;
    cancelSubscription(providerSubscriptionId: string): Promise<void>;
    recordCustomer(organizationId: string, providerCustomerId: string, billingEmail: string, db: DbClient): Promise<void>;
    recordSubscriptionUpdate(params: ParsedWebhookEvent, db: DbClient): Promise<void>;
}
