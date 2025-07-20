import { z } from "zod/v4";
import { shared_auditSchema } from "./_shared_audit";

export const platform_subscription_overridesSchema = z.object({
  id: z.uuid(),
  organization_id: z.uuid(),
  plan_override: z.string(),
  features: z.unknown(),
  reason: z.string(),
  ...shared_auditSchema,
});
