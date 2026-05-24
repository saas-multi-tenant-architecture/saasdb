export interface CheckoutParams {
    organizationId: string;
    planId: string;
    priceId: string;
    billingEmail: string;
    successUrl: string;
    cancelUrl: string;
    metadata?: Record<string, string>;
}
export interface CheckoutResult {
    checkoutUrl: string;
    sessionId: string;
}
export interface WebhookEvent {
    provider: 'stripe' | 'lemon_squeezy';
    rawBody: Buffer;
    signature: string;
}
export interface ParsedWebhookEvent {
    type: string;
    organizationId: string;
    providerCustomerId: string;
    providerSubscriptionId: string;
    plan: string;
    status: 'active' | 'trialing' | 'past_due' | 'canceled' | 'unpaid';
    currentPeriodEnd: Date;
    cancelAtPeriodEnd: boolean;
}
export interface SubscriptionResult {
    providerSubscriptionId: string;
    plan: string;
    status: string;
    currentPeriodEnd: Date;
    cancelAtPeriodEnd: boolean;
}
export interface DbClient {
    query(sql: string, params?: unknown[]): Promise<{
        rows: Record<string, unknown>[];
    }>;
}
export interface BillingProvider {
    readonly name: 'stripe' | 'lemon_squeezy';
    createCheckout(params: CheckoutParams): Promise<CheckoutResult>;
    handleWebhook(event: WebhookEvent): Promise<ParsedWebhookEvent>;
    getSubscription(providerSubscriptionId: string): Promise<SubscriptionResult>;
    cancelSubscription(providerSubscriptionId: string): Promise<void>;
    recordCustomer(organizationId: string, providerCustomerId: string, billingEmail: string, db: DbClient): Promise<void>;
    recordSubscriptionUpdate(params: ParsedWebhookEvent, db: DbClient): Promise<void>;
}
