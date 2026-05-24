// SYNC-CHECK: public.list_units(p_org_id UUID)
// SYNC-CHECK: public.get_unit(p_id UUID)
// SYNC-CHECK: public.create_unit(p_org_id UUID, p_name TEXT, p_description TEXT)
// SYNC-CHECK: public.update_unit(p_id UUID, p_name TEXT, p_description TEXT)
// SYNC-CHECK: public.list_unit_members(p_unit_id UUID)

import { z } from 'zod';

export const listUnitsInputSchema = z.object({ p_org_id: z.uuid() });
export const unitSchema = z.object({
  id: z.uuid(),
  organization_id: z.uuid(),
  name: z.string(),
  description: z.string().nullable(),
  created_at: z.coerce.date(),
  updated_at: z.coerce.date(),
});
export const listUnitsOutputSchema = z.array(unitSchema);

export const createUnitInputSchema = z.object({
  p_org_id: z.uuid(),
  p_name: z.string().min(1).trim(),
  p_description: z.string().optional(),
});

export const updateUnitInputSchema = z.object({
  p_id: z.uuid(),
  p_name: z.string().min(1).trim(),
  p_description: z.string().optional(),
});

export const unitMemberSchema = z.object({
  user_id: z.uuid(),
  email: z.email(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  role: z.string(),
});

export type Unit = z.infer<typeof unitSchema>;
export type UnitMember = z.infer<typeof unitMemberSchema>;
