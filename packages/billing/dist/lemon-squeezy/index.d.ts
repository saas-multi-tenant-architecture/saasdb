import type { BillingProvider, CheckoutParams, CheckoutResult, WebhookEvent, ParsedWebhookEvent, SubscriptionResult, DbClient } from '../provider';
export declare class LemonSqueezyProvider implements BillingProvider {
    readonly name: "lemon_squeezy";
    private apiKey;
    private storeId;
    constructor(apiKey: string, storeId: string);
    createCheckout(params: CheckoutParams): Promise<CheckoutResult>;
    handleWebhook(event: WebhookEvent): Promise<ParsedWebhookEvent>;
    getSubscription(providerSubscriptionId: string): Promise<SubscriptionResult>;
    cancelSubscription(providerSubscriptionId: string): Promise<void>;
    recordCustomer(organizationId: string, providerCustomerId: string, billingEmail: string, db: DbClient): Promise<void>;
    recordSubscriptionUpdate(params: ParsedWebhookEvent, db: DbClient): Promise<void>;
}
