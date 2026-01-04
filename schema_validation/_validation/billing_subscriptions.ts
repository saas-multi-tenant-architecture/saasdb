import { billing_subscriptionsSchema } from '../_schemas/billing_subscriptions';
import { BillingSubscription } from '../_types';

export function validateBillingSubscription(data: unknown): { success: true; data: BillingSubscription } | { success: false; error: any } {
  const result = billing_subscriptionsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
