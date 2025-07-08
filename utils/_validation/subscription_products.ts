import { subscription_productsSchema } from '../_schemas/subscription_products';
import { SubscriptionProduct } from '../_types';

export function validateSubscriptionProduct(data: unknown): { success: true; data: SubscriptionProduct } | { success: false; error: any } {
  const result = subscription_productsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
