import { z } from "zod/v4";
import { shared_auditSchema } from "./_shared_audit";

export const platform_usersSchema = z.object({
  id: z.uuid(),
  supabase_user_id: z.uuid(),
  email: z.string(),
  role_id: z.uuid(),
  first_name: z.string().optional(),
  last_name: z.string().optional(),
  ...shared_auditSchema,
});
