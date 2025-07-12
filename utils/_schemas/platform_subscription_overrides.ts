import { z } from "zod/v4";

export const platform_subscription_overridesSchema = z.object({
  id: z.uuid(),
  organization_id: z.uuid(),
  plan_override: z.string(),
  features: z.unknown(),
  reason: z.string(),
  created_by: z.uuid(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
