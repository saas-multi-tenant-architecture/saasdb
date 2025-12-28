import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

// Recursive JSON schema
const JsonPrimitiveSchema = z.union([z.string(), z.number(), z.boolean(), z.null()]);

// Don't over-type this; keep it as a schema-first definition
const JsonValueSchema: z.ZodTypeAny = z.lazy(() =>
  z.union([
    JsonPrimitiveSchema,
    z.array(JsonValueSchema),
    z.record(z.string(), JsonValueSchema),
  ])
);

export const CaslRuleSchema = z.object({
  action: z.union([z.string().min(1), z.array(z.string().min(1)).nonempty()]),
  subject: z.union([z.string().min(1), z.array(z.string().min(1)).nonempty()]),
  // Optional
  fields: z.array(z.string().min(1)).nonempty().optional(),
  conditions: z.record(z.string(), JsonValueSchema).optional(),
  inverted: z.boolean().optional(),
  reason: z.string().min(1).optional(),
});


export const rolesSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  description: z.string().optional(),
  casl_rules: z.array(CaslRuleSchema).default([]), // JSONB column to store CASL rules
  ...shared_auditSchema,
});
