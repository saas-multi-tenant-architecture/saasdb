import { billing_customersSchema } from '../_schemas/billing_customers';
import { BillingCustomer } from '../_types';

export function validateBillingCustomer(data: unknown): { success: true; data: BillingCustomer } | { success: false; error: any } {
  const result = billing_customersSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
