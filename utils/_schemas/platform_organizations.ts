import { z } from "zod/v4";
import { shared_auditSchema } from "./_shared_audit";

export const platform_organizationsSchema = z.object({
  id: z.uuid(),
  label: z.string(),
  notes: z.string().optional(),
  ...shared_auditSchema,
});
